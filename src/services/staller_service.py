"""
Staller Service - Psychological Masking
========================================

Generates context-aware filler text to mask latency while the
heavy Agent model processes complex queries.

Part of the Aura Routing Algorithm - Phase B (Secretary Protocol / Thread 1).

Key Features:
- Safe Verbs Protocol: Only uses generic action verbs
- Tool-Aware: Mentions specific tools only if confirmed available
- Sentiment-Aware: Adjusts tone based on query sentiment
- Buffer Window: Holds last 3 tokens for potential stitching
"""

import logging
import re
from typing import AsyncGenerator, Optional, List
from dataclasses import dataclass
from enum import Enum

from services.llm_service import llm_service

logger = logging.getLogger(__name__)


class Sentiment(Enum):
    """Query sentiment classification."""
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"
    URGENT = "urgent"


class Category(Enum):
    """Query category for context-aware responses."""
    EMOTIONAL = "emotional"
    TECHNICAL = "technical"
    CALENDAR = "calendar"
    SEARCH = "search"
    GENERAL = "general"


@dataclass
class StallerContext:
    """Context passed to the staller for generating appropriate filler."""
    query: str
    sentiment: Sentiment
    category: Category
    tool_name: Optional[str] = None
    tool_available: bool = False


@dataclass
class StallerChunk:
    """A chunk of staller output with metadata."""
    content: str
    is_final: bool = False
    is_buffer: bool = False  # True if this is part of the buffer window


