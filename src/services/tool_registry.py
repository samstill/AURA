"""
Tool Registry Service
=====================

Maintains a registry of all available tools with their descriptions.
Used by the router for LLM-based intent classification.
"""

import logging
from typing import Dict, List, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class ToolInfo:
    """Information about an available tool."""
    name: str
    description: str
    capabilities: List[str]
    is_connected: bool = True


class ToolRegistryService:
    """
    Aggregates all available tools for dynamic routing.
    
    Provides a unified view of:
    - Built-in tools (calendar)
    - MCP tools (dynamically loaded for user)
    """
    
    # Built-in tool definitions with their capabilities
    BUILTIN_TOOLS = {
        "calendar": ToolInfo(
            name="calendar",
            description="Google Calendar integration for scheduling and time management",
            capabilities=[
                "view schedule and events",
                "create/update/delete events",
                "check availability",
                "find free time slots",
                "reschedule meetings",
                "set reminders"
            ]
        ),
        # Add more built-in tools here as they're implemented
    }
    
    def __init__(self):
        self._initialized = False
        self._user_tools: Dict[str, Dict[str, ToolInfo]] = {}  # user_id -> {tool_name: ToolInfo}
    
    def initialize(self):
        """Initialize the tool registry."""
        self._initialized = True
        logger.info("🔧 [ToolRegistry] Tool Registry initialized")
    
    async def get_available_tools(
        self, 
        user_id: str,
        include_builtin: bool = True
    ) -> Dict[str, ToolInfo]:
        """
        Get all available tools for a user.
        
        Returns:
            Dict of {tool_name: ToolInfo}
        """
        tools = {}
        
        # Add built-in tools
        if include_builtin:
            for name, info in self.BUILTIN_TOOLS.items():
                # Check if built-in tool is connected for this user
                # For now, calendar is always available if user exists
                tools[name] = info
        
        # Add user's MCP tools (if any)
        if user_id in self._user_tools:
            tools.update(self._user_tools[user_id])
        
        return tools
    
    def get_tools_context_for_llm(self, tools: Dict[str, ToolInfo]) -> str:
        """
        Generate a concise context string for LLM classification.
        
        Args:
            tools: Dict of available tools
            
        Returns:
            String like "calendar (schedule events, check availability), github (repos, PRs)"
        """
        if not tools:
            return "No tools available"
        
        parts = []
        for name, info in tools.items():
            # Take first 3 capabilities for brevity
            caps = ", ".join(info.capabilities[:3])
            parts.append(f"{name} ({caps})")
        
        return "; ".join(parts)
    
    def get_tool_registry_dict(self, tools: Dict[str, ToolInfo]) -> Dict[str, bool]:
        """
        Get a simple dict of {tool_name: is_available} for router.
        """
        return {name: info.is_connected for name, info in tools.items()}
    
    def register_mcp_tool(
        self, 
        user_id: str, 
        name: str, 
        description: str,
        capabilities: List[str]
    ):
        """Register an MCP tool for a user."""
        if user_id not in self._user_tools:
            self._user_tools[user_id] = {}
        
        self._user_tools[user_id][name] = ToolInfo(
            name=name,
            description=description,
            capabilities=capabilities,
            is_connected=True
        )
        logger.info(f"🔧 [ToolRegistry] Registered {name} for user {user_id}")
    
    def unregister_tool(self, user_id: str, name: str):
        """Unregister a tool for a user."""
        if user_id in self._user_tools and name in self._user_tools[user_id]:
            del self._user_tools[user_id][name]
            logger.info(f"🔧 [ToolRegistry] Unregistered {name} for user {user_id}")


# Singleton instance
tool_registry = ToolRegistryService()
