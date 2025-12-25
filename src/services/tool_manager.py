"""
Tool Manager
============

Manages the retrieval of tools for a specific user.
All tools are DB-managed via the Admin Console. No hardcoding.
"""

import logging
from typing import List, Dict
from .database_service import database_service

logger = logging.getLogger(__name__)


class ToolManager:
    """
    Handles the hydration of tools by querying the registry (DB).
    No hardcoded tools. Everything is managed via Admin Console.
    """
    def __init__(self):
        self.db = database_service

    async def get_active_tools_for_user(self, user_id: str) -> List[Dict]:
        """
        Returns a list of active tools for the user from the database.
        
        Returns:
            List of dicts containing:
            - name: Tool name
            - endpoint: MCP endpoint URL
            - config: User configuration (secrets)
            - auth_type: Authentication strategy
        """
        # Skip DB query for dev/test user (not a valid UUID)
        if user_id == "test-user":
            logger.warning(f"No tools found for user {user_id}. Register tools via Admin Console.")
            return []
        
        try:
            # Get tools that are globally enabled OR enabled for this user
            tools = await self.db.get_active_tools_for_user(user_id)
            
            if not tools:
                logger.warning(f"No tools found for user {user_id}. Register tools via Admin Console.")
                return []
            
            logger.info(f"Loaded {len(tools)} active tools for user {user_id}")
            return tools
            
        except Exception as e:
            logger.error(f"❌ Failed to fetch tools: {e}")
            return []


# Singleton instance
tool_manager = ToolManager()
