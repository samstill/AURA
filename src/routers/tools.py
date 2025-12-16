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

class EnhancePromptRequest(BaseModel):
    name: str
    short_description: str

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


@router.post("/admin/enhance_prompt")
async def enhance_prompt(payload: EnhancePromptRequest):
    """
    Use AI to generate an optimized tool description.
    """
    from services.llm_service import llm_service
    
    prompt = f"""You are writing a tool description for an AI agent.
The tool is called "{payload.name}" and the user described it as: "{payload.short_description}"

Write a clear, concise description (2-3 sentences) that tells the AI:
1. What this tool does
2. When to use it (trigger words/phrases)
3. What kind of user requests should activate this tool

Be specific and action-oriented. Output ONLY the description, no quotes or labels."""

    try:
        result = ""
        async for chunk in llm_service.get_reflex_response(prompt, "", include_model_header=False):
            result += chunk
        
        # Clean up result
        result = result.strip().strip('"').strip("'")
        
        return {"enhanced_description": result}
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


@router.delete("/admin/tools/{tool_id}")
async def delete_tool(tool_id: str):
    """
    Admin: Delete (soft) a tool.
    """
    try:
        success = await database_service.delete_tool(tool_id)
        if not success:
            raise HTTPException(status_code=404, detail="Tool not found")
        return {"status": "deleted", "id": tool_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tools/{tool_id}/oauth/start")
async def start_oauth(tool_id: str):
    """
    Generate OAuth2 authorization URL for a tool.
    """
    from config import settings
    
    try:
        # Use configured Client ID or fallback to placeholder (with warning)
        client_id = settings.github_client_id or "YOUR_GITHUB_CLIENT_ID"
        redirect_uri = f"{settings.base_url}/api/v1/tools/oauth/callback"
        
        # Include tool_id in state so we know which tool to activate on callback
        state = tool_id
        
        # Construct real URL
        github_url = (
            f"https://github.com/login/oauth/authorize?"
            f"client_id={client_id}&"
            "scope=repo user&"
            f"redirect_uri={redirect_uri}&"
            f"state={state}"
        )
        
        return {"url": github_url}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tools/oauth/callback")
async def oauth_callback(code: str, state: str = None):
    """
    Handle OAuth2 callback from GitHub.
    Exchange authorization code for access token and store it.
    """
    import httpx
    from config import settings
    from fastapi.responses import RedirectResponse
    
    tool_id = state  # We passed tool_id as state
    user_id = "00000000-0000-0000-0000-000000000000"  # Demo user
    
    try:
        # Exchange code for access token
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://github.com/login/oauth/access_token",
                data={
                    "client_id": settings.github_client_id,
                    "client_secret": settings.github_client_secret,
                    "code": code,
                    "redirect_uri": f"{settings.base_url}/api/v1/tools/oauth/callback"
                },
                headers={"Accept": "application/json"}
            )
            
            token_data = response.json()
            
            if "access_token" not in token_data:
                error = token_data.get("error_description", "Unknown error")
                return RedirectResponse(
                    url=f"/admin_console.html?error={error}",
                    status_code=302
                )
            
            access_token = token_data["access_token"]
            
            # Store the token and mark tool as connected
            if tool_id:
                await database_service.update_user_tool(
                    user_id,
                    tool_id,
                    enabled=True,
                    config={"access_token": access_token}
                )
            
            # Redirect back to admin console with success
            return RedirectResponse(
                url="/admin_console.html?oauth=success",
                status_code=302
            )
            
    except Exception as e:
        return RedirectResponse(
            url=f"/admin_console.html?error={str(e)}",
            status_code=302
        )
