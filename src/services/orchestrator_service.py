"""
Orchestrator Service
====================

Coordinates the "Hybrid Brain" logic, managing the race conditions
and transitions between Fast (Reflex) and Smart (Agent) models.
"""

import asyncio
import logging
from typing import AsyncGenerator

from services.llm_service import llm_service
from services.agent_service import agent_service
from config import settings

logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------------
# Aura Persona & Prompts
# -----------------------------------------------------------------------------
AURA_SYSTEM_PROMPT = """You are Aura, the world's fastest AI secretary.
You are witty, efficient, and always helpful.
Keep responses concise and actionable.
If a tool fails or is unauthorized, report the error truthfully.
Do NOT fabricate or simulate data."""

AURA_FILLER_PROMPT = """You are Aura. The user asked a complex question that requires 
you to use tools (like checking calendars, searching the web, etc.).
Generate a very short, natural conversational filler to acknowledge you're working on it.
Examples: "Let me check that for you..." or "One moment, looking into that..."
Do NOT answer the actual question. Just acknowledge it briefly."""


class OrchestratorService:
    def __init__(self):
        # Services are singletons usually, but capturing them here is fine
        self.agent_service = agent_service
        self.llm_service = llm_service

    async def stream_fast_response(self, user_text: str) -> AsyncGenerator[str, None]:
        """
        FAST path: Direct streaming from Gemini Flash/Groq.
        """
        logger.info(f"⚡ [Orchestrator] FAST path for: {user_text[:30]}...")
        async for chunk in self.llm_service.get_reflex_response(user_text, AURA_SYSTEM_PROMPT):
            yield chunk

    async def stream_parallel_response(self, user_text: str, user_id: str) -> AsyncGenerator[str, None]:
        """
        SMART path: 3-Stage Parallel Speculative Loop.
        
        1. Fast Stall (Filler)
        2. Smart Agent (Background Task)
        3. Fast Transition (Smoother)
        """
        logger.info(f"🧠 [Orchestrator] SMART path for: {user_text[:30]}...")
        
        # 1. Start the Heavy Task (DO NOT AWAIT YET)
        smart_task = asyncio.create_task(
            self.agent_service.run_agent_loop(
                user_text,
                user_id,
                AURA_SYSTEM_PROMPT
            )
        )
        
        # 2. Stream the Filler
        filler_content = ""
        filler_prompt = f"The user asked: '{user_text}'. {AURA_FILLER_PROMPT}"
        
        # Don't show "Groq" for the filler
        async for chunk in self.llm_service.get_reflex_response(filler_prompt, "", include_model_header=False):
            filler_content += chunk
            yield chunk
        
        yield " "
        
        # 3. Await Smart Result
        try:
            smart_result = await smart_task
            logger.info("🧠 [Orchestrator] Smart Agent completed")
            
            # Explicit Attribution Logic
            if "[Fallback:" in smart_result or "[System Error:" in smart_result or "[Agent Error:" in smart_result:
                 pass 
            else:
                 yield f"||MODEL:{settings.gemini_smart_model}||"
            
            # 4. Third Fast Model: Smooth Transition
            transition_prompt = f"""
            You are context-aware. 
            You just said to the user: "{filler_content}"
            The result of the check is: "{smart_result}"
            
            Seamlessly continue your response from where you left off.
            Do NOT repeat what you already said.
            Format the result nicely.
            If the result error, apologize briefly.
            """
            
            # Disable auto-tagging so Groq doesn't overwrite "Gemini 3 Pro"
            async for chunk in self.llm_service.get_reflex_response(transition_prompt, AURA_SYSTEM_PROMPT, include_model_header=False):
                yield chunk
            
        except Exception as e:
            logger.error(f"Smart task failed: {e}")
            yield f"\n\n[System Error: {str(e)}]"

# Singleton
orchestrator_service = OrchestratorService()
