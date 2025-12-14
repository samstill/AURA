"""
Authentication Dependencies
===========================

FastAPI dependencies for route protection using Authentik tokens.
"""

from typing import Optional, Annotated
from fastapi import Depends, HTTPException, status, Cookie, Header
from pydantic import BaseModel

from services.authentik_service import authentik_service, AuthenticatedUser


class TokenData(BaseModel):
    """Data extracted from a validated token."""
    sub: str
    email: str
    name: str
    groups: list[str] = []


async def get_token_from_header(
    authorization: Annotated[Optional[str], Header()] = None
) -> Optional[str]:
    """
    Extract Bearer token from Authorization header.
    
    Returns None if no token is present.
    """
    if not authorization:
        return None
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    
    return parts[1]


async def get_token_from_cookie(
    access_token: Annotated[Optional[str], Cookie()] = None
) -> Optional[str]:
    """
    Extract access token from cookie.
    
    Used for browser-based flows where tokens are stored in HTTP-only cookies.
    """
    return access_token


async def get_access_token(
    header_token: Annotated[Optional[str], Depends(get_token_from_header)],
    cookie_token: Annotated[Optional[str], Depends(get_token_from_cookie)],
) -> Optional[str]:
    """
    Get access token from either header or cookie.
    
    Priority: Header > Cookie
    """
    return header_token or cookie_token


async def get_current_user(
    token: Annotated[Optional[str], Depends(get_access_token)]
) -> Optional[AuthenticatedUser]:
    """
    Get the currently authenticated user.
    
    Returns None if not authenticated (no token or invalid token).
    Use this for optional authentication.
    """
    if not token:
        return None
    
    try:
        user = await authentik_service.get_user_info(token)
        return user
    except Exception:
        return None


async def require_auth(
    user: Annotated[Optional[AuthenticatedUser], Depends(get_current_user)]
) -> AuthenticatedUser:
    """
    Require authentication for a route.
    
    Raises 401 if not authenticated.
    Use this dependency for protected routes.
    
    Example:
        @router.get("/protected")
        async def protected_route(user: AuthenticatedUser = Depends(require_auth)):
            return {"message": f"Hello {user.name}"}
    """
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def require_groups(required_groups: list[str]):
    """
    Factory for creating a dependency that requires specific groups.
    
    Example:
        @router.get("/admin")
        async def admin_route(user: AuthenticatedUser = Depends(require_groups(["admin"]))):
            return {"message": "Welcome admin"}
    """
    async def check_groups(
        user: Annotated[AuthenticatedUser, Depends(require_auth)]
    ) -> AuthenticatedUser:
        user_groups = set(user.groups)
        required = set(required_groups)
        
        if not user_groups.intersection(required):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of groups: {required_groups}",
            )
        return user
    
    return check_groups


# Convenience type aliases
CurrentUser = Annotated[AuthenticatedUser, Depends(require_auth)]
OptionalUser = Annotated[Optional[AuthenticatedUser], Depends(get_current_user)]
