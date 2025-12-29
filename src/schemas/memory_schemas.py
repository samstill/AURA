"""
Memory Schemas - Super Memory 3.0
=================================

Pydantic models for the Psychodynamic Memory System.
Enforces the "Freudian" structure for profile analysis and storage.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


# =============================================================================
# Enums
# =============================================================================

class LayerTag(str, Enum):
    """Memory layer classification tags."""
    CONSCIOUS = "conscious"       # Explicit facts stated by user
    RATIONAL = "rational"         # Logic or reasoning used
    SUBCONSCIOUS = "subconscious" # Implied habits or patterns
    UNCONSCIOUS = "unconscious"   # Hidden drivers or fears
    EMOTIONAL = "emotional"       # Emotional states
    FACT = "fact"                 # General facts
    PREFERENCE = "preference"     # Preferences
    PROJECT = "project"           # Projects


class MemoryOperationAction(str, Enum):
    """Actions for surgical memory updates."""
    ADD = "ADD"
    UPDATE = "UPDATE"
    REMOVE = "REMOVE"


class MemoryOperation(BaseModel):
    """
    A single surgical operation to apply to a user profile.
    
    Used for targeted updates instead of full profile regeneration.
    """
    action: MemoryOperationAction
    category: str  # identity, preferences, core_beliefs, behavioral_patterns
    fact: str
    old_fact: Optional[str] = None  # Only for UPDATE action


class EmotionalState(str, Enum):
    """Current emotional baseline."""
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"
    ANXIOUS = "anxious"
    EXCITED = "excited"
    STRESSED = "stressed"
    CALM = "calm"


# =============================================================================
# Freudian Analysis Model (Output of Analysis Agent)
# =============================================================================

class FreudianAnalysis(BaseModel):
    """
    The 5 Freudian Containers - output of the analysis agent.
    
    Extracts multi-layered meaning from user interactions.
    """
    conscious: List[str] = Field(
        default_factory=list,
        description="Explicit facts directly stated by the user"
    )
    rational: List[str] = Field(
        default_factory=list,
        description="Logic, reasoning, or decision-making patterns observed"
    )
    subconscious: List[str] = Field(
        default_factory=list,
        description="Implied habits, routines, or behavioral patterns"
    )
    unconscious: List[str] = Field(
        default_factory=list,
        description="Hidden drivers, fears, or motivations inferred"
    )
    emotional: str = Field(
        default="neutral",
        description="Current emotional vibe or state"
    )
    
    def is_empty(self) -> bool:
        """Check if analysis yielded any insights."""
        return (
            not self.conscious and 
            not self.rational and 
            not self.subconscious and 
            not self.unconscious and
            self.emotional == "neutral"
        )
    
    def to_flat_list(self) -> List[Dict[str, Any]]:
        """Flatten all insights with their layer tags for archiving."""
        items = []
        for fact in self.conscious:
            items.append({"content": fact, "layer_tag": LayerTag.CONSCIOUS})
        for fact in self.rational:
            items.append({"content": fact, "layer_tag": LayerTag.RATIONAL})
        for fact in self.subconscious:
            items.append({"content": fact, "layer_tag": LayerTag.SUBCONSCIOUS})
        for fact in self.unconscious:
            items.append({"content": fact, "layer_tag": LayerTag.UNCONSCIOUS})
        return items


# =============================================================================
# User Profile Model (Tier 2 - Active Memory)
# =============================================================================

class UserProfile(BaseModel):
    """
    The Active Profile Structure (Max ~2000 words).
    
    Represents the current "User Manual" - active beliefs, 
    ongoing projects, and personality traits.
    """
    identity: List[str] = Field(
        default_factory=list,
        description="Identity facts: name, role, demographics"
    )
    core_beliefs: List[str] = Field(
        default_factory=list,
        description="Fundamental beliefs and values"
    )
    behavioral_patterns: List[str] = Field(
        default_factory=list,
        description="Observable habits and behavioral tendencies"
    )
    preferences: List[str] = Field(
        default_factory=list,
        description="Likes, dislikes, and preferences"
    )
    active_projects: List[str] = Field(
        default_factory=list,
        description="Current ongoing projects or goals"
    )
    emotional_baseline: str = Field(
        default="neutral",
        description="Typical emotional state"
    )
    relationship_context: Dict[str, Any] = Field(
        default_factory=dict,
        description="Context about user's relationship with Aura"
    )
    
    def word_count(self) -> int:
        """Estimate total word count of the profile."""
        text = " ".join([
            " ".join(self.identity),
            " ".join(self.core_beliefs),
            " ".join(self.behavioral_patterns),
            " ".join(self.preferences),
            " ".join(self.active_projects),
            self.emotional_baseline,
            str(self.relationship_context)
        ])
        return len(text.split())
    
    def is_over_capacity(self, max_words: int = 2000) -> bool:
        """Check if profile exceeds word limit."""
        return self.word_count() > max_words
    
    def get_summary(self, max_words: int = 500) -> str:
        """
        Generate a concise summary (Tier 1 Cheat Sheet).
        
        Prioritizes identity > active projects > core beliefs.
        """
        parts = []
        
        # Identity first
        if self.identity:
            parts.append(f"User: {'; '.join(self.identity[:3])}")
        
        # Active projects (most relevant for context)
        if self.active_projects:
            parts.append(f"Currently: {'; '.join(self.active_projects[:3])}")
        
        # Core beliefs (shapes responses)
        if self.core_beliefs:
            parts.append(f"Values: {'; '.join(self.core_beliefs[:2])}")
        
        # Key preferences
        if self.preferences:
            parts.append(f"Preferences: {'; '.join(self.preferences[:3])}")
        
        # Emotional baseline
        if self.emotional_baseline != "neutral":
            parts.append(f"Emotional state: {self.emotional_baseline}")
        
        summary = " | ".join(parts)
        
        # Truncate to max words
        words = summary.split()
        if len(words) > max_words:
            summary = " ".join(words[:max_words]) + "..."
        
        return summary


# =============================================================================
# Full Profile Record (Database Row)
# =============================================================================

class UserProfileRecord(BaseModel):
    """Full database record for a user profile."""
    user_id: str
    tier_1_summary: str = ""
    long_term_profile: UserProfile = Field(default_factory=UserProfile)
    profile_version: int = 1
    created_at: Optional[datetime] = None
    last_updated: Optional[datetime] = None
    last_interaction: Optional[datetime] = None
    total_interactions: int = 0
    word_count: int = 0


# =============================================================================
# Archive Memory Model (Tier 3 - Cold Storage)
# =============================================================================

class ArchiveMemory(BaseModel):
    """A single archived memory in cold storage."""
    id: Optional[int] = None
    user_id: str
    content: str
    embedding: Optional[List[float]] = None
    layer_tag: LayerTag = LayerTag.FACT
    source_category: Optional[str] = None
    archived_at: Optional[datetime] = None
    original_created_at: Optional[datetime] = None
    last_accessed: Optional[datetime] = None
    access_count: int = 0


class ArchiveSearchResult(BaseModel):
    """Result from semantic archive search."""
    id: int
    content: str
    similarity: float
    layer_tag: str
    archived_at: Optional[datetime] = None


# =============================================================================
# Profile Update Request
# =============================================================================

class ProfileUpdateRequest(BaseModel):
    """Request to update a user profile with new analysis."""
    user_id: str
    analysis: FreudianAnalysis
    interaction_text: Optional[str] = None
    ai_response: Optional[str] = None


class ProfileMergeResult(BaseModel):
    """Result of merging new analysis into profile."""
    updated_profile: UserProfile
    archived_facts: List[ArchiveMemory] = Field(default_factory=list)
    was_pruned: bool = False
    new_word_count: int = 0
