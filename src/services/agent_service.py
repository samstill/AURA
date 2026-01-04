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
from .calendar_tools import CALENDAR_TOOL_DEFINITIONS, execute_calendar_tool
from config import settings

logger = logging.getLogger(__name__)


# Risk classification for autonomy guardrail
TOOL_RISK_LEVELS = {
    # Safe - always auto-execute
    "get_detailed_schedule": "low",
    "search_events": "low",
    "get_next_event": "low",
    "find_free_slots": "low",
    "list_user_calendars": "low",
    "check_calendar_availability": "low",
    "get_daily_summary": "low",
    "find_conflicts": "low",
    
    # Medium - ask in minimal mode
    "create_calendar_event": "medium",
    "update_calendar_event": "medium",
    "reschedule_event": "medium",
    "block_focus_time": "medium",
    
    # High - ask in half/minimal mode
    "delete_calendar_event": "high",
    "cancel_events_in_range": "high",
}


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
    
    def _check_action_safety(self, tool_name: str, tool_args: dict, autonomy: str) -> dict:
        """
        Check if an action should be executed or needs confirmation.
        
        Returns:
            {"safe": True} if action can proceed
            {"safe": False, "reason": "...", "risk": "high/medium"} if needs confirmation
        """
        risk = TOOL_RISK_LEVELS.get(tool_name, "low")
        
        # FULL mode - everything is safe
        if autonomy == "full":
            return {"safe": True}
        
        # HALF mode - only high-risk needs confirmation
        if autonomy == "half":
            if risk == "high":
                return {
                    "safe": False,
                    "reason": f"This action ({tool_name}) requires confirmation in half autonomy mode.",
                    "risk": risk,
                    "tool": tool_name,
                    "params": tool_args
                }
            return {"safe": True}
        
        # MINIMAL mode - medium and high need confirmation
        if autonomy == "minimal":
            if risk in ("medium", "high"):
                return {
                    "safe": False,
                    "reason": f"This action ({tool_name}) requires confirmation in minimal autonomy mode.",
                    "risk": risk,
                    "tool": tool_name,
                    "params": tool_args
                }
            return {"safe": True}
        
        return {"safe": True}
    
    def _build_confirmation_response(self, tool_name: str, tool_args: dict, risk: str, source: str = "text") -> str:
        """Build a confirmation request response."""
        # Extract readable info from args
        title = tool_args.get("title", tool_args.get("event_id", "event"))
        
        if source == "voice":
            # Verbal prompt for voice mode
            if tool_name == "delete_calendar_event":
                return f"I need your permission to delete '{title}'. Say 'yes' to confirm or 'no' to cancel."
            elif tool_name == "cancel_events_in_range":
                return f"This will cancel multiple events. Say 'yes' to confirm or 'no' to cancel."
            else:
                return f"Should I proceed with this action? Say 'yes' to confirm."
        else:
            # Structured response for text/UI mode
            return json.dumps({
                "status": "waiting_confirmation",
                "pending_action": {
                    "tool": tool_name,
                    "params": tool_args,
                    "risk_level": risk
                },
                "message": f"I need your permission to execute '{tool_name}'. Reply 'yes' to confirm.",
                "voice_prompt": f"Should I proceed with {tool_name}? Say yes to confirm."
            })
    
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
            mcp_tools, tool_clients, builtin_tools = await self._load_mcp_tools(user_id)
        except Exception as e:
            logger.error(f"Failed to load tools: {e}")
            return "I apologize, but I cannot access my tool functions at the moment. Please contact support."

        try:
            # Add Dynamic Context
            current_context = f"Current Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}. "
            full_system_prompt = f"{current_context}{system_prompt}"

            # Initialize Model
            # We construct the tool definitions manually for Gemini
            # gemini_tools argument: Iterable[Tool | Callable | FunctionDeclaration]
            # We wrap our schemas in FunctionDeclaration
            
            gemini_tool_declarations = []
            
            # Add MCP tools
            if mcp_tools:
                for t in mcp_tools:
                    gemini_tool_declarations.append(
                        FunctionDeclaration(
                            name=t["name"],
                            description=t["description"],
                            parameters=t["parameters"]
                        )
                    )
            
            # Add built-in calendar tools
            for t in builtin_tools:
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
                
                # Check if it's a built-in calendar tool
                builtin_tool_names = [t["name"] for t in builtin_tools]
                if fn_name in builtin_tool_names:
                    # Execute built-in calendar tool
                    try:
                        result_text = await execute_calendar_tool(fn_name, fn_args, user_id)
                    except Exception as e:
                        result_text = f"Error executing calendar tool {fn_name}: {str(e)}"
                elif fn_name in tool_clients:
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
                response = await chat.send_message_async(
                    {
                        "function_response": {
                            "name": fn_name,
                            "response": {"result": result_text}
                        }
                    }
                )

            return response.text

        except Exception as e:
            logger.warning(f"⚠️ Gemini Pro failed: {e}. Switching to Smart Fallback.")
            return await self._run_fallback_agent(user_query, full_system_prompt, mcp_tools, tool_clients, builtin_tools)

    async def _load_mcp_tools(self, user_id: str) -> Tuple[List[Dict], Dict[str, RemoteMCPClient], List[Dict]]:
        """
        Fetch tools from DB and Query MCP servers for definitions.
        Also includes built-in tools like calendar.
        
        Returns:
            list of MCP tool definitions,
            dict of {tool_name: mcp_client_instance},
            list of built-in tool definitions
        """
        gemini_defs = []
        client_map = {}
        
        # Skip MCP tool loading for non-UUID user IDs (like 'test-user' in dev mode)
        import re
        uuid_pattern = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)
        
        if uuid_pattern.match(user_id):
            user_tools_config = await tool_manager.get_active_tools_for_user(user_id)
            
            # Load MCP tools for valid UUID users
            for config in user_tools_config:
                try:
                    tool_config = config.get("config", {}) or {}
                    transport = tool_config.get("transport", "http")
                    client = RemoteMCPClient(config["mcp_endpoint"], tool_config, transport=transport)
                    
                    # Discovery
                    mcp_list = await client.list_tools()
                    
                    for tool in mcp_list:
                        # Map MCP Tool to Gemini Schema
                        g_tool = {
                            "name": tool["name"],
                            "description": tool.get("description", ""),
                            "parameters": tool.get("inputSchema", {})
                        }
                        gemini_defs.append(g_tool)
                        client_map[tool["name"]] = client
                        
                except Exception as e:
                    logger.error(f"Failed to load tools from {config.get('mcp_endpoint', 'unknown')}: {e}")
        else:
            logger.info(f"📝 [Agent] Skipping MCP tool loading for dev user '{user_id}'")
        
        # Add built-in calendar tools
        builtin_tools = list(CALENDAR_TOOL_DEFINITIONS)
        logger.info(f"📅 [Agent] Loaded {len(builtin_tools)} built-in calendar tools")
                
        return gemini_defs, client_map, builtin_tools

    async def _run_fallback_agent(
        self, 
        user_query: str, 
        system_prompt: str,
        mcp_tools: List[Dict],
        tool_clients: Dict[str, RemoteMCPClient],
        builtin_tools: List[Dict] = None
    ) -> str:
        """
        Fallback to Groq/OpenRouter with manual tool calling loop.
        CRITICAL: Includes anti-hallucination prompt for secretarial actions.
        """
        last_error = None
        
        # Get current time for context - Convert to IST (UTC+5:30)
        from datetime import datetime, timezone, timedelta
        utc_now = datetime.now(timezone.utc)
        ist_offset = timedelta(hours=5, minutes=30)
        ist_now = utc_now + ist_offset
        
        # Format for clarity
        ist_time_str = ist_now.strftime("%Y-%m-%d %H:%M IST")
        ist_date_str = ist_now.strftime("%A, %B %d, %Y")
        tomorrow = (ist_now + timedelta(days=1)).strftime("%A, %B %d, %Y")
        
        # Build autonomy-specific instructions FIRST
        autonomy_level = settings.agent_autonomy.lower()
        if autonomy_level == "full":
            autonomy_instructions = """You have FULL autonomy. Execute all actions without asking for confirmation. 
Keep iterating and calling tools until the user's goal is completely achieved.
Analyze results, reiterate if needed, and only stop when the task is done."""
        elif autonomy_level == "half":
            autonomy_instructions = """You have HALF autonomy. 
- Auto-execute: read, search, create, update actions
- ASK before: delete, cancel, or bulk operations
For destructive actions, explain what you're about to do and wait for confirmation."""
        else:  # minimal
            autonomy_instructions = """You have MINIMAL autonomy.
- Auto-execute: read and search actions only
- ASK before: create, update, delete, or any write action
Always explain what you plan to do and ask for confirmation before modifying anything."""
        
        # Anti-hallucination prompt for calendar/secretarial actions
        anti_hallucination = f"""

CURRENT DATE & TIME (User's timezone - IST/India):
- Right now: {ist_time_str}
- TODAY is: {ist_date_str}
- TOMORROW is: {tomorrow}

CRITICAL: When user says "today", use {ist_now.strftime("%Y-%m-%d")}.
When user says "tomorrow", use {(ist_now + timedelta(days=1)).strftime("%Y-%m-%d")}.
Do NOT schedule things in the past. If it's night (after 9pm), focus on tomorrow's schedule.
Use this time context for all calendar operations.

SCHEDULING INTELLIGENCE (Common Sense Rules):
1. BUFFER TIME: Always leave 15-30 min between events for:
   - Travel events → next event (need time to settle)
   - Workout → next event (need shower/rest)
   - Back-to-back meetings (mental break)
2. REALISTIC TIMING: Don't schedule:
   - Workouts at odd hours (before 6am or after 10pm)
   - Work calls during common meal times (12-1pm, 7-8pm) unless user specifies
   - Multiple high-energy activities back-to-back
3. CONTEXT AWARENESS:
   - If user has travel event, they may be tired after → suggest lighter activities
   - Check existing events for conflicts AND for logical flow
   - Consider travel time if events are at different locations
4. SMART SUGGESTIONS: When scheduling, proactively mention if:
   - The slot is tight (less than 30 min buffer)
   - There's a better alternative time
   - The schedule looks exhausting
5. WORK-LIFE BALANCE: Flag if user's day exceeds 10 hours of events

TOOL USAGE RULES:
1. You HAVE access to calendar tools. USE THEM when the user asks you to check, create, update, or delete events.
2. When the user asks to schedule something, you MUST call the appropriate tool (create_calendar_event, find_free_slots, etc.)
3. NEVER say "I'm unable to modify your calendar" if you have tools available - just USE the tools!
4. NEVER fabricate results - only report what the tool actually returns.
5. If a tool call fails, report the actual error message.
6. For multi-step tasks (e.g., "find a slot and book it"), call multiple tools in sequence.

SMART CALENDAR SELECTION:
When creating events, choose the MOST APPROPRIATE calendar based on event type:
- TV, movies, shows, streaming → "Entertainment" calendar
- Workout, gym, exercise, yoga → "Workout" calendar  
- Work, meetings, calls → "Work" or primary calendar
- Personal, family, friends → "Personal" calendar

IMPORTANT FALLBACK LOGIC:
1. FIRST call list_user_calendars to see what calendars the user actually has.
2. Pick the best matching calendar from the available ones.
3. If no matching calendar exists (e.g., no "Entertainment" for a TV show), use primary BUT mention:
   "I've added this to your primary calendar. You might want to create an Entertainment calendar for these events."
4. Always confirm which calendar you're using in your response.

CRITICAL - UPDATING EVENTS:
When updating or rescheduling an event, you MUST include the calendar_name from the event data.
Each event from get_detailed_schedule includes: "calendar": "Workout" and "calendar_id": "..."
ALWAYS pass calendar_name when calling update_calendar_event or reschedule_event!
Recurring events (is_recurring: true) CAN be updated - just include the calendar_name.

Available calendar tools: get_detailed_schedule, create_calendar_event, delete_calendar_event, update_calendar_event, search_events, find_free_slots, get_next_event, reschedule_event, find_conflicts, get_daily_summary, block_focus_time, cancel_events_in_range, list_user_calendars

AUTONOMY LEVEL: {autonomy_level.upper()}
{autonomy_instructions}
"""
        enhanced_system_prompt = system_prompt + anti_hallucination
        
        for client, model in self._get_fallback_clients():
            logger.info(f"🛡️ [Fallback] Trying {model}...")
            
            try:
                messages = [
                    {"role": "system", "content": enhanced_system_prompt},
                    {"role": "user", "content": user_query}
                ]
                
                # Convert tools format to OpenAI Schema
                # Include BOTH MCP tools and built-in calendar tools
                openai_tools = []
                all_tools = list(mcp_tools)
                if builtin_tools:
                    all_tools.extend(builtin_tools)
                
                for t in all_tools:
                    openai_tools.append({
                        "type": "function",
                        "function": {
                            "name": t["name"],
                            "description": t["description"],
                            "parameters": t["parameters"]
                        }
                    })

                # Use configured max iterations based on autonomy level
                max_turns = settings.agent_max_iterations
                autonomy = settings.agent_autonomy.lower()
                
                # Destructive actions that need confirmation in half/minimal mode
                destructive_tools = {"delete_calendar_event", "cancel_events_in_range"}
                write_tools = {"create_calendar_event", "update_calendar_event", "reschedule_event", "block_focus_time"}
                
                for turn in range(max_turns):
                    response = await client.chat.completions.create(
                        model=model,
                        messages=messages,
                        tools=openai_tools if openai_tools else None,
                        tool_choice="auto" if openai_tools else "none"
                    )
                    
                    message = response.choices[0].message
                    
                    # If no tool calls, we have our final answer
                    if not message.tool_calls:
                        return f"[Fallback: {model.split('/')[-1]}] {message.content}"
                    
                    # Handle tool calls
                    logger.info(f"🛠️ [Fallback] Turn {turn+1}: Model requested {len(message.tool_calls)} tools")
                    messages.append(message)
                    
                    # Execute each tool
                    for tool_call in message.tool_calls:
                        fn_name = tool_call.function.name
                        fn_args = json.loads(tool_call.function.arguments)
                        
                        # AUTONOMY GUARDRAIL: Check if action needs confirmation
                        safety_check = self._check_action_safety(fn_name, fn_args, autonomy)
                        if not safety_check.get("safe", True):
                            logger.info(f"   🛑 [Guardrail] Action {fn_name} needs confirmation (risk: {safety_check['risk']})")
                            # Return confirmation request instead of executing
                            confirmation_msg = self._build_confirmation_response(
                                fn_name, fn_args, safety_check["risk"], "text"
                            )
                            return f"[Fallback: {model.split('/')[-1]}] {confirmation_msg}"
                        
                        logger.info(f"   Executing {fn_name}({fn_args})")
                        
                        result_str = ""
                        
                        # Check if it's a builtin calendar tool
                        builtin_tool_names = [t["name"] for t in (builtin_tools or [])]
                        if fn_name in builtin_tool_names:
                            try:
                                result_str = await execute_calendar_tool(fn_name, fn_args, "test-user")
                                logger.info(f"   📅 Calendar tool result: {result_str[:100]}...")
                            except Exception as e:
                                result_str = f"Error executing calendar tool: {str(e)}"
                        elif fn_name in tool_clients:
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
                            "content": result_str
                        })
                
                # If we exhausted turns, get final answer
                final_response = await client.chat.completions.create(
                    model=model,
                    messages=messages
                )
                return f"[Fallback: {model.split('/')[-1]}] {final_response.choices[0].message.content}"
                
            except Exception as e:
                logger.warning(f"⚠️ Provider {model} failed: {e}")
                last_error = e
                continue
        
        # If we get here, all fallbacks failed
        logger.error(f"❌ All agents failed. Last error: {last_error}")
        return "I apologize, but I'm having trouble accessing my tools right now. Please try again in a moment."

    def _get_fallback_clients(self):
        """Yield available fallback providers in priority order (best tool-calling first)"""
        # Priority 1: OpenAI (best tool calling, most reliable)
        if llm_service.openai_client:
            yield llm_service.openai_client, settings.openai_smart_model
        
        # Priority 2: DeepSeek (excellent tool calling, cheaper)
        if llm_service.deepseek_client:
            yield llm_service.deepseek_client, settings.deepseek_model
        
        # Priority 3: OpenRouter (various models)
        if llm_service.openrouter_client:
            yield llm_service.openrouter_client, settings.openrouter_smart_model
        
        # Priority 4: Groq (fast but tool calling can be buggy)
        if llm_service.groq_client:
            yield llm_service.groq_client, settings.groq_smart_model

# Singleton instance
agent_service = AgentService()
