"""
Router Service - Context-Aware Intent Classification
=====================================================

Implements the Aura Routing Algorithm's Smart Classification.
Uses regex pattern matching + tool registry check for routing decisions.

Decision Matrix:
- Condition A: Simple Query (No Tool Needed) → FAST_SOLVER
- Condition B: Tool Intent + Tool MISSING → FAST_ERROR
- Condition C: Tool Intent + Tool AVAILABLE → SECRETARY_PROTOCOL
- Condition D: Complex Reasoning → SECRETARY_PROTOCOL
"""

import re
import logging
from typing import Literal, Optional, Dict
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)


# Classification results
ClassificationResult = Literal["FAST_SOLVER", "FAST_ERROR", "SECRETARY_PROTOCOL"]


class Sentiment(Enum):
    """Query sentiment for context injection."""
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"
    URGENT = "urgent"


class Category(Enum):
    """Query category for context-aware responses."""
    EMOTIONAL = "emotional"
    TECHNICAL = "technical"
    CALENDAR = "calendar"
    EMAIL = "email"
    SEARCH = "search"
    TASK = "task"
    GENERAL = "general"


@dataclass
class ClassificationContext:
    """
    Full classification context for the routing decision.
    
    Contains all information needed by downstream services
    (Staller, Agent, Orchestrator) to make informed decisions.
    """
    route: ClassificationResult
    tool_needed: Optional[str] = None
    tool_available: bool = False
    sentiment: Sentiment = Sentiment.NEUTRAL
    category: Category = Category.GENERAL
    confidence: float = 0.0


