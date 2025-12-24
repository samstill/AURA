"""
Chat Router
===========

Handles conversational AI interactions with the Aura hybrid brain.
Routes requests between:
- FAST path: Gemini Flash for quick responses
- SMART path: Gemini Pro with tool use for complex tasks

Uses the Parallel Speculative Loop (via OrchestratorService) for perceived-instant responses.
"""

import logging
from typing import Optional, List

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from dependencies.auth_dependencies import CurrentUser
from services.llm_service import llm_service
from services.router_service import router_service
from services.orchestrator_service import orchestrator_service

logger = logging.getLogger(__name__)

router = APIRouter()


# -----------------------------------------------------------------------------
# Request/Response Models
# -----------------------------------------------------------------------------
class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    context_window: int = 10


class ChatResponse(BaseModel):
    message: str
    conversation_id: str
    tokens_used: int
    user_id: str
    route: str


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
    Main chat endpoint.
    Orchestrates the response using the Hybrid Brain (OrchestratorService).
    """
    user_text = request.message
    user_id = user.sub
    
    if not llm_service.is_initialized:
        raise HTTPException(
            status_code=503,
            detail="LLM Service not available. Check GOOGLE_API_KEY configuration."
        )
    
    # 1. Classify
    mode = await router_service.classify(user_text)
    logger.info(f"📨 [Chat] {user.name} ({mode}): {user_text[:40]}...")

    # 2. Route via Orchestrator
    if mode == "FAST":
        return StreamingResponse(
            orchestrator_service.stream_fast_response(user_text),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "FAST",
                "Cache-Control": "no-cache",
            }
        )

    elif mode == "SMART":
        # Pass user_id for tool hydration
        return StreamingResponse(
            orchestrator_service.stream_parallel_response(user_text, user_id),
            media_type="text/event-stream",
            headers={
                "X-Aura-Route": "SMART",
                "Cache-Control": "no-cache",
            }
        )
        
    else:
        # Safety fallback
        return StreamingResponse(
            orchestrator_service.stream_fast_response(user_text),
            media_type="text/event-stream"
        )


# -----------------------------------------------------------------------------
# Dev / Test Endpoints (Unauthenticated)
# -----------------------------------------------------------------------------
@router.post("/send/dev")
async def send_message_dev(request: ChatRequest):
    """
    Dev endpoint for testing without Auth headers.
    Uses a hardcoded 'test-user' ID (matches calendar integration UI).
    """
    user_text = request.message
    user_id = "test-user"  # Must match the user_id used in calendar connection 
    
    if not llm_service.is_initialized:
        raise HTTPException(status_code=503, detail="LLM Service unavailable.")

    mode = await router_service.classify(user_text)

    if mode == "SMART":
        return StreamingResponse(
            orchestrator_service.stream_parallel_response(user_text, user_id),
            media_type="text/event-stream",
            headers={"X-Aura-Route": "SMART"}
        )
    else:
        return StreamingResponse(
            orchestrator_service.stream_fast_response(user_text),
            media_type="text/event-stream",
            headers={"X-Aura-Route": "FAST"}
        )


@router.get("/conversations", response_model=List[ConversationSummary])
async def list_conversations(user: CurrentUser):
    return []

@router.delete("/conversations/{conversation_id}")
async def delete_conversation(conversation_id: str, user: CurrentUser):
    raise HTTPException(status_code=404, detail="Not found")

@router.get("/conversations/{conversation_id}/history")
async def get_conversation_history(conversation_id: str, user: CurrentUser):
    raise HTTPException(status_code=404, detail="Not found")
