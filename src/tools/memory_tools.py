"""
Memory Tools - Agent-callable Functions
========================================

Tools for the Aura agent to interact with the memory system.
Used for deep recall and profile queries.
"""

import logging
from typing import Optional, List, Dict, Any

from services.memory_service import memory_service

logger = logging.getLogger(__name__)


async def search_archive_memory(
    query: str,
    user_id: str,
    max_results: int = 5
) -> Dict[str, Any]:
    """
    Search the user's memory archive for relevant past information.
    
    Called by the agent when:
    - User asks about past conversations ("remember when...")
    - User references something previously discussed
    - Current context is missing information that should exist
    
    Args:
        query: What to search for in the archive
        user_id: The user's ID
        max_results: Maximum number of results to return
        
    Returns:
        Dictionary with search results and status
    """
    try:
        results = await memory_service.deep_recall(
            query=query,
            user_id=user_id,
            restore_to_profile=True
        )
        
        if not results:
            return {
                "success": True,
                "found": False,
                "message": "No matching memories found in the archive.",
                "memories": []
            }
        
        # Format results for the agent
        formatted = []
        for r in results[:max_results]:
            formatted.append({
                "content": r.content,
                "similarity": round(r.similarity, 3),
                "category": r.layer_tag,
                "archived_at": r.archived_at.isoformat() if r.archived_at else None
            })
        
        return {
            "success": True,
            "found": True,
            "message": f"Found {len(formatted)} relevant memories.",
            "memories": formatted
        }
        
    except Exception as e:
        logger.error(f"Archive search failed: {e}")
        return {
            "success": False,
            "found": False,
            "message": f"Search failed: {str(e)}",
            "memories": []
        }


async def get_user_preferences(
    user_id: str,
    category: Optional[str] = None
) -> Dict[str, Any]:
    """
    Get the user's known preferences from their profile.
    
    Useful for personalizing responses without asking redundant questions.
    
    Args:
        user_id: The user's ID
        category: Optional filter for preference type
        
    Returns:
        Dictionary with user preferences
    """
    try:
        profile = await memory_service.get_full_profile(user_id)
        
        if not profile:
            return {
                "success": True,
                "has_profile": False,
                "message": "No profile found for this user.",
                "preferences": []
            }
        
        prefs = profile.long_term_profile.preferences
        
        return {
            "success": True,
            "has_profile": True,
            "preferences": prefs,
            "identity": profile.long_term_profile.identity,
            "emotional_baseline": profile.long_term_profile.emotional_baseline
        }
        
    except Exception as e:
        logger.error(f"Failed to get preferences: {e}")
        return {
            "success": False,
            "has_profile": False,
            "message": f"Failed to retrieve preferences: {str(e)}",
            "preferences": []
        }


async def get_user_context_summary(user_id: str) -> str:
    """
    Get a brief context summary for the user (Tier 1 cheat sheet).
    
    Fast operation designed for injection into system prompts.
    
    Args:
        user_id: The user's ID
        
    Returns:
        Brief context summary string
    """
    return await memory_service.get_user_context(user_id)


# Tool definitions for agent registration
MEMORY_TOOLS = [
    {
        "name": "search_archive_memory",
        "description": "Search the user's long-term memory archive for past information. Use when the user references past conversations or asks 'remember when...'",
        "function": search_archive_memory,
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "What to search for in the memory archive"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "get_user_preferences",
        "description": "Get the user's known preferences and identity information from their profile. Useful for personalization.",
        "function": get_user_preferences,
        "parameters": {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "description": "Optional filter for preference category"
                }
            },
            "required": []
        }
    }
]
