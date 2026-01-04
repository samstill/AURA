"""
Task Router
===========

Endpoints for Secretary Background Tasks.
"""

from fastapi import APIRouter, HTTPException, Query
from dependencies.auth_dependencies import CurrentUser
from services.task_service import task_service

router = APIRouter()

@router.get("/summary")
async def get_task_summary(user: CurrentUser):
    """Get task counts (total, unread)."""
    return await task_service.get_summary_stats(user.sub)

@router.get("/overview")
async def get_task_overview(user: CurrentUser):
    """Get a generative natural language overview of unread tasks."""
    summary = await task_service.get_task_overview(user.sub)
    return {"overview": summary}

@router.get("")
async def get_tasks(
    user: CurrentUser,
    limit: int = 50,
    offset: int = 0
):
    """Get list of background tasks."""
    return await task_service.get_tasks(user.sub, limit, offset)

@router.post("/{task_id}/read")
async def mark_task_read(task_id: int, user: CurrentUser):
    """Mark a task as read."""
    success = await task_service.mark_as_read(task_id, user.sub)
    if not success:
        raise HTTPException(status_code=404, detail="Task not found")
    return {"status": "success"}