class RouterService:
    """
    Context-Aware Intent Classification Service.
    
    Implements the Aura Routing Algorithm's 4-condition decision matrix:
    
    1. FAST_SOLVER: Simple queries, no tool needed
    2. FAST_ERROR: Tool intent but tool is not connected
    3. SECRETARY_PROTOCOL: Tool available OR complex reasoning required
    
    Latency Budget: < 50ms for classification
    """
    
    def __init__(self):
        self._initialized = False
        
        # =====================================================================
        # Tool Intent Patterns
        # Map tools to their trigger patterns
        # =====================================================================
        self.tool_patterns = {
            "calendar": [
                r"\b(book|schedule|create|add|set)\b.*\b(meeting|appointment|event|call)\b",
                r"\b(check|show|get|what's on|what is on|tell me)\b.*\b(calendar|schedule|events|appointments)\b",
                r"\b(my calendar|my schedule|my events|my appointments)\b",
                r"\b(agenda|my day|today's|tomorrow's|this week|next week)\b",
                r"\b(when|do i have|am i free|am i busy|available)\b.*\b(meeting|event|appointment|schedule)\b",
                r"\b(next meeting|next event|upcoming|scheduled|on my calendar)\b",
                r"\b(reschedule|move|push|cancel|delete)\b.*\b(meeting|event|appointment)\b",
                r"\b(block|focus time|deep work)\b",
                r"\b(brief me|summarize|summary|overview)\b.*\b(day|schedule|calendar)\b",
                r"\b(tomorrow|today)\b.*\b(schedule|calendar|events|meetings|appointments)\b",
                r"\bcalendar\b",  # Simple mention of calendar
            ],
            "email": [
                r"\b(send|compose|write|draft|reply)\b.*\b(email|message|mail)\b",
                r"\b(check|show|read)\b.*\b(inbox|emails?|mail)\b",
            ],
            "jira": [
                r"\b(create|add|open|update)\b.*\b(ticket|issue|jira|task)\b",
                r"\b(check|show|get|status)\b.*\b(jira|sprint|board|backlog)\b",
            ],
            "github": [
                r"\b(github|repo|repository|commit|pr|pull request|issue|branch)\b",
                r"\b(create|merge|push|clone)\b.*\b(pr|pull request|branch)\b",
            ],
            "search": [
                r"\b(search|find|look up|google|lookup|what is|who is|where is)\b",
                r"\b(news|stock|price|exchange rate|weather|forecast)\b",
            ],
            "spotify": [
                r"\b(play|pause|skip|next|previous)\b.*\b(song|music|track|playlist)\b",
                r"\b(spotify|music|playing|currently playing)\b",
            ],
            "slack": [
                r"\b(send|post|message)\b.*\b(slack|channel|dm)\b",
                r"\b(check|show)\b.*\b(slack|messages|notifications)\b",
            ],
        }
        
        # =====================================================================
        # Simple Query Patterns (No Tool Needed)
        # =====================================================================
        self.simple_patterns = [
            r"^(hi|hello|hey|greetings|good morning|good afternoon|good evening)\b",
            r"^(thanks|thank you|thx|ty)\b",
            r"^(bye|goodbye|see you|later)\b",
            r"\b(how are you|what's up|how's it going)\b",
            r"\b(tell me a joke|make me laugh|something funny)\b",
            r"\b(who are you|what are you|what can you do)\b",
            r"^(yes|no|ok|okay|sure|alright|fine)\b",
            r"\b(what is|what are|explain|describe|define)\b(?!.*\b(calendar|schedule|meeting|email))",
            # Simple factual questions
            r"^(what|who|when|where|why|how)\b.{0,30}$",
        ]
        
        # =====================================================================
        # Complex Reasoning Patterns (Secretary Protocol, no specific tool)
        # =====================================================================
        self.complex_patterns = [
            r"\b(analyze|debug|review|optimize|refactor)\b.*\b(code|script|function|program)\b",
            r"\b(compare|contrast|evaluate|assess)\b",
            r"\b(plan|strategy|approach|design)\b",
            r"\b(multi-step|step by step|break down)\b",
            r"\b(help me think|reason through|figure out)\b",
        ]
        
        # =====================================================================
        # Sentiment Patterns
        # =====================================================================
        self.sentiment_patterns = {
            Sentiment.NEGATIVE: [
                r"\b(sad|upset|angry|frustrated|annoyed|hate|terrible|awful|worst)\b",
                r"\b(can't|won't|don't|failed|broken|error|mistake)\b",
                r"[!?]{2,}",  # Excessive punctuation
            ],
            Sentiment.POSITIVE: [
                r"\b(happy|excited|great|awesome|wonderful|love|best|amazing)\b",
                r"\b(thank|thanks|appreciate|grateful)\b",
            ],
            Sentiment.URGENT: [
                r"\b(urgent|asap|immediately|now|quick|hurry|emergency)\b",
                r"[!]{2,}",  # Multiple exclamation marks
            ],
        }
        
        # =====================================================================
        # Category Patterns
        # =====================================================================
        self.category_patterns = {
            Category.EMOTIONAL: [r"\b(feel|feeling|sad|happy|upset|excited|worried|anxious)\b"],
            Category.TECHNICAL: [r"\b(code|debug|error|function|api|database|server|bug)\b"],
            Category.CALENDAR: [r"\b(calendar|schedule|meeting|event|appointment|agenda)\b"],
            Category.EMAIL: [r"\b(email|inbox|mail|message|reply|forward)\b"],
            Category.SEARCH: [r"\b(search|find|look up|google|news|weather)\b"],
            Category.TASK: [r"\b(todo|task|reminder|jira|ticket|issue)\b"],
        }
        
        self._llm_service = None
    
    def initialize(self, llm_service=None):
        """Initialize the router service with LLM for intent classification."""
        logger.info("🧠 [Router] Context-Aware Router initializing...")
        self._llm_service = llm_service
        self._initialized = True
        logger.info("🧠 [Router] Router Service ready (LLM-enhanced classification)")
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized
    
    def _detect_sentiment(self, text: str) -> Sentiment:
        """Detect query sentiment for context injection."""
        text_lower = text.lower()
        
        for sentiment, patterns in self.sentiment_patterns.items():
            for pattern in patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return sentiment
        
        return Sentiment.NEUTRAL
    
    def _detect_category(self, text: str) -> Category:
        """Detect query category for context-aware responses."""
        text_lower = text.lower()
        
        for category, patterns in self.category_patterns.items():
            for pattern in patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return category
        
        return Category.GENERAL
    
    def _detect_tool_intent(self, text: str) -> Optional[str]:
        """
        Detect if the query intends to use a specific tool.
        
        Returns the tool name if detected, None otherwise.
        """
        text_lower = text.lower()
        
        for tool_name, patterns in self.tool_patterns.items():
            for pattern in patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return tool_name
        
        return None
    
    def _is_simple_query(self, text: str) -> bool:
        """Check if this is a simple query that doesn't need tools."""
        text_lower = text.lower().strip()
        
        for pattern in self.simple_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return True
        
        # Short messages are often simple
        if len(text.split()) <= 4:
            return True
        
        return False
    
    def _is_complex_reasoning(self, text: str) -> bool:
        """Check if this requires complex reasoning (Secretary Protocol)."""
        text_lower = text.lower()
        
        for pattern in self.complex_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return True
        
        # Long, detailed queries often need more thought
        if len(text.split()) > 30:
            return True
        
        return False
    
    async def _classify_with_llm(
        self, 
        text: str, 
        tools_context: str,
        available_tools: list
    ) -> Optional[str]:
        """
        Use LLM to detect which tool (if any) the user's query needs.
        
        Args:
            text: User's query
            tools_context: String description of available tools
            available_tools: List of available tool names
            
        Returns:
            Tool name if detected, None otherwise
        """
        if not self._llm_service or not self._llm_service.openai_client:
            return None
        
        if not available_tools:
            return None
        
        # Build a fast classification prompt
        tools_list = ", ".join(available_tools)
        
        prompt = f"""Classify if the user's query needs a specific tool.

Available tools: {tools_context}

User query: "{text}"

If the query needs one of these tools, respond with ONLY the tool name.
If no tool is needed (simple chat/question), respond with "none".

Answer:"""

        try:
            from config import settings
            
            # Use non-streaming for fast single response
            response = await self._llm_service.openai_client.chat.completions.create(
                model=settings.staller_model,  # Use fast model
                messages=[
                    {"role": "system", "content": "You classify user intents. Respond with ONLY a single tool name or 'none'. Nothing else."},
                    {"role": "user", "content": prompt}
                ],
                max_completion_tokens=20,  # Use max_completion_tokens for gpt-4.1+ models
                temperature=0
            )
            
            result = response.choices[0].message.content.strip().lower()
            
            # Validate the result
            if result in available_tools:
                logger.info(f"🤖 [Router] LLM detected tool intent: {result}")
                return result
            elif result == "none" or result not in available_tools:
                return None
            
        except Exception as e:
            logger.warning(f"LLM classification failed: {e}")
            return None
        
        return None
    
    async def classify(self, text: str) -> ClassificationResult:
        """
        Legacy classification method for backward compatibility.
        
        Maps to the new classification context but returns simple result.
        """
        context = await self.classify_with_context(text, {})
        
        # Map new routes to legacy routes
        if context.route == "FAST_SOLVER" or context.route == "FAST_ERROR":
            return "FAST_SOLVER"  # Both handled by fast path
        else:
            return "SECRETARY_PROTOCOL"
    
    async def classify_with_context(
        self, 
        text: str, 
        tool_registry: Dict[str, bool],
        tools_context: str = ""
    ) -> ClassificationContext:
        """
        Full context-aware classification with LLM-enhanced tool detection.
        
        Implements the 4-condition decision matrix:
        
        Args:
            text: User's input query
            tool_registry: Dict of {tool_name: is_available}
            tools_context: String description of available tools for LLM
            
        Returns:
            ClassificationContext with full routing information
        """
        text_lower = text.lower().strip()
        
        # Detect sentiment and category for context injection
        sentiment = self._detect_sentiment(text)
        category = self._detect_category(text)
        
        # =====================================================================
        # Condition A: Simple Query (No Tool Needed) → FAST_SOLVER
        # =====================================================================
        if self._is_simple_query(text):
            logger.info(f"📍 [Router] FAST_SOLVER (simple query)")
            return ClassificationContext(
                route="FAST_SOLVER",
                sentiment=sentiment,
                category=category,
                confidence=0.9
            )
        
        # =====================================================================
        # Check for tool intent - Use LLM first, then fall back to regex
        # =====================================================================
        available_tools = list(tool_registry.keys())
        
        # Try LLM-based classification for accurate intent detection
        tool_needed = await self._classify_with_llm(text, tools_context, available_tools)
        
        # Fall back to regex if LLM didn't detect or failed
        if not tool_needed:
            tool_needed = self._detect_tool_intent(text)
        
        if tool_needed:
            tool_available = tool_registry.get(tool_needed, False)
            
            # =================================================================
            # Condition B: Tool Intent + Tool MISSING → FAST_ERROR
            # =================================================================
            if not tool_available:
                logger.info(f"📍 [Router] FAST_ERROR (tool '{tool_needed}' not connected)")
                return ClassificationContext(
                    route="FAST_ERROR",
                    tool_needed=tool_needed,
                    tool_available=False,
                    sentiment=sentiment,
                    category=category,
                    confidence=0.95
                )
            
            # =================================================================
            # Condition C: Tool Intent + Tool AVAILABLE → SECRETARY_PROTOCOL
            # =================================================================
            logger.info(f"📍 [Router] SECRETARY_PROTOCOL (tool '{tool_needed}' available)")
            return ClassificationContext(
                route="SECRETARY_PROTOCOL",
                tool_needed=tool_needed,
                tool_available=True,
                sentiment=sentiment,
                category=category,
                confidence=0.95
            )
        
        # =====================================================================
        # Condition D: Complex Reasoning → SECRETARY_PROTOCOL
        # =====================================================================
        if self._is_complex_reasoning(text):
            logger.info(f"📍 [Router] SECRETARY_PROTOCOL (complex reasoning)")
            return ClassificationContext(
                route="SECRETARY_PROTOCOL",
                sentiment=sentiment,
                category=category,
                confidence=0.8
            )
        
        # =====================================================================
        # Default: Short/medium queries without tool intent → FAST_SOLVER
        # =====================================================================
        word_count = len(text.split())
        if word_count <= 15:
            logger.info(f"📍 [Router] FAST_SOLVER (default for medium query)")
            return ClassificationContext(
                route="FAST_SOLVER",
                sentiment=sentiment,
                category=category,
                confidence=0.7
            )
        
        # Longer queries default to Secretary Protocol
        logger.info(f"📍 [Router] SECRETARY_PROTOCOL (default for longer query)")
        return ClassificationContext(
            route="SECRETARY_PROTOCOL",
            sentiment=sentiment,
            category=category,
            confidence=0.6
        )


# Singleton instance
router_service = RouterService()
