"""
Authentication Router
=====================

OAuth2/OIDC authentication using Authentik as Identity Provider.

Endpoints:
- /login - Redirect to Authentik for authentication
- /callback - Handle OAuth2 callback from Authentik
- /logout - End session and redirect to Authentik logout
- /me - Get current user profile (protected)
- /refresh - Refresh access token
"""

import secrets
from typing import Optional
from fastapi import APIRouter, HTTPException, Response, Request, Depends
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from config import settings
from services.authentik_service import authentik_service, AuthenticatedUser
from dependencies.auth_dependencies import require_auth, get_current_user, OptionalUser

router = APIRouter()


# -----------------------------------------------------------------------------
# Response Models
# -----------------------------------------------------------------------------
class TokenResponse(BaseModel):
    """OAuth2 token response."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_token: Optional[str] = None
    id_token: Optional[str] = None


class UserResponse(BaseModel):
    """User profile response."""
    id: str
    email: str
    email_verified: bool
    name: str
    username: str
    groups: list[str]


class AuthStatusResponse(BaseModel):
    """Authentication status response."""
    authenticated: bool
    user: Optional[UserResponse] = None


# -----------------------------------------------------------------------------
# OAuth2 Flow Endpoints
# -----------------------------------------------------------------------------
@router.get("/login")
async def login(
    request: Request,
    redirect_uri: Optional[str] = None,
):
    """
    Initiate OAuth2 authorization flow.
    
    Redirects user to Authentik login page.
    
    Query Parameters:
        redirect_uri: Optional URL to redirect after successful login
    """
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # Store state and optional redirect in session/cookie
    # For now, we'll embed redirect_uri in state (simple approach)
    # In production, use proper session storage
    
    authorization_url = authentik_service.get_authorization_url(state)
    
    response = RedirectResponse(url=authorization_url, status_code=302)
    
    # Store state in a secure HTTP-only cookie
    response.set_cookie(
        key="oauth_state",
        value=state,
        httponly=True,
        secure=settings.environment == "production",
        samesite="lax",
        max_age=600,  # 10 minutes
    )
    
    # Store intended redirect URI if provided
    if redirect_uri:
        response.set_cookie(
            key="post_login_redirect",
            value=redirect_uri,
            httponly=True,
            secure=settings.environment == "production",
            samesite="lax",
            max_age=600,
        )
    
    return response


@router.get("/callback")
async def callback(
    request: Request,
    code: str,
    state: str,
):
    """
    Handle OAuth2 callback from Authentik.
    
    Exchanges authorization code for tokens and sets session cookies.
    """
    # Verify state matches (CSRF protection)
    stored_state = request.cookies.get("oauth_state")
    if not stored_state or stored_state != state:
        raise HTTPException(
            status_code=400,
            detail="Invalid state parameter. Possible CSRF attack.",
        )
    
    try:
        # Exchange code for tokens
        tokens = await authentik_service.exchange_code_for_tokens(code)
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to exchange authorization code: {str(e)}",
        )
    
    # Get post-login redirect URI or default to home
    redirect_uri = request.cookies.get("post_login_redirect", "/")
    
    # Create response with redirect
    response = RedirectResponse(url=redirect_uri, status_code=302)
    
    # Set tokens in HTTP-only cookies (secure for browser-based auth)
    response.set_cookie(
        key="access_token",
        value=tokens["access_token"],
        httponly=True,
        secure=settings.environment == "production",
        samesite="lax",
        max_age=tokens.get("expires_in", 3600),
    )
    
    if "refresh_token" in tokens:
        response.set_cookie(
            key="refresh_token",
            value=tokens["refresh_token"],
            httponly=True,
            secure=settings.environment == "production",
            samesite="lax",
            max_age=60 * 60 * 24 * 7,  # 7 days
        )
    
    if "id_token" in tokens:
        response.set_cookie(
            key="id_token",
            value=tokens["id_token"],
            httponly=True,
            secure=settings.environment == "production",
            samesite="lax",
            max_age=tokens.get("expires_in", 3600),
        )
    
    # Clear temporary cookies
    response.delete_cookie("oauth_state")
    response.delete_cookie("post_login_redirect")
    
    return response


@router.get("/callback/token", response_model=TokenResponse)
async def callback_token(
    code: str,
    state: Optional[str] = None,
):
    """
    Handle OAuth2 callback and return tokens directly (for mobile/API clients).
    
    Unlike /callback, this returns JSON tokens instead of setting cookies.
    Used by Flutter app and other API clients.
    """
    try:
        tokens = await authentik_service.exchange_code_for_tokens(code)
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to exchange authorization code: {str(e)}",
        )
    
    return TokenResponse(
        access_token=tokens["access_token"],
        token_type="bearer",
        expires_in=tokens.get("expires_in", 3600),
        refresh_token=tokens.get("refresh_token"),
        id_token=tokens.get("id_token"),
    )


@router.post("/logout")
async def logout(
    request: Request,
    response: Response,
):
    """
    End the current session.
    
    Clears session cookies and optionally redirects to Authentik logout.
    """
    # Get ID token for Authentik logout
    id_token = request.cookies.get("id_token")
    
    # Clear all auth cookies
    response.delete_cookie("access_token")
    response.delete_cookie("refresh_token")
    response.delete_cookie("id_token")
    
    # If we have an ID token, return the Authentik logout URL
    if id_token:
        logout_url = authentik_service.get_logout_url(
            id_token,
            post_logout_redirect=settings.base_url,
        )
        return {"message": "Logged out", "authentik_logout_url": logout_url}
    
    return {"message": "Logged out"}


@router.get("/logout/redirect")
async def logout_redirect(request: Request):
    """
    Logout and redirect to Authentik for full session termination.
    """
    id_token = request.cookies.get("id_token")
    
    if id_token:
        logout_url = authentik_service.get_logout_url(
            id_token,
            post_logout_redirect=settings.base_url,
        )
    else:
        logout_url = settings.base_url
    
    response = RedirectResponse(url=logout_url, status_code=302)
    
    # Clear all auth cookies
    response.delete_cookie("access_token")
    response.delete_cookie("refresh_token")
    response.delete_cookie("id_token")
    
    return response


# -----------------------------------------------------------------------------
# Token Management
# -----------------------------------------------------------------------------
@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: Request, response: Response):
    """
    Refresh the access token using the refresh token.
    """
    refresh_token = request.cookies.get("refresh_token")
    
    if not refresh_token:
        raise HTTPException(
            status_code=401,
            detail="No refresh token available",
        )
    
    try:
        tokens = await authentik_service.refresh_access_token(refresh_token)
    except Exception as e:
        # Refresh token expired or invalid, user needs to re-authenticate
        response.delete_cookie("access_token")
        response.delete_cookie("refresh_token")
        response.delete_cookie("id_token")
        raise HTTPException(
            status_code=401,
            detail="Refresh token expired. Please login again.",
        )
    
    # Update cookies with new tokens
    response.set_cookie(
        key="access_token",
        value=tokens["access_token"],
        httponly=True,
        secure=settings.environment == "production",
        samesite="lax",
        max_age=tokens.get("expires_in", 3600),
    )
    
    return TokenResponse(
        access_token=tokens["access_token"],
        token_type="bearer",
        expires_in=tokens.get("expires_in", 3600),
        refresh_token=tokens.get("refresh_token"),
    )


# -----------------------------------------------------------------------------
# User Info Endpoints
# -----------------------------------------------------------------------------
@router.get("/me", response_model=UserResponse)
async def get_me(user: AuthenticatedUser = Depends(require_auth)):
    """
    Get the current authenticated user's profile.
    
    Requires valid access token.
    """
    return UserResponse(
        id=user.sub,
        email=user.email,
        email_verified=user.email_verified,
        name=user.name,
        username=user.preferred_username,
        groups=user.groups,
    )


@router.get("/status", response_model=AuthStatusResponse)
async def get_auth_status(user: OptionalUser):
    """
    Check authentication status.
    
    Returns whether the user is authenticated and their profile if so.
    Does not require authentication.
    """
    if user:
        return AuthStatusResponse(
            authenticated=True,
            user=UserResponse(
                id=user.sub,
                email=user.email,
                email_verified=user.email_verified,
                name=user.name,
                username=user.preferred_username,
                groups=user.groups,
            ),
        )
    
    return AuthStatusResponse(authenticated=False)