class StallerService:
    """
    Generates context-aware stalling text for latency masking.
    
    The staller creates natural-sounding acknowledgments while the
    heavy Agent model processes the actual request in parallel.
    
    Safety Protocols:
    1. Safe Verbs: Only uses generic verbs like "Reviewing", "Checking"
    2. Tool Registry: Never mentions a tool unless confirmed available
    3. No Promises: Never claims an action is done, only that it's in progress
    """
    
    # Safe verbs that don't imply completion
    SAFE_VERBS = [
        "Reviewing",
        "Checking",
        "Looking into",
        "Accessing",
        "Connecting to",
        "Searching through",
        "Analyzing",
        "Processing",
    ]
    
    # Tool-specific verbs (only used when tool is confirmed available)
    TOOL_VERBS = {
        "calendar": ["Checking your calendar", "Looking at your schedule", "Accessing your events"],
        "email": ["Checking your inbox", "Looking through your emails"],
        "jira": ["Connecting to your Jira board", "Accessing your Jira workspace"],
        "github": ["Checking your repositories", "Looking at your GitHub"],
        "search": ["Searching the web", "Looking that up for you"],
        "spotify": ["Checking Spotify", "Looking at your music"],
    }
    
    # Sentiment-based tone prefixes
    SENTIMENT_TONES = {
        Sentiment.POSITIVE: "",  # Normal tone
        Sentiment.NEGATIVE: "I understand. ",  # Empathetic
        Sentiment.NEUTRAL: "",
        Sentiment.URGENT: "On it! ",  # Quick acknowledgment
    }
    
    # Category-specific acknowledgments
    CATEGORY_ACKS = {
        Category.EMOTIONAL: "I hear you. Let me think about this",
        Category.TECHNICAL: "Let me analyze that",
        Category.CALENDAR: "Checking your schedule",
        Category.SEARCH: "Searching for that information",
        Category.GENERAL: "Let me look into that",
    }
    
    def __init__(self):
        self.buffer_size = 3  # Number of tokens to hold for stitching
        self._llm_service = None
    
    def initialize(self):
        """Initialize the staller with LLM service reference."""
        self._llm_service = llm_service
        logger.info("✅ Staller Service initialized")
    
    def _build_prompt(self, context: StallerContext) -> str:
        """
        Build a constrained prompt for the staller LLM.
        
        The prompt enforces safe verbs and tool awareness.
        """
        tone = self.SENTIMENT_TONES.get(context.sentiment, "")
        
        # Determine what verb/phrase to use
        if context.tool_name and context.tool_available:
            # Tool is confirmed available - can mention it
            tool_verbs = self.TOOL_VERBS.get(context.tool_name.lower(), self.SAFE_VERBS)
            allowed_verbs = tool_verbs + self.SAFE_VERBS
        else:
            # No tool or tool not available - use only safe verbs
            allowed_verbs = self.SAFE_VERBS
        
        allowed_verbs_str = ", ".join(f'"{v}"' for v in allowed_verbs[:5])
        
        prompt = f"""You are Aura, a helpful AI assistant. The user asked: "{context.query}"

You need to generate a VERY SHORT acknowledgment (max 10 words) while the system processes their request.

STRICT RULES:
1. ONLY use these phrases: {allowed_verbs_str}
2. DO NOT answer the question
3. DO NOT promise any specific outcome
4. DO NOT end with a period - leave it open for continuation
5. Keep it conversational and natural
{"6. The user seems " + context.sentiment.value + " - be appropriately empathetic" if context.sentiment != Sentiment.NEUTRAL else ""}

{tone}Generate a brief acknowledgment:"""
        
        return prompt
    
    def _build_quick_acknowledgment(self, context: StallerContext) -> str:
        """
        Build a quick, template-based acknowledgment.
        
        Used as a fallback or for instant first token.
        """
        tone = self.SENTIMENT_TONES.get(context.sentiment, "")
        
        if context.tool_name and context.tool_available:
            tool_verbs = self.TOOL_VERBS.get(context.tool_name.lower())
            if tool_verbs:
                return f"{tone}{tool_verbs[0]}"
        
        category_ack = self.CATEGORY_ACKS.get(context.category, self.CATEGORY_ACKS[Category.GENERAL])
        return f"{tone}{category_ack}"
    
    async def stream_stall(
        self, 
        context: StallerContext,
        use_llm: bool = True
    ) -> AsyncGenerator[StallerChunk, None]:
        """
        Stream stalling text using LLM (model from settings.staller_model).
        
        Uses LLM to generate natural, context-aware acknowledgments.
        No templates - pure LLM generation for natural responses.
        
        Args:
            context: The staller context with query and metadata
            use_llm: If True, use LLM; else fallback to simple acknowledgment
            
        Yields:
            StallerChunk objects with content and metadata
        """
        if not use_llm or not self._llm_service:
            # Minimal fallback
            yield StallerChunk(content="Just a moment...", is_final=True, is_buffer=True)
            return
        
        # Build a prompt for the LLM to generate a natural acknowledgment
        tool_context = ""
        if context.tool_name and context.tool_available:
            tool_context = f"The user's request involves {context.tool_name}."
        
        prompt = f"""Generate a brief, natural acknowledgment (10-15 words max) for this user request.
User asked: "{context.query[:100]}"
{tool_context}

Rules:
- Be conversational and warm
- Don't answer the question, just acknowledge you're working on it
- Don't end with a period - leave it open
- Examples: "Let me check that for you", "Pulling up your schedule now", "Working on it"

Acknowledgment:"""

        system_prompt = "You are a helpful assistant. Generate ONLY the acknowledgment text, nothing else. Be brief and natural."
        
        try:
            first_chunk = True
            async for chunk in self._llm_service.stream_openai(
                prompt,
                system_prompt=system_prompt
                # Model comes from settings.staller_model via llm_service
            ):
                if chunk.strip():
                    yield StallerChunk(
                        content=chunk,
                        is_final=False,
                        is_buffer=False
                    )
                    first_chunk = False
            
            # End with ellipsis
            yield StallerChunk(content=" ...", is_final=True, is_buffer=True)
            
        except Exception as e:
            logger.warning(f"Staller LLM error: {e}")
            # Minimal fallback on error
            yield StallerChunk(content="Working on it ...", is_final=True, is_buffer=True)
    
    async def generate_timeout_message(self, context: StallerContext) -> str:
        """
        Generate a conversational message for when the agent times out.
        
        This is used when we need to hand off to async processing.
        Makes the timeout feel natural and keeps the conversation flowing.
        """
        import random
        
        tool_mention = ""
        if context.tool_name and context.tool_available:
            tool_mention = context.tool_name
        
        # Conversational timeout messages - secretarial style
        messages = [
            f"This is taking a bit longer than expected. I'll keep working on it and ping you when it's ready! Is there anything else you need in the meantime?",
            f"Hmm, let me dig deeper into this. I'll get back to you with the results shortly - feel free to ask me anything else while you wait!",
            f"This one needs a bit more time. I'll finish it in the background and notify you. What else can I help with?",
            f"Alright, I'm on it! This might take a moment so I'll continue in the background. Let me know if there's anything else you need!",
        ]
        
        if tool_mention:
            messages = [
                f"Checking your {tool_mention} is taking a bit longer. I'll keep working and notify you when done! Anything else I can help with?",
                f"Your {tool_mention} request needs a bit more time. I'll handle it in the background - is there something else you'd like me to do?",
                f"Still working on the {tool_mention} stuff. I'll ping you when it's ready! Meanwhile, I'm all ears if you need anything else.",
            ]
        
        return random.choice(messages)
    
    def get_stitch_hint(self, last_tokens: List[str]) -> str:
        """
        Provide a hint for the stitcher based on the last tokens.
        
        Analyzes the grammatical structure to suggest the best
        conjunction for a smooth stitch.
        """
        if not last_tokens:
            return " "
        
        last_text = " ".join(last_tokens).strip()
        
        # If ends with ellipsis, suggest direct continuation
        if last_text.endswith("..."):
            return " "
        
        # If ends with a verb form, suggest conjunction
        verb_endings = ["ing", "to", "for"]
        for ending in verb_endings:
            if last_text.endswith(ending):
                return " and "
        
        # Default: add a comma-conjunction
        return ", "


# Singleton instance
staller_service = StallerService()
