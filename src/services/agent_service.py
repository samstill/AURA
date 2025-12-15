"""
Agent Service - Gemini Tool-Use Agent
======================================

Handles complex agentic tasks using Gemini Pro with
Dynamic Tool Injection via MCP.
"""

import logging
import json
import asyncio
from datetime import datetime
from typing import List, Any, Callable, Dict, Optional, Tuple

import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration, Tool

from .llm_service import llm_service
from .tool_manager import tool_manager
from .mcp_client import RemoteMCPClient
from config import settings

logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Agent Service
# -----------------------------------------------------------------------------
class AgentService:
    """
    Agentic service for complex tool-use tasks.
    Uses Gemini Pro with dynamic MCP tool injection and manual execution loop.
    """
    
    def __init__(self):
        # We no longer hardcode tools here.
        pass
    
    async def run_agent_loop(
        self, 
        user_query: str, 
        user_id: str,
        system_prompt: str = "You are Aura, an efficient AI secretary."
    ) -> str:
        """
        Run the Gemini Agent Loop with Dynamic Tools.
        
        Args:
            user_query: User's request
            user_id: ID of the user to fetch tools for
            system_prompt: Context for the AI persona
            
        Returns:
            Final text response from the agent
        """
        logger.info(f"🤖 [Agent] Thinking with Gemini Pro (User: {user_id})...")
        
        if not llm_service.is_initialized:
            return "[System Error: LLM Service not initialized]"
        
        # 1. Hydrate Tools
        # Fetch enabled tools for this user and discover their capabilities
        try:
            mcp_tools, tool_clients = await self._load_mcp_tools(user_id)
        except Exception as e:
            logger.error(f"Failed to load tools: {e}")
            return f"[System Error: Failed to load tools. {e}]"

        try:
            # Add Dynamic Context
            current_context = f"Current Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}. "
            full_system_prompt = f"{current_context}{system_prompt}"

            # Initialize Model
            # We construct the tool definitions manually for Gemini
            # gemini_tools argument: Iterable[Tool | Callable | FunctionDeclaration]
            # We wrap our schemas in FunctionDeclaration
            
            gemini_tool_declarations = []
            if mcp_tools:
                for t in mcp_tools:
                    gemini_tool_declarations.append(
                        FunctionDeclaration(
                            name=t["name"],
                            description=t["description"],
                            parameters=t["parameters"]
                        )
                    )

            model = genai.GenerativeModel(
                settings.gemini_smart_model,
                tools=[Tool(function_declarations=gemini_tool_declarations)] if gemini_tool_declarations else None,
                system_instruction=full_system_prompt
            )
            
            # Start chat (Manual handling for better control over remote tools)
            # enable_automatic_function_calling=False is default
            chat = model.start_chat()
            
            # Send Initial Query
            response = await chat.send_message_async(user_query)
            
            # loop for function calls (Max turns to prevent infinite loops)
            max_turns = 5
            for _ in range(max_turns):
                # Check if the model wants to call a function
                # Gemini 1.5 Pro refers to this as 'function_calls' in candidates which the SDK abstracts?
                # The SDK 'response.parts' contains 'FunctionCall' parts.
                
                function_call_part = None
                for part in response.parts:
                    if fn := part.function_call:
                        function_call_part = fn
                        break
                
                if not function_call_part:
                    # No function call, just return text
                    return response.text
                
                # Execute Function
                fn_name = function_call_part.name
                fn_args = dict(function_call_part.args)
                logger.info(f"🛠️ [Agent] Calling Tool: {fn_name}({fn_args})")
                
                result_text = ""
                
                if fn_name in tool_clients:
                    # Execute Remote MCP Tool
                    client = tool_clients[fn_name]
                    try:
                        result_text = await client.call_tool(fn_name, fn_args)
                    except Exception as e:
                        result_text = f"Error executing tool {fn_name}: {str(e)}"
                else:
                    result_text = f"Error: Tool {fn_name} not found."
                
                logger.info(f"   Result: {result_text[:100]}...")

                # Send Result back to Model
                # We need to construct a FunctionResponse
                response = await chat.send_message_async(
                    genai.prototypes.Part(
                        function_response=genai.prototypes.FunctionResponse(
                            name=fn_name,
                            response={"result": result_text}
                        )
                    )
                )

            return response.text

        except Exception as e:
            logger.warning(f"⚠️ Gemini Pro failed: {e}. Switching to Smart Fallback.")
            return await self._run_fallback_agent(user_query, full_system_prompt, mcp_tools, tool_clients)

    async def _load_mcp_tools(self, user_id: str) -> Tuple[List[Dict], Dict[str, RemoteMCPClient]]:
        """
        Fetch tools from DB and Query MCP servers for definitions.
        
        Returns:
            list of tool definitions (Gemini schema specific dicts),
            dict of {tool_name: mcp_client_instance}
        """
        user_tools_config = await tool_manager.get_active_tools_for_user(user_id)
        
        gemini_defs = []
        client_map = {}
        
        # In a real app, we should parallelize this
        for config in user_tools_config:
            try:
                client = RemoteMCPClient(config["endpoint"], config["config"])
                
                # Discovery
                mcp_list = await client.list_tools()
                
                for tool in mcp_list:
                    # Map MCP Tool to Gemini Schema
                    # MCP: {name, description, inputSchema}
                    # Gemini: {name, description, parameters}
                    
                    g_tool = {
                        "name": tool["name"],
                        "description": tool.get("description", ""),
                        "parameters": tool.get("inputSchema", {})
                    }
                    gemini_defs.append(g_tool)
                    client_map[tool["name"]] = client
                    
            except Exception as e:
                logger.error(f"Failed to load tools from {config['endpoint']}: {e}")
                # Continue without this tool
                
        return gemini_defs, client_map

    async def _run_fallback_agent(
        self, 
        user_query: str, 
        system_prompt: str,
        mcp_tools: List[Dict],
        tool_clients: Dict[str, RemoteMCPClient]
    ) -> str:
        """
        Fallback to Groq/OpenRouter with manual tool calling loop.
        """
        last_error = None
        
        for client, model in self._get_fallback_clients():
            logger.info(f"🛡️ [Fallback] Trying {model}...")
            
            try:
                messages = [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_query}
                ]
                
                # Convert Gemini tools format (which we built) to OpenAI Schema
                # They are very similar, just need to wrap them
                openai_tools = []
                for t in mcp_tools:
                    openai_tools.append({
                        "type": "function",
                        "function": {
                            "name": t["name"],
                            "description": t["description"],
                            "parameters": t["parameters"]
                        }
                    })

                # 1. First Goal: Get tool calls or final answer
                response = await client.chat.completions.create(
                    model=model,
                    messages=messages,
                    tools=openai_tools if openai_tools else None,
                    tool_choice="auto" if openai_tools else "none"
                )
                
                message = response.choices[0].message
                
                # 2. Check for tool calls
                if message.tool_calls:
                    logger.info(f"🛠️ [Fallback] Model requested {len(message.tool_calls)} tools")
                    messages.append(message)
                    
                    # Execute tools
                    for tool_call in message.tool_calls:
                        fn_name = tool_call.function.name
                        fn_args = json.loads(tool_call.function.arguments)
                        
                        logger.info(f"   Executing {fn_name}({fn_args})")
                        
                        result_str = ""
                        if fn_name in tool_clients:
                            try:
                                result_str = await tool_clients[fn_name].call_tool(fn_name, fn_args)
                            except Exception as e:
                                result_str = str(e)
                        else:
                            result_str = "Error: Tool not found"
                            
                        messages.append({
                            "tool_call_id": tool_call.id,
                            "role": "tool",
                            "name": fn_name,
                            "content": result_str # OpenAI expects string content
                        })
                    
                    # 3. Get Final Answer after tool execution
                    final_response = await client.chat.completions.create(
                        model=model,
                        messages=messages
                    )
                    return f"[Fallback: {model.split('/')[-1]}] {final_response.choices[0].message.content}"
                
                return f"[Fallback: {model.split('/')[-1]}] {message.content}"
                
            except Exception as e:
                logger.warning(f"⚠️ Provider {model} failed: {e}")
                last_error = e
                continue
        
        return f"[Agent Error: All fallbacks failed. Last error: {str(last_error)}]"

    def _get_fallback_clients(self):
        """Yield available fallback providers in priority order"""
        if llm_service.openrouter_client:
             yield llm_service.openrouter_client, settings.openrouter_smart_model
        if llm_service.groq_client:
             yield llm_service.groq_client, settings.groq_smart_model

# Singleton instance
agent_service = AgentService()
