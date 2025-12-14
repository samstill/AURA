"""
Chat Router
===========

Handles conversational AI interactions.
Integrates with OpenAI and maintains conversation context via Qdrant.

All endpoints require authentication via Authentik.
"""

from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from dependencies.auth_dependencies import require_auth, CurrentUser
from services.authentik_service import AuthenticatedUser

router = APIRouter()


# -----------------------------------------------------------------------------
# Request/Response Models
# -----------------------------------------------------------------------------
class Message(BaseModel):
    role: str  # "user" | "assistant" | "system"
    content: str


class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    context_window: int = 10  # Number of previous messages to include


class ChatResponse(BaseModel):
    message: str
    conversation_id: str
    tokens_used: int
    user_id: str  # Added to show which user initiated


class ConversationSummary(BaseModel):
    id: str
    title: str
    last_message: str
    created_at: str
    message_count: int


# -----------------------------------------------------------------------------
# Protected Endpoints (require authentication)
# -----------------------------------------------------------------------------
@router.post("/send", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    user: CurrentUser,  # Requires authentication
):
    """
    Send a message and receive an AI response.
    
    Requires authentication.
    
    Flow:
    1. Retrieve conversation context from Qdrant (Supermemory)
    2. Construct prompt with context
    3. Call OpenAI API
    4. Store response in Qdrant
    5. Return response to client
    
    TODO: Implement full flow with services.
    """
    # For now, return a placeholder response
    return ChatResponse(
        message=f"Hello {user.name}! Chat is not yet implemented. Your message: {request.message}",
        conversation_id=request.conversation_id or "new-conversation",
        tokens_used=0,
        user_id=user.sub,
    )


@router.get("/conversations", response_model=List[ConversationSummary])
async def list_conversations(
    user: CurrentUser,  # Requires authentication
):
    """
    List all conversations for the current authenticated user.
    """
    # TODO: Fetch conversations from database filtered by user.sub
    return []


@router.get("/conversations/{conversation_id}/history")
async def get_conversation_history(
    conversation_id: str,
    user: CurrentUser,  # Requires authentication
    limit: int = 50,
):
    """
    Retrieve message history for a specific conversation.
    
    Args:
        conversation_id: The conversation to retrieve
        limit: Maximum number of messages to return
    """
    # TODO: Verify user owns this conversation
    raise HTTPException(
        status_code=404,
        detail=f"Conversation {conversation_id} not found"
    )


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user: CurrentUser,  # Requires authentication
):
    """
    Delete a conversation and its history.
    
    This also removes the embeddings from Qdrant.
    """
    # TODO: Verify user owns this conversation before deleting
    raise HTTPException(
        status_code=404,
        detail=f"Conversation {conversation_id} not found"
    )
