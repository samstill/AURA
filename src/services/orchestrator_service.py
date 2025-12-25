"""
Orchestrator Service - Aura Routing Algorithm
==============================================

Implements the full "Secretary Protocol" for speculative execution
and latency masking.

Core Philosophy: "Always acknowledge instantly, deliver answers continuously,
and process heavy loads asynchronously."

Algorithm Flow:
1. Phase A: Ingestion & Smart Classification
   - Semantic cache check (10ms hit)
   - Context-aware classifier with tool registry
   
2. Phase B: Parallel Execution (Secretary Protocol)
   - Thread 1: Staller streaming
   - Thread 2: Agent execution
   
3. Phase C: Stitcher & Soft Timeout
   - Perfect stitch if agent ready < 1.0s
   - Grace period (500ms) if agent started
   - Handoff to async if > 1.5s
   
4. Phase D: Async Handoff
   - Close staller gracefully
   - Background processing continues
   - Result sent to Analyst
"""

import asyncio
import logging
import re
import time
from typing import AsyncGenerator, Optional, Dict

from services.llm_service import llm_service
from services.agent_service import agent_service
from services.router_service import router_service, ClassificationContext
from services.staller_service import staller_service, StallerContext, Sentiment, Category
from services.stitcher_service import stitcher_service
from services.analyst_service import analyst_service
from services.semantic_cache_service import semantic_cache_service
from services.tool_manager import tool_manager
from config import settings

logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
HARD_TIMEOUT = getattr(settings, 'aura_hard_timeout', 1.0)  # seconds
GRACE_PERIOD = getattr(settings, 'aura_grace_period', 0.5)  # seconds
MAX_ASYNC_WAIT = getattr(settings, 'aura_max_async_wait', 30.0)  # seconds

# -----------------------------------------------------------------------------
# Aura Persona & Prompts
# -----------------------------------------------------------------------------
AURA_SYSTEM_PROMPT = """You are Aura, the world's fastest AI secretary.
You are witty, efficient, and always helpful.
Keep responses concise and actionable.
If a tool fails or is unauthorized, report the error truthfully.
Do NOT fabricate or simulate data."""

AURA_VOICE_PROMPT = """You are Aura, a friendly AI assistant responding via voice.
CRITICAL RULES for spoken responses:
- Use natural, conversational language
- NO markdown formatting (no asterisks, no bullet points, no headers)
- NO special characters or symbols
- Keep sentences short and clear
- Speak as if talking to a friend
- Be concise - voice responses should be brief"""


def clean_for_speech(text: str) -> str:
    """Remove markdown and special characters for TTS."""
    # Remove model tags
    text = re.sub(r'\|\|MODEL:.*?\|\|', '', text)
    # Remove markdown bold/italic
    text = re.sub(r'\*\*?(.*?)\*\*?', r'\1', text)
    # Remove markdown headers
    text = re.sub(r'^#+\s*', '', text, flags=re.MULTILINE)
    # Remove bullet points
    text = re.sub(r'^[\-\*•]\s*', '', text, flags=re.MULTILINE)
    # Remove code blocks
    text = re.sub(r'`{1,3}[^`]*`{1,3}', '', text)
    # Remove brackets
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)  # markdown links
    text = re.sub(r'\[|\]', '', text)
    # Clean up extra whitespace
    text = re.sub(r'\n{2,}', '. ', text)
    text = re.sub(r'\s{2,}', ' ', text)
    return text.strip()


