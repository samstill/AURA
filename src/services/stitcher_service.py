"""
Stitcher Service - Seamless Response Merging
=============================================

Merges Staller and Agent outputs into a grammatically correct,
seamless response stream.

Part of the Aura Routing Algorithm - Phase C (The Stitcher).

Key Features:
- Buffer Window: Holds last 3 tokens of staller for potential modification
- Grammar Analysis: Ensures smooth conjunction
- Case Normalization: Lowercases agent's first letter if mid-sentence
"""

import logging
import re
from typing import List, Tuple, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class StitchResult:
    """Result of stitching staller and agent outputs."""
    text: str
    stitch_type: str  # "direct", "conjunction", "replacement"
    quality: float  # 0.0 to 1.0, how confident we are in the stitch


class StitcherService:
    """
    Merges staller output with agent output seamlessly.
    
    The stitcher ensures that the transition from the staller
    (acknowledgment) to the agent (actual response) is grammatically
    smooth and natural-sounding.
    
    Stitch Types:
    1. Direct: Agent output follows staller naturally
    2. Conjunction: Insert connecting word (and, which, etc.)
    3. Replacement: Replace staller's last tokens with transition
    """
    
    # Conjunctions for stitching
    CONJUNCTIONS = [" and ", ", and ", " — ", ": "]
    
    # Patterns that indicate a complete sentence start
    SENTENCE_STARTERS = [
        r"^(I|You|The|This|That|Here|There|It|We|They)",
        r"^(Yes|No|Sure|Okay|Alright)",
        r"^(Done|Completed|Success|Error|Failed)",
    ]
    
    # Patterns that indicate continuation is natural
    CONTINUATION_PATTERNS = [
        r"\.\.\.$",  # Ellipsis
        r"ing\s*$",  # Gerund
        r"to\s*$",   # Infinitive
        r"and\s*$",  # Already has conjunction
    ]
    
    def __init__(self):
        self._sentence_patterns = [re.compile(p, re.IGNORECASE) for p in self.SENTENCE_STARTERS]
        self._continuation_patterns = [re.compile(p) for p in self.CONTINUATION_PATTERNS]
    
    def _is_sentence_start(self, text: str) -> bool:
        """Check if text looks like the start of a new sentence."""
        text = text.strip()
        for pattern in self._sentence_patterns:
            if pattern.match(text):
                return True
        return False
    
    def _allows_continuation(self, text: str) -> bool:
        """Check if the staller text naturally allows continuation."""
        for pattern in self._continuation_patterns:
            if pattern.search(text):
                return True
        return False
    
    def _analyze_staller_suffix(self, staller_text: str) -> Tuple[str, bool]:
        """
        Analyze the staller's ending for stitching.
        
        Returns:
            Tuple of (cleaned_suffix, needs_conjunction)
        """
        text = staller_text.rstrip()
        
        # Remove trailing ellipsis for analysis
        if text.endswith("..."):
            return text[:-3].rstrip(), False  # Direct continuation
        
        if text.endswith("."):
            return text, True  # Needs transition
        
        return text, True  # Default: needs conjunction
    
    def _normalize_agent_start(self, agent_text: str, mid_sentence: bool) -> str:
        """
        Normalize the agent's first character for stitching.
        
        If we're mid-sentence, lowercase the first letter.
        """
        if not agent_text:
            return agent_text
        
        agent_text = agent_text.lstrip()
        
        if mid_sentence and agent_text[0].isupper():
            # Check it's not an acronym or proper noun we should keep
            words = agent_text.split()
            if words and len(words[0]) > 1:
                # Lowercase first letter
                return agent_text[0].lower() + agent_text[1:]
        
        return agent_text
    
    def _select_conjunction(self, staller_text: str, agent_text: str) -> str:
        """
        Select the best conjunction for stitching.
        
        Analyzes both texts to determine the most natural connector.
        """
        agent_lower = agent_text.lower().strip()
        
        # If agent starts with common result words, use colon
        result_starters = ["here", "done", "success", "found", "your"]
        for starter in result_starters:
            if agent_lower.startswith(starter):
                return " — "
        
        # If staller ends with an action verb, use "and"
        action_endings = ["accessing", "checking", "reviewing", "looking"]
        staller_lower = staller_text.lower()
        for ending in action_endings:
            if staller_lower.endswith(ending):
                return " and "
        
        # Default conjunction
        return ", and "
    
    def stitch(
        self, 
        staller_text: str, 
        agent_text: str,
        staller_buffer: Optional[List[str]] = None
    ) -> StitchResult:
        """
        Stitch staller and agent outputs together.
        
        Args:
            staller_text: The full staller output (including buffer)
            agent_text: The agent's response
            staller_buffer: Optional list of the last buffer tokens
            
        Returns:
            StitchResult with merged text and metadata
        """
        if not staller_text or not agent_text:
            # No stitch needed
            return StitchResult(
                text=agent_text or staller_text or "",
                stitch_type="direct",
                quality=1.0
            )
        
        staller_text = staller_text.rstrip()
        agent_text = agent_text.strip()
        
        # Analyze staller ending
        cleaned_suffix, needs_conjunction = self._analyze_staller_suffix(staller_text)
        
        # Check if agent starts a new sentence
        if self._is_sentence_start(agent_text):
            # Agent wants to start fresh - respect that
            if staller_text.endswith("..."):
                # Remove ellipsis, add period, start new sentence
                text = staller_text[:-3].rstrip() + ". " + agent_text
            else:
                text = staller_text + " " + agent_text
                
            return StitchResult(
                text=text,
                stitch_type="direct",
                quality=0.9
            )
        
        # Check if direct continuation works
        if self._allows_continuation(staller_text):
            # Staller naturally leads into continuation
            mid_sentence = not staller_text.endswith(".")
            normalized_agent = self._normalize_agent_start(agent_text, mid_sentence)
            
            # Remove ellipsis if present
            if staller_text.endswith("..."):
                text = staller_text[:-3].rstrip() + " " + normalized_agent
            else:
                text = staller_text + " " + normalized_agent
                
            return StitchResult(
                text=text,
                stitch_type="direct",
                quality=0.95
            )
        
        # Need conjunction
        conjunction = self._select_conjunction(staller_text, agent_text)
        normalized_agent = self._normalize_agent_start(agent_text, mid_sentence=True)
        
        # Handle ellipsis
        if staller_text.endswith("..."):
            text = staller_text[:-3].rstrip() + conjunction + normalized_agent
        else:
            text = staller_text + conjunction + normalized_agent
        
        return StitchResult(
            text=text,
            stitch_type="conjunction",
            quality=0.85
        )
    
    def prepare_staller_for_timeout(self, staller_text: str) -> str:
        """
        Prepare the staller text for a timeout scenario.
        
        Cleans up the staller text so it can standalone when
        followed by a timeout message.
        """
        text = staller_text.rstrip()
        
        # Remove trailing ellipsis
        if text.endswith("..."):
            text = text[:-3].rstrip()
        
        # Ensure it ends properly
        if not text.endswith((".", "!", "?")):
            text += "."
        
        return text


# Singleton instance
stitcher_service = StitcherService()
