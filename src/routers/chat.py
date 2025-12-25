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
    
    Uses the Aura Routing Algorithm:
    1. Semantic cache check (instant hit)
    2. Context-aware classification with tool registry
    3. Routes to FAST_SOLVER, FAST_ERROR, or SECRETARY_PROTOCOL
    """
    user_text = request.message
    user_id = user.sub
    
    if not llm_service.is_initialized:
        raise HTTPException(
            status_code=503,
            detail="LLM Service not available. Check GOOGLE_API_KEY configuration."
        )
    
    logger.info(f"📨 [Chat] {user.name}: {user_text[:40]}...")
    
    # Use the main orchestration flow - handles all routing internally
    return StreamingResponse(
        orchestrator_service.orchestrate_response(user_text, user_id),
        media_type="text/event-stream",
        headers={
            "X-Aura-Algorithm": "v2",
            "Cache-Control": "no-cache",
        }
    )


# -----------------------------------------------------------------------------
# Dev / Test Endpoints (Unauthenticated)
# -----------------------------------------------------------------------------
@router.post("/send/dev")
async def send_message_dev(request: ChatRequest):
    """
    Dev endpoint for testing without Auth headers.
    Uses a hardcoded 'test-user' ID (matches calendar integration UI).
    Uses the full Aura Routing Algorithm.
    """
    user_text = request.message
    user_id = "test-user"  # Must match the user_id used in calendar connection 
    
    if not llm_service.is_initialized:
        raise HTTPException(status_code=503, detail="LLM Service unavailable.")

    logger.info(f"📨 [Chat/Dev] test-user: {user_text[:40]}...")
    
    # Use the main orchestration flow
    return StreamingResponse(
        orchestrator_service.orchestrate_response(user_text, user_id),
        media_type="text/event-stream",
        headers={"X-Aura-Algorithm": "v2"}
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


# -----------------------------------------------------------------------------
# Background Task Status Endpoints
# -----------------------------------------------------------------------------
from services.analyst_service import analyst_service


@router.get("/tasks/{task_id}/status")
async def get_task_status(task_id: str):
    """
    Get the status of a background task.
    Returns result if task is completed.
    """
    status = analyst_service.get_task_status(task_id)
    if not status:
        raise HTTPException(status_code=404, detail="Task not found")
    return status


@router.get("/notifications")
async def get_notifications(user_id: str = "test-user"):
    """Get all notifications for a user."""
    return analyst_service.get_user_notifications(user_id)


@router.get("/notifications/{task_id}")
async def get_notification(task_id: str):
    """Get a specific notification by task ID."""
    notification = analyst_service.get_notification(task_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


@router.post("/notifications/{task_id}/read")
async def mark_notification_read(task_id: str):
    """Mark a notification as read."""
    success = analyst_service.mark_notification_read(task_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"status": "ok"}
