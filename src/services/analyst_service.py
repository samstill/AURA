"""
Analyst Service - Async Processing & Priority Tagging
======================================================

Handles tasks that exceed the real-time threshold.
Processes results asynchronously and delivers prioritized notifications.

Part of the Aura Routing Algorithm - Phase D (Container 3).

Key Features:
- Executive Brief: Summarizes complex results
- Priority Tagging: 🔴 Urgent, 🟡 Medium, 🟢 Low
- Notification Push: Delivers results to user inbox
"""

import logging
import asyncio
from typing import Optional, Dict, Any, Callable, Awaitable
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import uuid

from services.llm_service import llm_service

logger = logging.getLogger(__name__)


class Priority(Enum):
    """Priority levels for async task results."""
    URGENT = "urgent"    # 🔴 Requires immediate user intervention
    MEDIUM = "medium"    # 🟡 Valuable but non-blocking
    LOW = "low"          # 🟢 FYI only


@dataclass
class NotificationPayload:
    """Notification payload for async task results."""
    id: str
    user_id: str
    priority: Priority
    title: str
    summary: str
    full_result: str
    original_query: str
    created_at: datetime = field(default_factory=datetime.utcnow)
    read: bool = False
    
    @property
    def emoji(self) -> str:
        return {
            Priority.URGENT: "🔴",
            Priority.MEDIUM: "🟡",
            Priority.LOW: "🟢"
        }[self.priority]


@dataclass
class BackgroundTask:
    """Represents a background task being processed."""
    id: str
    user_id: str
    query: str
    task: asyncio.Task
    created_at: datetime = field(default_factory=datetime.utcnow)
    status: str = "running"
    processing_task: Optional[asyncio.Task] = None


