"""
Tool Manager
============

Manages the retrieval of tools for a specific user.
"""

from typing import List, Dict
from .database_service import database_service

class ToolManager:
    """
    Handles the hydration of tools by merging the Registry (DB)
    with User Secrets.
    """
    def __init__(self):
        self.db = database_service

    async def get_active_tools_for_user(self, user_id: str) -> List[Dict]:
        """
        Returns a list of active tools for the user.
        
        Returns:
            List of dicts containing:
            - name: Tool name
            - endpoint: MCP endpoint URL
            - config: User configuration (secrets)
            - auth_type: Authentication strategy
        """
        # Fetch from DB
        rows = await self.db.get_active_tools_for_user(user_id)
        
        # Map to expected structure
        tools = []
        for row in rows:
            tools.append({
                "name": row["name"],
                "endpoint": row["mcp_endpoint"],
                "config": row["config"] or {}, # Ensure dict
                "auth_type": row["auth_type"]
            })
            
        return tools

# Singleton instance
tool_manager = ToolManager()
