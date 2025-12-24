"""
Calendar Router
===============

REST endpoints for Google Calendar integration:
- OAuth connection flow
- Calendar management
- Event queries
"""

import secrets
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Request, Depends, Query
from fastapi.responses import RedirectResponse, HTMLResponse
from pydantic import BaseModel

from config import settings
from services.google_calendar_service import google_calendar_service
from services.calendar_db_service import calendar_db_service
from dependencies.auth_dependencies import require_auth, get_current_user, OptionalUser
from services.authentik_service import AuthenticatedUser

logger = logging.getLogger(__name__)

router = APIRouter()


# -----------------------------------------------------------------------------
# Response Models
# -----------------------------------------------------------------------------
class CalendarStatusResponse(BaseModel):
    """Google Calendar connection status."""
    connected: bool
    email: Optional[str] = None
    calendars_count: int = 0


class CalendarSourceResponse(BaseModel):
    """Calendar source info."""
    id: int
    google_calendar_id: str
    calendar_name: str
    access_role: Optional[str]
    sync_enabled: bool
    color: Optional[str]


class CalendarSyncRequest(BaseModel):
    """Request to toggle calendar sync."""
    sync_enabled: bool


class EventResponse(BaseModel):
    """Calendar event."""
    id: str
    title: str
    description: str
    start: str
    end: str
    location: str
    all_day: bool
    source_calendar: str
    html_link: Optional[str]
    attendees: List[dict] = []


class EventsQueryParams(BaseModel):
    """Query parameters for events."""
    start: datetime
    end: datetime


# -----------------------------------------------------------------------------
# OAuth Flow
# -----------------------------------------------------------------------------
@router.get("/calendar/connect")
async def connect_google_calendar(
    request: Request,
    user_id: Optional[str] = Query(None, description="User ID (for API testing)"),
    user: OptionalUser = None,
):
    """
    Initiate Google Calendar OAuth flow.
    
    Redirects user to Google for authorization.
    """
    if not settings.google_calendar_client_id:
        raise HTTPException(
            status_code=503,
            detail="Google Calendar integration not configured. Set GOOGLE_CALENDAR_CLIENT_ID and GOOGLE_CALENDAR_CLIENT_SECRET."
        )
    
    # Get user ID from auth or query param (for testing)
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    # Generate state for CSRF protection (includes user_id)
    state = f"{actual_user_id}:{secrets.token_urlsafe(32)}"
    
    authorization_url = google_calendar_service.get_authorization_url(state)
    
    response = RedirectResponse(url=authorization_url, status_code=302)
    
    # Store state in cookie for validation
    response.set_cookie(
        key="google_oauth_state",
        value=state,
        httponly=True,
        secure=settings.environment == "production",
        samesite="lax",
        max_age=600,  # 10 minutes
    )
    
    return response