class OrchestratorService:
    """
    Orchestrates the Aura Routing Algorithm.
    
    Implements speculative execution with the Secretary Protocol:
    - Instant acknowledgment via Staller
    - Parallel heavy processing via Agent
    - Seamless stitching of responses
    - Async handoff for long-running tasks
    """
    
    def __init__(self):
        self.agent_service = agent_service
        self.llm_service = llm_service
        self.router_service = router_service
        self.staller_service = staller_service
        self.stitcher_service = stitcher_service
        self.analyst_service = analyst_service
        self.semantic_cache = semantic_cache_service
    
    def initialize(self):
        """Initialize orchestrator and sub-services."""
        self.staller_service.initialize()
        self.analyst_service.initialize()
        try:
            self.semantic_cache.initialize()
        except Exception as e:
            logger.warning(f"Semantic cache init failed (continuing without cache): {e}")
        logger.info("✅ Orchestrator Service initialized (Aura Algorithm)")
    
    # =========================================================================
    # Main Orchestration Entry Point
    # =========================================================================
    async def orchestrate_response(
        self, 
        user_query: str, 
        user_id: str,
        tool_registry: Optional[Dict[str, bool]] = None
    ) -> AsyncGenerator[str, None]:
        """
        Main orchestration entry point implementing the Aura Algorithm.
        
        Flow:
        1. Semantic cache check
        2. Context-aware classification
        3. Route to appropriate handler
        
        Args:
            user_query: User's input
            user_id: User ID for tool hydration and cache isolation
            tool_registry: Dict of available tools (fetched if not provided)
            
        Yields:
            Response chunks for streaming
        """
        # Fetch tool registry if not provided
        if tool_registry is None:
            try:
                tools = await tool_manager.get_active_tools_for_user(user_id)
                tool_registry = {t.get("name", ""): True for t in tools if t.get("name")}
                # Add calendar as built-in tool
                tool_registry["calendar"] = True
            except Exception as e:
                logger.warning(f"Tool registry fetch failed: {e}")
                tool_registry = {"calendar": True}  # Default: calendar available
        
        # =====================================================================
        # Phase A: Ingestion & Smart Classification
        # =====================================================================
        
        # 1. Semantic Cache Check (10ms target)
        try:
            cache_hit = await self.semantic_cache.check(user_query, user_id)
            if cache_hit:
                logger.info(f"🎯 [Orchestrator] Cache hit ({cache_hit.source})")
                yield cache_hit.response
                return
        except Exception as e:
            logger.debug(f"Cache check skipped: {e}")
        
        # 2. Generate tools context for LLM classification
        from services.tool_registry import tool_registry as tool_reg
        try:
            available_tools = await tool_reg.get_available_tools(user_id)
            tools_context = tool_reg.get_tools_context_for_llm(available_tools)
            # Update tool_registry with actual available tools
            tool_registry = tool_reg.get_tool_registry_dict(available_tools)
        except Exception as e:
            logger.warning(f"Tool registry context generation failed: {e}")
            tools_context = "calendar (schedule events, check availability)"
        
        # 3. Context-Aware Classification with LLM
        context = await self.router_service.classify_with_context(user_query, tool_registry, tools_context)
        logger.info(f"📍 [Orchestrator] Route: {context.route} | Tool: {context.tool_needed}")
        
        # =====================================================================
        # Route Based on Classification
        # =====================================================================
        
        if context.route == "FAST_SOLVER":
            # Simple query - direct fast path
            async for chunk in self._handle_fast_solver(user_query, user_id):
                yield chunk
                
        elif context.route == "FAST_ERROR":
            # Tool missing - fast error response
            async for chunk in self._handle_fast_error(context):
                yield chunk
                
        elif context.route == "SECRETARY_PROTOCOL":
            # Complex query - full Secretary Protocol
            async for chunk in self._handle_secretary_protocol(user_query, user_id, context):
                yield chunk
    
    # =========================================================================
    # Route Handlers
    # =========================================================================
    
    async def _handle_fast_solver(
        self, 
        user_query: str, 
        user_id: str
    ) -> AsyncGenerator[str, None]:
        """
        FAST_SOLVER path: Direct response from fast model.
        
        For simple queries that don't need tool use.
        Caches the response for future semantic matching.
        """
        logger.info(f"⚡ [Orchestrator] FAST path for: {user_query[:30]}...")
        
        full_response = ""
        async for chunk in self.llm_service.get_reflex_response(user_query, AURA_SYSTEM_PROMPT):
            full_response += chunk
            yield chunk
        
        # Cache the response
        try:
            await self.semantic_cache.store(user_query, full_response, user_id)
        except Exception as e:
            logger.debug(f"Cache store skipped: {e}")
    
    async def _handle_fast_error(
        self, 
        context: ClassificationContext
    ) -> AsyncGenerator[str, None]:
        """
        FAST_ERROR path: Tool is not connected.
        
        Returns a fast, friendly error without invoking heavy models.
        Saves GPU resources by not attempting tool execution.
        """
        tool_name = context.tool_needed or "the required tool"
        
        # Friendly error messages per tool
        error_messages = {
            "calendar": f"📅 It looks like I need access to your calendar for this. Please connect your Google Calendar in Settings first!",
            "email": f"📧 I'd need access to your email for this. Please connect your email account in Settings.",
            "jira": f"🎫 I can't access Jira yet. Please connect your Jira workspace in Settings to enable this.",
            "github": f"🐙 I need access to your GitHub to help with this. Connect it in Settings!",
            "spotify": f"🎵 Music control requires Spotify connection. Set it up in Settings!",
            "slack": f"💬 I need Slack access for this. Please connect your workspace in Settings.",
        }
        
        error = error_messages.get(
            tool_name, 
            f"🔧 You need to connect {tool_name} first. Head to Settings to set it up!"
        )
        
        logger.info(f"⚠️ [Orchestrator] FAST_ERROR: {tool_name} not connected")
        yield error
    
    async def _handle_secretary_protocol(
        self, 
        user_query: str, 
        user_id: str,
        context: ClassificationContext
    ) -> AsyncGenerator[str, None]:
        """
        SECRETARY_PROTOCOL: Full speculative execution.
        
        Phase B: Parallel Execution
        - Thread 1: Staller streams acknowledgment
        - Thread 2: Agent processes query
        
        Phase C: Stitcher & Timeout
        - Monitor for agent completion
        - Stitch if ready < 1.0s
        - Grace period if agent started
        - Handoff if > 1.5s
        """
        logger.info(f"🧠 [Orchestrator] Secretary Protocol for: {user_query[:30]}...")
        
        # Build staller context - map enums by string value to avoid import conflicts
        try:
            sentiment_value = context.sentiment.value if hasattr(context.sentiment, 'value') else str(context.sentiment)
            category_value = context.category.value if hasattr(context.category, 'value') else str(context.category)
            staller_sentiment = Sentiment(sentiment_value)
            staller_category = Category(category_value) if category_value in [c.value for c in Category] else Category.GENERAL
        except (ValueError, KeyError):
            staller_sentiment = Sentiment.NEUTRAL
            staller_category = Category.GENERAL
        
        staller_context = StallerContext(
            query=user_query,
            sentiment=staller_sentiment,
            category=staller_category,
            tool_name=context.tool_needed,
            tool_available=context.tool_available
        )
        
        # =====================================================================
        # Phase B: Start Parallel Tasks
        # =====================================================================
        
        # Thread 2: Start Agent (Heavy Task) - DO NOT AWAIT
        agent_task = asyncio.create_task(
            self.agent_service.run_agent_loop(
                user_query,
                user_id,
                AURA_SYSTEM_PROMPT
            )
        )
        
        # Thread 1: Stream Staller (hybrid: instant template + LLM enhancement)
        staller_buffer = ""
        staller_tokens = []
        start_time = time.time()
        
        # Use LLM-enhanced staller (template yields first for instant response)
        async for chunk in self.staller_service.stream_stall(staller_context, use_llm=True):
            elapsed = time.time() - start_time
            
            # Check if agent is done while streaming staller
            if agent_task.done():
                # Agent finished during staller - perfect stitch!
                try:
                    agent_result = agent_task.result()
                    logger.info(f"🪡 [Orchestrator] Perfect stitch at {elapsed:.2f}s")
                    
                    # Yield remaining staller content
                    staller_buffer += chunk.content
                    yield chunk.content
                    
                    # Stitch and yield agent result
                    stitch_result = self.stitcher_service.stitch(staller_buffer, agent_result)
                    
                    # Extract just the agent portion (staller already yielded)
                    agent_portion = stitch_result.text[len(staller_buffer):].lstrip()
                    yield agent_portion
                    
                    # Cache the full response
                    try:
                        await self.semantic_cache.store(
                            user_query, 
                            stitch_result.text, 
                            user_id
                        )
                    except Exception:
                        pass
                    
                    return
                except Exception as e:
                    logger.error(f"Agent task error during stitch: {e}")
                    yield f"\n\n[Error: {str(e)}]"
                    return
            
            # Track staller output
            staller_buffer += chunk.content
            staller_tokens.append(chunk.content)
            
            # Yield staller chunks (but hold buffer for potential stitching)
            if not chunk.is_buffer:
                yield chunk.content
        
        # Yield the buffer now that staller is done
        buffer_text = "".join(staller_tokens[-3:]) if len(staller_tokens) >= 3 else ""
        yield buffer_text
        
        # =====================================================================
        # Phase C: Soft Timeout & Stitching
        # =====================================================================
        
        elapsed = time.time() - start_time
        
        # Check 1: Agent done within hard timeout?
        if elapsed < HARD_TIMEOUT:
            remaining = HARD_TIMEOUT - elapsed
            
            try:
                agent_result = await asyncio.wait_for(agent_task, timeout=remaining)
                logger.info(f"🪡 [Orchestrator] Stitch after staller at {time.time() - start_time:.2f}s")
                
                # Stitch and yield
                stitch_result = self.stitcher_service.stitch(staller_buffer, agent_result)
                agent_portion = stitch_result.text[len(staller_buffer):].lstrip()
                
                # Add model attribution if available
                if hasattr(settings, 'gemini_smart_model'):
                    yield f" ||MODEL:{settings.gemini_smart_model}||"
                
                yield agent_portion
                
                # Cache
                try:
                    await self.semantic_cache.store(user_query, stitch_result.text, user_id)
                except Exception:
                    pass
                
                return
                
            except asyncio.TimeoutError:
                pass  # Continue to grace period
        
        # Check 2: Grace Period - agent started generating?
        # In a real implementation, we'd check agent_task for stream_start signal
        # For now, we give an extra grace period
        
        try:
            agent_result = await asyncio.wait_for(agent_task, timeout=GRACE_PERIOD)
            logger.info(f"🪡 [Orchestrator] Stitch in grace period at {time.time() - start_time:.2f}s")
            
            stitch_result = self.stitcher_service.stitch(staller_buffer, agent_result)
            agent_portion = stitch_result.text[len(staller_buffer):].lstrip()
            
            yield f" ||MODEL:{settings.gemini_smart_model}||"
            yield agent_portion
            
            try:
                await self.semantic_cache.store(user_query, stitch_result.text, user_id)
            except Exception:
                pass
            
            return
            
        except asyncio.TimeoutError:
            pass  # Fall through to async handoff
        
        # =====================================================================
        # Phase D: Async Handoff
        # =====================================================================
        
        logger.info(f"⏰ [Orchestrator] Timeout - handing off to async processing")
        
        # Cancel the original agent task - it will be restarted by the analyst
        agent_task.cancel()
        
        # Close staller loop gracefully
        timeout_message = await self.staller_service.generate_timeout_message(staller_context)
        yield " " + timeout_message
        
        # Hand off to Analyst for background processing
        # Pass the agent service, not the task - analyst will start a new independent agent call
        task_id = await self.analyst_service.process_background_task(
            query=user_query,
            user_id=user_id,
            agent_service=self.agent_service,
            system_prompt=AURA_SYSTEM_PROMPT
        )
        
        yield f"\n\n[Task ID: {task_id} - You'll be notified when ready]"
    
    # =========================================================================
    # Legacy Methods (Backward Compatibility)
    # =========================================================================
    
    async def stream_fast_response(self, user_text: str) -> AsyncGenerator[str, None]:
        """
        FAST path: Direct streaming from Gemini Flash/Groq.
        Legacy method for backward compatibility.
        """
        logger.info(f"⚡ [Orchestrator] FAST path for: {user_text[:30]}...")
        async for chunk in self.llm_service.get_reflex_response(user_text, AURA_SYSTEM_PROMPT):
            yield chunk

    async def stream_voice_response(self, user_text: str, user_id: str) -> AsyncGenerator[str, None]:
        """
        Voice-optimized response with automatic FAST/SMART routing.
        Outputs clean, speakable text without markdown.
        """
        # Route the request
        route = await self.router_service.classify(user_text)
        
        if route == "FAST_SOLVER":
            # Simple response - direct fast path
            logger.info(f"🎤 [Voice] FAST path for: {user_text[:30]}...")
            async for chunk in self.llm_service.get_reflex_response(user_text, AURA_VOICE_PROMPT):
                yield clean_for_speech(chunk)
        else:
            # Complex response - use orchestration
            logger.info(f"🎤 [Voice] SMART path for: {user_text[:30]}...")
            async for chunk in self.orchestrate_response(user_text, user_id):
                yield clean_for_speech(chunk)

    async def stream_parallel_response(self, user_text: str, user_id: str) -> AsyncGenerator[str, None]:
        """
        SMART path: Full Secretary Protocol.
        Legacy method - routes to orchestrate_response.
        """
        async for chunk in self.orchestrate_response(user_text, user_id):
            yield chunk


# Singleton
orchestrator_service = OrchestratorService()
