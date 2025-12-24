"""
Orchestrator Service
====================

Coordinates the "Hybrid Brain" logic, managing the race conditions
and transitions between Fast (Reflex) and Smart (Agent) models.
"""

import asyncio
import logging
import re
from typing import AsyncGenerator

from services.llm_service import llm_service
from services.agent_service import agent_service
from services.router_service import router_service
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

AURA_VOICE_PROMPT = """You are Aura, a friendly AI assistant responding via voice.
CRITICAL RULES for spoken responses:
- Use natural, conversational language
- NO markdown formatting (no asterisks, no bullet points, no headers)
- NO special characters or symbols
- Keep sentences short and clear
- Speak as if talking to a friend
- Be concise - voice responses should be brief"""

AURA_FILLER_PROMPT = """You are Aura. The user asked a complex question that requires 
you to use tools (like checking calendars, searching the web, etc.).
Generate a very short, natural conversational filler to acknowledge you're working on it.
Examples: "Let me check that for you..." or "One moment, looking into that..."
Do NOT answer the actual question. Just acknowledge it briefly.
Do NOT use any markdown or special formatting."""


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
    def __init__(self):
        self.agent_service = agent_service
        self.llm_service = llm_service
        self.router_service = router_service

    async def stream_fast_response(self, user_text: str) -> AsyncGenerator[str, None]:
        """
        FAST path: Direct streaming from Gemini Flash/Groq.
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
        
        if route == "FAST":
            # Simple response - direct fast path
            logger.info(f"🎤 [Voice] FAST path for: {user_text[:30]}...")
            async for chunk in self.llm_service.get_reflex_response(user_text, AURA_VOICE_PROMPT):
                yield clean_for_speech(chunk)
        else:
            # Complex response - use parallel speculative loop
            logger.info(f"🎤 [Voice] SMART path for: {user_text[:30]}...")
            async for chunk in self._stream_smart_voice(user_text, user_id):
                yield chunk

    async def _stream_smart_voice(self, user_text: str, user_id: str) -> AsyncGenerator[str, None]:
        """SMART path optimized for voice output."""
        # 1. Start the Heavy Task
        smart_task = asyncio.create_task(
            self.agent_service.run_agent_loop(user_text, user_id, AURA_VOICE_PROMPT)
        )
        
        # 2. Stream the Filler
        filler_content = ""
        filler_prompt = f"The user asked: '{user_text}'. {AURA_FILLER_PROMPT}"
        
        async for chunk in self.llm_service.get_reflex_response(filler_prompt, "", include_model_header=False):
            clean_chunk = clean_for_speech(chunk)
            filler_content += clean_chunk
            yield clean_chunk
        
        yield " "
        
        # 3. Await Smart Result
        try:
            smart_result = await smart_task
            smart_result = clean_for_speech(smart_result)
            logger.info("🎤 [Voice] Smart Agent completed")
            
            # 4. Smooth Transition
            transition_prompt = f"""You just said: "{filler_content}"
The result is: "{smart_result}"

Continue naturally from where you left off. Summarize the result conversationally.
Do NOT repeat what you already said.
Do NOT use any markdown, asterisks, or special formatting.
Speak naturally as if talking to a friend."""
            
            async for chunk in self.llm_service.get_reflex_response(transition_prompt, AURA_VOICE_PROMPT, include_model_header=False):
                yield clean_for_speech(chunk)
            
        except Exception as e:
            logger.error(f"Smart task failed: {e}")
            yield "Sorry, I encountered an error processing that request."

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
            
            # Check if result is from fallback provider
            is_fallback = "[Fallback:" in smart_result
            
            # Extract and yield the model attribution
            if is_fallback:
                # Extract fallback model name for attribution
                import re
                match = re.search(r'\[Fallback: ([^\]]+)\]', smart_result)
                if match:
                    yield f"||MODEL:{match.group(1)}||"
                # Remove the [Fallback: xxx] prefix for cleaner display
                smart_result = re.sub(r'\[Fallback: [^\]]+\]\s*', '', smart_result)
            elif "[System Error:" in smart_result or "[Agent Error:" in smart_result:
                pass  # Don't add model tag for errors
            else:
                yield f"||MODEL:{settings.gemini_smart_model}||"
            
            # IMPORTANT: Directly yield the smart result instead of reprocessing
            # The smart agent already produced a well-formatted response with all the data
            yield smart_result
            
        except Exception as e:
            logger.error(f"Smart task failed: {e}")
            yield f"\n\n[System Error: {str(e)}]"

# Singleton
orchestrator_service = OrchestratorService()

