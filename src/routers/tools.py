"""
Tool Registry Router
====================

API endpoints for:
1. Admin: Registering new MCP tools
2. User: Listing available tools
3. User: Connecting/Disconnecting tools
"""

from urllib.parse import quote
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import Optional, Dict

from config import settings
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
    
    WARNING: This endpoint should be protected by authentication in production.
    """
    # Security: Block in production if not in development mode
    if settings.environment != "development":
        raise HTTPException(
            status_code=403,
            detail="Admin endpoints require authentication in production"
        )
    
    try:
        # Pydantic model to dict
        tool_data = payload.model_dump()
        result = await database_service.register_tool(tool_data)
        return {"status": "created", "tool": result}
    except Exception as e:
        # Don't expose internal error details
        raise HTTPException(status_code=500, detail="Failed to register tool")


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
        # Don't expose internal error details
        raise HTTPException(status_code=500, detail="Failed to enhance prompt")


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
        raise HTTPException(status_code=500, detail="Failed to update tool connection")


@router.delete("/admin/tools/{tool_id}")
async def delete_tool(tool_id: str):
    """
    Admin: Delete (soft) a tool.
    
    WARNING: This endpoint should be protected by authentication in production.
    """
    # Security: Block in production if not in development mode
    if settings.environment != "development":
        raise HTTPException(
            status_code=403,
            detail="Admin endpoints require authentication in production"
        )
    
    try:
        success = await database_service.delete_tool(tool_id)
        if not success:
            raise HTTPException(status_code=404, detail="Tool not found")
        return {"status": "deleted", "id": tool_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to delete tool")


@router.get("/tools/{tool_id}/oauth/start")
async def start_oauth(tool_id: str):
    """
    Generate OAuth2 authorization URL for a tool.
    """
    # Security: Block this endpoint in production without proper credentials
    if settings.environment != "development" and not settings.github_client_id:
        raise HTTPException(
            status_code=503,
            detail="GitHub OAuth not configured"
        )
    
    try:
        # Use configured Client ID or provide clear error
        client_id = settings.github_client_id
        if not client_id:
            raise HTTPException(
                status_code=503,
                detail="GitHub OAuth not configured. Set GITHUB_CLIENT_ID environment variable."
            )
        
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
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to generate OAuth URL")


@router.get("/tools/oauth/callback")
async def oauth_callback(code: str, state: str = None):
    """
    Handle OAuth2 callback from GitHub.
    Exchange authorization code for access token and store it.
    """
    import httpx
    from fastapi.responses import RedirectResponse
    
    tool_id = state  # We passed tool_id as state
    user_id = "00000000-0000-0000-0000-000000000000"  # Demo user
    
    # Security: Block this endpoint in production without proper credentials
    if not settings.github_client_id or not settings.github_client_secret:
        return RedirectResponse(
            url=f"/admin_console.html?error={quote('GitHub OAuth not configured')}",
            status_code=302
        )
    
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
                # URL-encode error message to prevent XSS/injection
                error = quote(token_data.get("error_description", "Authentication failed"))
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
        # URL-encode error message to prevent XSS/injection
        safe_error = quote("OAuth callback failed")
        return RedirectResponse(
            url=f"/admin_console.html?error={safe_error}",
            status_code=302
        )
