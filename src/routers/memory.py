"""
Memory Router - Super Memory 3.0 API
=====================================

API endpoints for the Psychodynamic Memory System.
Provides access to user profiles, archive search, and memory management.
"""

import logging
from typing import Optional, List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.memory_service import memory_service

logger = logging.getLogger(__name__)

router = APIRouter()


# -----------------------------------------------------------------------------
# Request/Response Models
# -----------------------------------------------------------------------------

class ArchiveSearchRequest(BaseModel):
    """Request for semantic archive search."""
    query: str
    user_id: str
    max_results: int = 5
    layer_tag: Optional[str] = None


class ArchiveMemoryResponse(BaseModel):
    """Single archive memory result."""
    content: str
    similarity: float
    category: str
    archived_at: Optional[str] = None


class ArchiveSearchResponse(BaseModel):
    """Response from archive search."""
    success: bool
    found: bool
    message: str
    memories: List[ArchiveMemoryResponse]


class ProfileSectionResponse(BaseModel):
    """A section of the user profile."""
    identity: List[str] = []
    core_beliefs: List[str] = []
    behavioral_patterns: List[str] = []
    preferences: List[str] = []
    active_projects: List[str] = []
    emotional_baseline: str = "neutral"


class ProfileResponse(BaseModel):
    """Full user profile response."""
    user_id: str
    tier_1_summary: str
    long_term_profile: ProfileSectionResponse
    profile_version: int
    word_count: int
    total_interactions: int
    last_updated: Optional[str] = None


class MemoryStatusResponse(BaseModel):
    """Memory service status."""
    initialized: bool
    profile_exists: bool
    archive_count: int


# -----------------------------------------------------------------------------
# Profile Endpoints
# -----------------------------------------------------------------------------

@router.get("/profile/{user_id}", response_model=ProfileResponse)
async def get_user_profile(user_id: str):
    """
    Get the full user profile (Tier 2 - Warm Memory).
    
    Returns the user's psychological profile including:
    - Identity facts
    - Core beliefs
    - Behavioral patterns
    - Preferences
    - Active projects
    - Tier 1 summary (LLM cheat sheet)
    """
    if not memory_service.is_initialized:
        raise HTTPException(
            status_code=503,
            detail="Memory service not initialized. Database pool may not be connected."
        )
    
    profile = await memory_service.get_full_profile(user_id)
    
    if not profile:
        raise HTTPException(
            status_code=404,
            detail=f"No profile found for user: {user_id}"
        )
    
    # Convert to response format
    ltp = profile.long_term_profile
    return ProfileResponse(
        user_id=profile.user_id,
        tier_1_summary=profile.tier_1_summary,
        long_term_profile=ProfileSectionResponse(
            identity=ltp.identity,
            core_beliefs=ltp.core_beliefs,
            behavioral_patterns=ltp.behavioral_patterns,
            preferences=ltp.preferences,
            active_projects=ltp.active_projects,
            emotional_baseline=ltp.emotional_baseline
        ),
        profile_version=profile.profile_version,
        word_count=profile.word_count,
        total_interactions=profile.total_interactions,
        last_updated=profile.last_updated.isoformat() if profile.last_updated else None
    )


@router.get("/summary/{user_id}")
async def get_tier1_summary(user_id: str):
    """
    Get only the Tier 1 summary (fast path).
    
    This is the 500-word "cheat sheet" injected into LLM prompts.
    Optimized for minimal latency.
    """
    if not memory_service.is_initialized:
        raise HTTPException(status_code=503, detail="Memory service not initialized")
    
    summary = await memory_service.get_user_context(user_id)
    return {
        "user_id": user_id,
        "summary": summary,
        "word_count": len(summary.split()) if summary else 0
    }


@router.post("/profile/{user_id}/create")
async def create_user_profile(user_id: str):
    """
    Create a new user profile if one doesn't exist.
    """
    if not memory_service.is_initialized:
        raise HTTPException(status_code=503, detail="Memory service not initialized")
    
    profile = await memory_service.ensure_profile_exists(user_id)
    return {
        "success": True,
        "user_id": user_id,
        "profile_version": profile.profile_version if profile else 1
    }


@router.delete("/profile/{user_id}/reset")
async def reset_user_profile(user_id: str):
    """
    Hard reset: Delete all memory profile and archives for a user.
    """
    if not memory_service.is_initialized:
        raise HTTPException(status_code=503, detail="Memory service not initialized")
    
    success = await memory_service.reset_user_memory(user_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to reset memory")
        
    return {
        "success": True,
        "message": f"All memory data deleted for user {user_id}"
    }


# -----------------------------------------------------------------------------
# Archive Search Endpoints
# -----------------------------------------------------------------------------

@router.post("/search", response_model=ArchiveSearchResponse)
async def search_archive(request: ArchiveSearchRequest):
    """
    Semantic search in the Cold Archive (Tier 3).
    
    Uses pgvector to find memories similar to the query.
    Returns memories with similarity scores.
    """
    if not memory_service.is_initialized:
        raise HTTPException(status_code=503, detail="Memory service not initialized")
    
    results = await memory_service.deep_recall(
        query=request.query,
        user_id=request.user_id,
        restore_to_profile=False  # Don't auto-restore from API call
    )
    
    if not results:
        return ArchiveSearchResponse(
            success=True,
            found=False,
            message="No matching memories found in the archive.",
            memories=[]
        )
    
    memories = [
        ArchiveMemoryResponse(
            content=r.content,
            similarity=r.similarity,
            category=r.layer_tag,
            archived_at=r.archived_at.isoformat() if r.archived_at else None
        )
        for r in results
    ]
    
    return ArchiveSearchResponse(
        success=True,
        found=True,
        message=f"Found {len(memories)} relevant memories.",
        memories=memories
    )


@router.get("/archive/{user_id}")
async def list_archive_memories(
    user_id: str,
    limit: int = 50,
    offset: int = 0
):
    """
    List archived memories for a user (paginated).
    """
    if not memory_service.is_initialized:
        raise HTTPException(status_code=503, detail="Memory service not initialized")
    
    memories = await memory_service.repository.get_archive_memories_by_user(
        user_id=user_id,
        limit=limit,
        offset=offset
    )
    
    return {
        "user_id": user_id,
        "count": len(memories),
        "offset": offset,
        "memories": memories
    }


# -----------------------------------------------------------------------------
# Status Endpoint
# -----------------------------------------------------------------------------

@router.get("/status")
async def get_memory_status():
    """
    Get the status of the memory service.
    """
    return {
        "initialized": memory_service.is_initialized,
        "repository_initialized": memory_service.repository.is_initialized if memory_service.repository else False,
        "max_profile_words": memory_service.MAX_PROFILE_WORDS,
        "archive_threshold": memory_service.ARCHIVE_SIMILARITY_THRESHOLD
    }
