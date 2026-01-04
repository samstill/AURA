"""
Task Service
============

Manages Secretary Background Tasks.
"""

from typing import List, Optional
from services.database_service import database_service
from services.llm_service import llm_service

class TaskService:
    async def create_task(self, user_id: str, title: str, status: str = "processing", result: str = None) -> dict:
        """Create a new background task."""
        return await database_service.create_task(user_id, title, status, result)

    async def get_tasks(self, user_id: str, limit: int = 50, offset: int = 0) -> List[dict]:
        """Get tasks for a user."""
        return await database_service.get_tasks(user_id, limit, offset)

    async def get_summary_stats(self, user_id: str) -> dict:
        """Get task counts (total, unread)."""
        return await database_service.get_task_stats(user_id)

    async def mark_as_read(self, task_id: int, user_id: str) -> bool:
        """Mark a task as read."""
        return await database_service.mark_task_read(task_id, user_id)

    async def get_task_overview(self, user_id: str) -> str:
        """Generate a natural language summary of unread tasks using LLM."""
        # 1. Fetch unread tasks
        tasks = await database_service.get_tasks(user_id, limit=10, offset=0)
        unread_tasks = [t for t in tasks if not t.get('is_read')]

        if not unread_tasks:
            return "You have no unread tasks. The day is clear."

        # 2. Format tasks for LLM
        task_descriptions = "\n".join([
            f"- {t['title']} ({t['status']}): {t.get('result', '')[:100]}..."
            for t in unread_tasks
        ])

        # 3. Generate summary
        prompt = f"""
        You are an elite executive secretary. Summarize these background tasks for your boss in 1-2 concise, professional sentences. 
        Focus on what's important. Do not list them one by one. Use a calm, reassuring tone.
        
        Tasks:
        {task_descriptions}
        """
        
        summary = ""
        async for chunk in llm_service.get_reflex_response(prompt, system_prompt="You are Aura, an efficient AI secretary."):
            summary += chunk
            
        return summary.strip()

task_service = TaskService()
