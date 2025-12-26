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
    MEMORY = "memory"  # Memory recall/past conversation intent
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
            # Memory/Recall patterns - triggers deep archive search
            "memory": [
                r"\b(remember|recall|mentioned|told you|said before)\b",
                r"\b(i told you|we discussed|we talked about)\b",
                r"\b(previously|earlier|last time|before|back when)\b.*\b(said|told|mentioned|discussed)\b",
                r"\b(what was|what did i|what have i|did i mention)\b",
                r"\b(my|our)\b.*\b(history|past|conversations?)\b",
                r"\b(you know|you already know|as you know)\b",
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
            Category.MEMORY: [r"\b(remember|recall|told you|said before|mentioned|previously|history)\b"],
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
    ) -> str:
        """
        Use LLM to decide the best route: FAST, SMART, or TOOL.
        
        Args:
            text: User's query
            tools_context: String description of available tools
            available_tools: List of available tool names
            
        Returns:
            "FAST", "SMART", or "TOOL:[name]"
        """
        if not self._llm_service or not self._llm_service.openai_client:
            return "SMART" # Default to smart fallsafe
        
        # Build prompt
        prompt = f"""Classify the user query into one of three categories:

1. FAST: Simple questions, greetings, facts, jokes, or short chit-chat. (e.g. "hi", "what is python", "tell me a joke", "i like coffee")
2. SMART: Complex reasoning, planning, analysis, coding, creative writing, or multi-step tasks. (e.g. "plan my week", "debug this code", "write a story")
3. TOOL: Requires a specific tool from this list: [{tools_context}]

User query: "{text}"

Respond with ONLY: "FAST", "SMART", or "TOOL:[tool_name]"
"""

        try:
            from config import settings
            
            # Use non-streaming for fast single response
            response = await self._llm_service.openai_client.chat.completions.create(
                model=settings.staller_model,  # Use fast model (e.g. gpt-4o-mini/nano)
                messages=[
                    {"role": "system", "content": "You are a precise router. Output ONLY the category code."},
                    {"role": "user", "content": prompt}
                ],
                max_completion_tokens=20,
                temperature=0
            )
            
            result = response.choices[0].message.content.strip()
            logger.info(f"🤖 [Router] LLM Decision: {result}")
            return result
            
        except Exception as e:
            logger.warning(f"LLM classification failed: {e}")
            return "SMART" # Fail safe to smart path

    async def classify_with_context(
        self, 
        text: str, 
        tool_registry: Dict[str, bool],
        tools_context: str = ""
    ) -> ClassificationContext:
        """
        Full context-aware classification with LLM-driven routing.
        """
        text_lower = text.lower().strip()
        
        # Detect context
        sentiment = self._detect_sentiment(text)
        category = self._detect_category(text)
        
        # Pre-check: Ultra-simple patterns (0ms latency optimization)
        # We keep this ONLY for "hi/hello" type instant interactions
        if self._is_simple_query(text) and len(text.split()) <= 2:
             logger.info(f"📍 [Router] FAST_SOLVER (heuristic pre-check)")
             return ClassificationContext("FAST_SOLVER", sentiment=sentiment, category=category, confidence=0.99)

        # Main Path: LLM Decision
        available_tools = list(tool_registry.keys())
        decision = await self._classify_with_llm(text, tools_context, available_tools)
        
        # Parse Decision
        decision_upper = decision.upper().strip()
        
        # Robust parsing (handle "Category: FAST" or "FAST.")
        is_fast = "FAST" in decision_upper and "SMART" not in decision_upper
        is_smart = "SMART" in decision_upper
        is_tool = "TOOL" in decision_upper
        
        if is_fast:
            logger.info(f"📍 [Router] FAST_SOLVER (LLM decision)")
            return ClassificationContext("FAST_SOLVER", sentiment=sentiment, category=category, confidence=0.9)
            
        elif is_tool:
            # Extract tool name more robustly
            try:
                # Look for TOOL:name or just name if it's in the string
                tool_part = decision.split("TOOL:")[-1].strip().lower()
                # Remove punctuation
                tool_name = re.sub(r'[^\w\s]', '', tool_part).strip()
            except:
                tool_name = "unknown"

            # Verify availability
            if tool_registry.get(tool_name, False):
                logger.info(f"📍 [Router] SECRETARY_PROTOCOL (Tool: {tool_name})")
                return ClassificationContext("SECRETARY_PROTOCOL", tool_needed=tool_name, tool_available=True, sentiment=sentiment, category=category, confidence=0.95)
            else:
                logger.info(f"📍 [Router] FAST_ERROR (Tool {tool_name} unavailable)")
                return ClassificationContext("FAST_ERROR", tool_needed=tool_name, tool_available=False, sentiment=sentiment, category=category, confidence=0.95)
        
        # Fallback to SMART if explicitly chosen
        elif is_smart:
            logger.info(f"📍 [Router] SECRETARY_PROTOCOL (Smart/Reasoning)")
            return ClassificationContext("SECRETARY_PROTOCOL", sentiment=sentiment, category=category, confidence=0.9)
            
        # If LLM returned garbage/failed to decide, fall back to Heuristics
        else:
            logger.warning(f"⚠️ [Router] LLM returned ambiguous '{decision}'. Falling back to heuristics.")
            if self._is_simple_query(text):
                return ClassificationContext("FAST_SOLVER", sentiment=sentiment, category=category, confidence=0.5)
            else:
                return ClassificationContext("SECRETARY_PROTOCOL", sentiment=sentiment, category=category, confidence=0.5)


# Singleton instance
router_service = RouterService()
