"""
Tool Registry Router
====================

API endpoints for:
1. Admin: Registering new MCP tools
2. User: Listing available tools
3. User: Connecting/Disconnecting tools
"""

from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import Optional, Dict

from services.database_service import database_service

router = APIRouter()

# --- Models ---

class ToolRegisterRequest(BaseModel):
    name: str
    description: str
    mcp_endpoint: str
    auth_type: str = "none"

class ToolConnectRequest(BaseModel):
    enabled: bool
    config: Optional[Dict] = None

# --- Endpoints ---

@router.post("/admin/tools")
async def register_tool(payload: ToolRegisterRequest):
    """
    Admin: Register a new tool.
    In a real app, this should be protected by admin role check.
    """
    try:
        # Pydantic model to dict
        tool_data = payload.model_dump()
        result = await database_service.register_tool(tool_data)
        return {"status": "created", "tool": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tools")
async def list_tools():
    """
    User: List all stored tools and their connection status.
    TODO: Get real user_id from auth context.
    For now, defaulting to a demo user ID for the dev console.
    """
    try:
        # Demo User ID for dev console testing (Must be valid UUID)
        user_id = "00000000-0000-0000-0000-000000000000" 
        
        tools = await database_service.get_all_tools(user_id)

        
        # Format for frontend
        formatted = []
        for t in tools:
            formatted.append({
                "id": str(t["id"]),
                "name": t["name"],
                "description": t["description"],
                "mcp_endpoint": t["mcp_endpoint"],
                "auth_type": t["auth_type"],
                "is_enabled": t.get("is_enabled", False)
            })
            
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/tools/{tool_id}/connect")
async def connect_tool(tool_id: str, payload: ToolConnectRequest):
    """
    User: Toggle tool connection.
    """
    try:
        user_id = "00000000-0000-0000-0000-000000000000" # Demo user
        
        await database_service.update_user_tool(
            user_id, 
            tool_id, 
            payload.enabled, 
            payload.config
        )
        return {"status": "updated", "enabled": payload.enabled}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