@router.get("/calendar/callback/google")
async def google_calendar_callback(
    request: Request,
    code: str,
    state: str,
):
    """
    Handle OAuth callback from Google.
    
    Exchanges code for tokens and discovers calendars.
    """
    # Verify state (CSRF protection)
    stored_state = request.cookies.get("google_oauth_state")
    if not stored_state or stored_state != state:
        raise HTTPException(
            status_code=400,
            detail="Invalid state parameter. Please try connecting again."
        )
    
    # Extract user_id from state
    try:
        user_id = state.split(":")[0]
    except (IndexError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid state format")
    
    try:
        # Exchange code for tokens
        tokens = await google_calendar_service.exchange_code_for_tokens(code)
        
        # Get user email
        email = await google_calendar_service.get_user_email(tokens["access_token"])
        
        # Calculate token expiry
        expires_in = tokens.get("expires_in", 3600)
        token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
        
        # Save tokens
        await calendar_db_service.save_tokens(
            user_id=user_id,
            access_token=tokens["access_token"],
            refresh_token=tokens.get("refresh_token", ""),
            token_expiry=token_expiry,
            email=email,
        )
        
        # Discover calendars
        calendars = await google_calendar_service.discover_calendars(user_id)
        
        logger.info(f"✅ Google Calendar connected for user {user_id}, found {len(calendars)} calendars")
        
        # Return success page
        success_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Calendar Connected</title>
            <style>
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                }}
                .container {{
                    text-align: center;
                    padding: 40px;
                    background: rgba(255,255,255,0.1);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                }}
                h1 {{ margin-bottom: 10px; }}
                p {{ opacity: 0.9; }}
                .calendars {{ margin-top: 20px; font-size: 14px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🎉 Calendar Connected!</h1>
                <p>Successfully connected <strong>{email}</strong></p>
                <div class="calendars">
                    Found {len(calendars)} calendars. You can manage sync settings in the app.
                </div>
                <p style="margin-top: 30px; font-size: 14px;">You can close this window.</p>
            </div>
            <script>
                // Attempt to close window or notify parent
                setTimeout(() => {{
                    if (window.opener) {{
                        window.opener.postMessage({{ type: 'GOOGLE_CALENDAR_CONNECTED', email: '{email}' }}, '*');
                        window.close();
                    }}
                }}, 2000);
            </script>
        </body>
        </html>
        """
        
        response = HTMLResponse(content=success_html)
        response.delete_cookie("google_oauth_state")
        return response
        
    except Exception as e:
        logger.error(f"Google Calendar callback error: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to connect: {str(e)}")


# -----------------------------------------------------------------------------
# Status & Management
# -----------------------------------------------------------------------------
@router.get("/calendar/status", response_model=CalendarStatusResponse)
async def get_calendar_status(
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """Check if Google Calendar is connected."""
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    tokens = await calendar_db_service.get_tokens(actual_user_id)
    if not tokens:
        return CalendarStatusResponse(connected=False)
    
    calendars = await calendar_db_service.get_calendars(actual_user_id)
    
    return CalendarStatusResponse(
        connected=True,
        email=tokens.get("email"),
        calendars_count=len(calendars)
    )


@router.post("/calendar/disconnect")
async def disconnect_google_calendar(
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """Disconnect Google Calendar integration."""
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    deleted = await calendar_db_service.delete_integration(actual_user_id)
    
    if not deleted:
        raise HTTPException(status_code=404, detail="No integration found")
    
    return {"message": "Google Calendar disconnected"}


# -----------------------------------------------------------------------------
# Calendar Sources
# -----------------------------------------------------------------------------
@router.get("/calendar/sources", response_model=List[CalendarSourceResponse])
async def list_calendar_sources(
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """List all discovered calendars with sync status."""
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    calendars = await calendar_db_service.get_calendars(actual_user_id)
    return [CalendarSourceResponse(**cal) for cal in calendars]


@router.patch("/calendar/sources/{calendar_id}/sync")
async def toggle_calendar_sync(
    calendar_id: int,
    body: CalendarSyncRequest,
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """Toggle sync for a specific calendar."""
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    updated = await calendar_db_service.update_calendar_sync(
        user_id=actual_user_id,
        calendar_id=calendar_id,
        sync_enabled=body.sync_enabled
    )
    
    if not updated:
        raise HTTPException(status_code=404, detail="Calendar not found")
    
    return {"message": "Sync preference updated", "sync_enabled": body.sync_enabled}


@router.post("/calendar/refresh")
async def refresh_calendars(
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """Re-discover calendars from Google."""
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    try:
        calendars = await google_calendar_service.discover_calendars(actual_user_id)
        return {"message": "Calendars refreshed", "count": len(calendars)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# -----------------------------------------------------------------------------
# Events
# -----------------------------------------------------------------------------
@router.get("/calendar/events", response_model=List[EventResponse])
async def get_calendar_events(
    start: datetime = Query(..., description="Start time (ISO format)"),
    end: datetime = Query(..., description="End time (ISO format)"),
    user_id: Optional[str] = Query(None),
    user: OptionalUser = None,
):
    """
    Get events from synced calendars within a time range.
    """
    actual_user_id = user.sub if user else user_id
    if not actual_user_id:
        raise HTTPException(status_code=401, detail="User ID required")
    
    # Ensure timezone awareness
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    
    try:
        events = await google_calendar_service.get_events(
            user_id=actual_user_id,
            start_time=start,
            end_time=end
        )
        return [EventResponse(**event) for event in events]
    except Exception as e:
        logger.error(f"Failed to get events: {e}")
        raise HTTPException(status_code=400, detail=str(e))
