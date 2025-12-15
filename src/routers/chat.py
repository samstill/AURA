"""
Chat Router
===========

Handles conversational AI interactions with the Aura hybrid brain.
Routes requests between:
- FAST path: Gemini Flash for quick responses
- SMART path: Gemini Pro with tool use for complex tasks

Uses the Parallel Speculative Loop for perceived-instant responses.
"""

import asyncio
import logging
from typing import Optional, List, AsyncGenerator

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from dependencies.auth_dependencies import require_auth, CurrentUser
from services.authentik_service import AuthenticatedUser
from services.router_service import router_service
from services.orchestrator_service import orchestrator_service

logger = logging.getLogger(__name__)

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
    user_id: str
    route: str  # "FAST" | "SMART"


class ConversationSummary(BaseModel):
    id: str
    title: str
    last_message: str
    created_at: str
    message_count: int


# -----------------------------------------------------------------------------
# Protected Endpoints (require authentication)
# -----------------------------------------------------------------------------
@router.post("/send")
async def send_message(
    request: ChatRequest,
    user: CurrentUser,  # Requires authentication
):
    """
    Send a message and receive an AI response.
    Delegates to Orchestrator Service.
    """
    user_text = request.message
    user_id = user.sub
    
    logger.info(f"📨 [Chat] Message from {user.name}: {user_text[:50]}...")
    
    # 1. Classify the intent
    mode = await router_service.classify(user_text)
    logger.info(f"📍 [Router] Classified as: {mode}")
    
    # 2. Route to appropriate path via Orchestrator
    if mode == "SMART":
        return StreamingResponse(
            orchestrator_service.stream_parallel_response(user_text, user_id),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "SMART",
                "Cache-Control": "no-cache",
            }
        )
    else:
        return StreamingResponse(
            orchestrator_service.stream_fast_response(user_text),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "FAST",
                "Cache-Control": "no-cache",
            }
        )


# -----------------------------------------------------------------------------
# Development Endpoint (NO AUTH - for testing only)
# -----------------------------------------------------------------------------
@router.post("/send/dev")
async def send_message_dev(request: ChatRequest):
    """
    ⚠️ DEVELOPMENT ONLY - No authentication required.
    Delegates to Orchestrator Service.
    """
    user_text = request.message
    
    logger.info(f"🧪 [DEV] Message: {user_text[:50]}...")
    
    # 1. Classify the intent
    mode = await router_service.classify(user_text)
    logger.info(f"📍 [Router] Classified as: {mode}")
    
    # 2. Route to appropriate path via Orchestrator
    if mode == "SMART":
        return StreamingResponse(
            orchestrator_service.stream_parallel_response(user_text, "dev-user-0000"),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "SMART",
                "Cache-Control": "no-cache",
            }
        )
    else:
        return StreamingResponse(
            orchestrator_service.stream_fast_response(user_text),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "FAST",
                "Cache-Control": "no-cache",
            }
        )


@router.post("/send/sync", response_model=ChatResponse)
async def send_message_sync(
    request: ChatRequest,
    user: CurrentUser,
):
    """
    Synchronous version of send_message for clients that don't support streaming.
    Returns a complete JSON response.
    """
    user_text = request.message
    user_id = user.sub
    
    if not llm_service.is_initialized:
        raise HTTPException(
            status_code=503,
            detail="LLM Service not available. Check GOOGLE_API_KEY configuration."
        )
    
    mode = await router_service.classify(user_text)
    
    # Collect full response
    response_text = ""
    
    if mode == "SMART":
        response_text = await agent_service.run_agent_loop(user_text, user_id, AURA_SYSTEM_PROMPT)
    else:
        async for chunk in llm_service.get_reflex_response(user_text, AURA_SYSTEM_PROMPT):
            response_text += chunk
    
    return ChatResponse(
        message=response_text,
        conversation_id=request.conversation_id or "new-conversation",
        tokens_used=0,  # TODO: Track actual token usage
        user_id=user_id,
        route=mode,
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