class AnalystService:
    """
    Handles asynchronous processing of tasks that exceed real-time limits.
    
    When a task takes longer than the soft timeout (1.5s), it's handed off
    to the Analyst for background processing. The Analyst:
    
    1. Awaits the background task completion
    2. Summarizes the result into an "Executive Brief"
    3. Assigns a priority tag based on content analysis
    4. Pushes a notification to the user
    
    Priority Classification:
    - 🔴 Urgent: Security alerts, critical errors, action required
    - 🟡 Medium: Completed tasks, optimizations, drafts ready
    - 🟢 Low: Fun facts, background info, confirmations
    """
    
    # Keywords for priority classification
    URGENT_KEYWORDS = [
        "error", "failed", "critical", "security", "down", "breach",
        "urgent", "immediately", "warning", "alert", "risk", "danger"
    ]
    
    MEDIUM_KEYWORDS = [
        "completed", "done", "success", "created", "updated", "ready",
        "optimization", "draft", "scheduled", "confirmed"
    ]
    
    def __init__(self):
        self._background_tasks: Dict[str, BackgroundTask] = {}
        self._completed_notifications: Dict[str, NotificationPayload] = {}  # Store completed results
        self._notification_handlers: list[Callable[[NotificationPayload], Awaitable[None]]] = []
        self._llm_service = None
    
    def initialize(self):
        """Initialize the analyst service."""
        self._llm_service = llm_service
        logger.info("✅ Analyst Service initialized")
    
    def register_notification_handler(
        self, 
        handler: Callable[[NotificationPayload], Awaitable[None]]
    ):
        """
        Register a handler to receive notifications.
        
        Handlers are called when async tasks complete with the
        notification payload.
        """
        self._notification_handlers.append(handler)
    
    async def _classify_priority(self, result: str, query: str) -> Priority:
        """
        Classify the priority of a result.
        
        Uses keyword matching first, then falls back to LLM if needed.
        """
        result_lower = result.lower()
        
        # Check for urgent keywords
        for keyword in self.URGENT_KEYWORDS:
            if keyword in result_lower:
                return Priority.URGENT
        
        # Check for medium keywords
        for keyword in self.MEDIUM_KEYWORDS:
            if keyword in result_lower:
                return Priority.MEDIUM
        
        # Default to low priority
        return Priority.LOW
    
    async def _generate_summary(self, result: str, query: str) -> str:
        """
        Generate an executive brief summary of the result.
        
        Creates a concise summary suitable for notification display.
        """
        # If result is already short, use it directly
        if len(result) < 150:
            return result
        
        if not self._llm_service or not self._llm_service.is_initialized:
            # Fallback: truncate
            return result[:147] + "..."
        
        try:
            prompt = f"""Summarize this into 1-2 sentences for a notification:

Original question: {query}

Result: {result}

Summary (max 100 characters):"""
            
            summary = ""
            async for chunk in self._llm_service.get_reflex_response(
                prompt, 
                system_prompt="You are a concise summarizer.",
                include_model_header=False
            ):
                summary += chunk
            
            return summary.strip()[:150]
            
        except Exception as e:
            logger.error(f"Summary generation failed: {e}")
            return result[:147] + "..."
    
    async def _generate_title(self, result: str, query: str) -> str:
        """Generate a short title for the notification."""
        # Simple extraction: first sentence or short query summary
        if len(query) < 50:
            return query[:47] + "..." if len(query) > 47 else query
        
        # Extract first meaningful phrase
        parts = query.split()[:8]
        return " ".join(parts) + "..."
    
    async def _process_completed_task(
        self, 
        task_id: str,
        result: str, 
        query: str, 
        user_id: str
    ) -> NotificationPayload:
        """
        Process a completed background task and create notification.
        """
        # Classify priority
        priority = await self._classify_priority(result, query)
        
        # Generate summary
        summary = await self._generate_summary(result, query)
        
        # Generate title
        title = await self._generate_title(result, query)
        
        # Create notification payload
        notification = NotificationPayload(
            id=task_id,
            user_id=user_id,
            priority=priority,
            title=title,
            summary=summary,
            full_result=result,
            original_query=query
        )
        
        logger.info(
            f"📬 [Analyst] Task {task_id[:8]} completed: "
            f"{notification.emoji} {priority.value}"
        )
        
        return notification
    
    async def _notify_handlers(self, notification: NotificationPayload):
        """Send notification to all registered handlers."""
        for handler in self._notification_handlers:
            try:
                await handler(notification)
            except Exception as e:
                logger.error(f"Notification handler failed: {e}")
    
    async def process_background_task(
        self,
        query: str,
        user_id: str,
        agent_service,  # Pass the service, not the task
        system_prompt: str
    ) -> str:
        """
        Process a background task that exceeded the real-time threshold.
        
        IMPORTANT: We create a NEW agent call here instead of receiving an existing task.
        This ensures the task runs independently of the HTTP request lifecycle.
        
        Args:
            query: Original user query
            user_id: User ID for notification
            agent_service: The agent service to use for processing
            system_prompt: System prompt for the agent
            
        Returns:
            Task ID for tracking
        """
        task_id = str(uuid.uuid4())
        
        # Create a placeholder background task entry
        bg_task = BackgroundTask(
            id=task_id,
            user_id=user_id,
            query=query,
            task=None  # Will be set when we create the real task
        )
        self._background_tasks[task_id] = bg_task
        
        logger.info(f"🔄 [Analyst] Background task {task_id[:8]} started for: {query[:40]}...")
        
        async def _run_agent_and_process():
            """
            Run the agent independently and process its result.
            This is a completely new coroutine that isn't tied to the HTTP request.
            """
            try:
                logger.info(f"📡 [Analyst] Starting independent agent call for task {task_id[:8]}...")
                
                # Create and run a NEW agent call - completely independent
                result = await agent_service.run_agent_loop(
                    query,
                    user_id,
                    system_prompt
                )
                
                # Task completed successfully!
                bg_task.status = "completed"
                logger.info(f"✅ [Analyst] Task {task_id[:8]} completed with {len(result) if result else 0} chars")
                
                # Process through analyst
                notification = await self._process_completed_task(
                    task_id, result, query, user_id
                )
                
                # Store notification for frontend polling
                self.store_notification(notification)
                
                # Notify handlers
                await self._notify_handlers(notification)
                
            except Exception as e:
                bg_task.status = "failed"
                logger.error(f"❌ [Analyst] Task {task_id[:8]} failed: {e}")
                import traceback
                traceback.print_exc()
                
                # Store failure notification
                notification = NotificationPayload(
                    id=task_id,
                    user_id=user_id,
                    priority=Priority.URGENT,
                    title="Task Failed",
                    summary=f"Error: {str(e)[:100]}",
                    full_result=str(e),
                    original_query=query
                )
                self.store_notification(notification)
                await self._notify_handlers(notification)
            
            finally:
                # Keep task info for an hour for status queries
                async def cleanup():
                    await asyncio.sleep(3600)
                    self._background_tasks.pop(task_id, None)
                    self._completed_notifications.pop(task_id, None)
                asyncio.create_task(cleanup())
        
        # Create and start the independent task
        processing_task = asyncio.create_task(
            _run_agent_and_process(), 
            name=f"analyst_bg_{task_id[:8]}"
        )
        bg_task.task = processing_task
        bg_task.processing_task = processing_task
        
        return task_id
    
    def cancel_task(self, task_id: str) -> bool:
        """Cancel a background task (e.g., user disconnected)."""
        bg_task = self._background_tasks.get(task_id)
        if bg_task and bg_task.task and not bg_task.task.done():
            bg_task.task.cancel()
            logger.info(f"🚫 [Analyst] Cancelled task {task_id[:8]}")
            return True
        return False
    
    def get_task_status(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get the status of a background task, including result if completed."""
        bg_task = self._background_tasks.get(task_id)
        
        # Check if we have a completed notification
        notification = self._completed_notifications.get(task_id)
        if notification:
            return {
                "id": task_id,
                "status": "completed",
                "query": notification.original_query[:50],
                "created_at": notification.created_at.isoformat(),
                "result": {
                    "priority": notification.priority.value,
                    "title": notification.title,
                    "summary": notification.summary,
                    "full_result": notification.full_result,
                    "original_query": notification.original_query,
                }
            }
        
        if not bg_task:
            return None
        
        return {
            "id": bg_task.id,
            "status": bg_task.status,
            "query": bg_task.query[:50],
            "created_at": bg_task.created_at.isoformat(),
        }
    
    def get_notification(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get a completed notification by task ID."""
        notification = self._completed_notifications.get(task_id)
        if not notification:
            return None
        
        return {
            "id": notification.id,
            "priority": notification.priority.value,
            "title": notification.title,
            "summary": notification.summary,
            "full_result": notification.full_result,
            "original_query": notification.original_query,
            "created_at": notification.created_at.isoformat(),
            "read": notification.read,
        }
    
    def mark_notification_read(self, task_id: str) -> bool:
        """Mark a notification as read."""
        notification = self._completed_notifications.get(task_id)
        if notification:
            notification.read = True
            return True
        return False
    
    def get_user_notifications(self, user_id: str) -> list[Dict[str, Any]]:
        """Get all notifications for a user."""
        notifications = []
        for notification in self._completed_notifications.values():
            if notification.user_id == user_id:
                notifications.append({
                    "id": notification.id,
                    "priority": notification.priority.value,
                    "title": notification.title,
                    "summary": notification.summary,
                    "original_query": notification.original_query,
                    "created_at": notification.created_at.isoformat(),
                    "read": notification.read,
                })
        return sorted(notifications, key=lambda x: x["created_at"], reverse=True)
    
    def get_user_pending_tasks(self, user_id: str) -> list[Dict[str, Any]]:
        """Get all pending tasks for a user."""
        tasks = []
        for task in self._background_tasks.values():
            if task.user_id == user_id and task.status == "running":
                tasks.append({
                    "id": task.id,
                    "query": task.query[:50],
                    "created_at": task.created_at.isoformat(),
                })
        return tasks
    
    def store_notification(self, notification: NotificationPayload):
        """Store a completed notification for later retrieval."""
        self._completed_notifications[notification.id] = notification
        logger.info(f"📦 [Analyst] Stored notification {notification.id[:8]}")


# Singleton instance
analyst_service = AnalystService()
