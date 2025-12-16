"""
Router Service - Intent Classification (Regex-Only)
====================================================

Lightweight intent classification using regex pattern matching.
No ML dependencies = fast builds, low memory usage.

Routes requests to either FAST (reflex) or SMART (agentic) path.
"""

import re
import logging
from typing import Literal

logger = logging.getLogger(__name__)


# Classification results
ClassificationResult = Literal["FAST", "SMART"]


class RouterService:
    """
    Intent classification service for routing requests.
    Uses regex pattern matching for zero-latency classification.
    """
    
    def __init__(self):
        self._initialized = False
        
        # Patterns that indicate agentic/tool-use intent
        self.agentic_patterns = [
            # Action verbs
            r"\b(book|schedule|create|send|remind|set|make|add)\b.*\b(meeting|appointment|event|email|reminder|alarm|task)\b",
            r"\b(search|find|look up|google|lookup)\b",
            r"\b(check|show|get|what's on)\b.*\b(calendar|schedule|events|appointments)\b",
            r"\b(plan|organize|arrange)\b.*\b(trip|travel|meeting|event)\b",
            r"\b(send|compose|write|draft)\b.*\b(email|message|text)\b",
            r"\b(remind me|set a reminder|don't let me forget)\b",
            # Direct tool references
            r"\b(calendar|email|web search|flight|hotel|restaurant)\b",
            # Time-based requests often need tools
            r"\b(tomorrow|next week|this weekend|on monday|at \d+)\b.*\b(schedule|book|plan|meeting)\b",
            # Information retrieval
            r"\b(github|repo|repository|commit|pr|pull request|issue|branch)\b",
            r"\b(time|date|clock|timezone|weather|forecast)\b",
            r"\b(news|stock|price|exchange rate)\b",
        ]
        
        # Patterns that indicate simple chat (reflex)
        self.reflex_patterns = [
            r"^(hi|hello|hey|greetings|good morning|good afternoon|good evening)\b",
            r"^(thanks|thank you|thx|ty)\b",
            r"^(bye|goodbye|see you|later)\b",
            r"\b(how are you|what's up|how's it going)\b",
            r"\b(tell me a joke|make me laugh|something funny)\b",
            r"\b(who are you|what are you|what can you do)\b",
            r"^(yes|no|ok|okay|sure|alright)\b",
        ]
    
    def initialize(self):
        """
        Initialize the router service.
        For regex-only, this is just a sanity check.
        """
        logger.info("🧠 [Cortex] Router Service initializing (regex mode)...")
        self._initialized = True
        logger.info("🧠 [Cortex] Router Service ready.")
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized
    
    async def classify(self, text: str) -> ClassificationResult:
        """
        Classify user intent to determine routing path.
        
        Uses regex pattern matching for instant (0ms) classification.
        
        Args:
            text: User's input text
            
        Returns:
            "FAST" for reflex responses, "SMART" for agentic tasks
        """
        text_lower = text.lower().strip()
        
        # Check for explicit agentic patterns first
        for pattern in self.agentic_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.info(f"📍 [Router] SMART (pattern match)")
                return "SMART"
        
        # Check for simple chat patterns
        for pattern in self.reflex_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.info(f"📍 [Router] FAST (reflex pattern)")
                return "FAST"
        
        # Default: If message is short, likely casual chat
        if len(text.split()) <= 5:
            logger.info(f"📍 [Router] FAST (short message)")
            return "FAST"
        
        # Longer messages might need more thought
        logger.info(f"📍 [Router] SMART (default for longer query)")
        return "SMART"


# Singleton instance
router_service = RouterService()
