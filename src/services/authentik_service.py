"""
Authentik Service
=================

OAuth2/OIDC client for Authentik Identity Provider.
Handles token exchange, validation, and user info retrieval.
"""

import time
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass
import httpx
from authlib.integrations.httpx_client import AsyncOAuth2Client
from authlib.jose import jwt, JsonWebKey
from authlib.jose.errors import JoseError

from config import settings

logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Custom Exceptions
# -----------------------------------------------------------------------------
class AuthentikError(Exception):
    """Base exception for Authentik-related errors."""
    pass


class TokenExchangeError(AuthentikError):
    """Failed to exchange authorization code for tokens."""
    pass


class TokenValidationError(AuthentikError):
    """Token validation failed."""
    pass


class UserInfoError(AuthentikError):
    """Failed to fetch user info."""
    pass


class AuthentikUnavailableError(AuthentikError):
    """Authentik service is unavailable."""
    pass


# -----------------------------------------------------------------------------
# Data Models
# -----------------------------------------------------------------------------
@dataclass
class AuthenticatedUser:
    """Represents an authenticated user from Authentik."""
    sub: str  # Subject (unique user ID in Authentik)
    email: str
    email_verified: bool
    name: str
    preferred_username: str
    groups: list[str]
    raw_claims: Dict[str, Any]


# -----------------------------------------------------------------------------
# Service
# -----------------------------------------------------------------------------
class AuthentikService:
    """
    OIDC client for Authentik.
    
    Implements:
    - Authorization URL generation
    - Token exchange (auth code -> tokens)
    - Token validation (JWT verification)
    - User info retrieval
    - Token refresh
    - Logout (token revocation)
    - Health checking
    """
    
    # HTTP request timeout (seconds)
    TIMEOUT = 10.0
    
    def __init__(self):
        self._jwks_cache: Optional[JsonWebKey] = None
        self._jwks_cache_time: float = 0
        self._jwks_cache_ttl: int = 3600  # Cache JWKS for 1 hour
        self._initialized: bool = False
    
    async def initialize(self):
        """
        Initialize the service.
        Called during application startup.
        """
        logger.info("Initializing Authentik service...")
        logger.info(f"  Authorization URL: {settings.authentik_authorization_url}")
        logger.info(f"  Token URL: {settings.authentik_token_url}")
        logger.info(f"  Client ID configured: {bool(settings.authentik_client_id)}")
        
        # Pre-fetch JWKS for faster token validation
        try:
            await self._get_jwks()
            logger.info("  JWKS pre-fetched successfully")
        except Exception as e:
            logger.warning(f"  Could not pre-fetch JWKS: {e}")
        
        self._initialized = True
        logger.info("Authentik service initialized")
    
    async def health_check(self) -> Dict[str, Any]:
        """
        Check if Authentik is reachable and responding.
        
        Returns:
            Dict with status and optional error message
        """
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                # Try to reach the OIDC discovery endpoint
                response = await client.get(
                    f"{settings.authentik_internal_url}/.well-known/openid-configuration"
                )
                if response.status_code == 200:
                    return {"status": "ok", "reachable": True}
                else:
                    return {
                        "status": "degraded",
                        "reachable": True,
                        "http_status": response.status_code
                    }
        except httpx.TimeoutException:
            return {"status": "error", "reachable": False, "error": "timeout"}
        except httpx.ConnectError:
            return {"status": "error", "reachable": False, "error": "connection_refused"}
        except Exception as e:
            return {"status": "error", "reachable": False, "error": str(e)}
    
    def create_oauth_client(self) -> AsyncOAuth2Client:
        """Create an OAuth2 client configured for Authentik."""
        return AsyncOAuth2Client(
            client_id=settings.authentik_client_id,
            client_secret=settings.authentik_client_secret,
            redirect_uri=settings.authentik_redirect_uri,
            scope=settings.authentik_scopes,
        )
    
    def get_authorization_url(self, state: str) -> str:
        """
        Generate the authorization URL for redirecting users to Authentik.
        
        Args:
            state: CSRF protection token (should be stored in session)
            
        Returns:
            Full authorization URL with all parameters
        """
        client = self.create_oauth_client()
        url, _ = client.create_authorization_url(
            settings.authentik_authorization_url,
            state=state,
        )
        return url
    
    async def exchange_code_for_tokens(self, code: str) -> Dict[str, Any]:
        """
        Exchange authorization code for access and ID tokens.
        
        Args:
            code: The authorization code from Authentik callback
            
        Returns:
            Token response containing access_token, id_token, refresh_token, etc.
            
        Raises:
            TokenExchangeError: If the exchange fails
        """
        try:
            async with AsyncOAuth2Client(
                client_id=settings.authentik_client_id,
                client_secret=settings.authentik_client_secret,
                timeout=self.TIMEOUT,
            ) as client:
                token = await client.fetch_token(
                    settings.authentik_token_url,
                    code=code,
                    redirect_uri=settings.authentik_redirect_uri,
                )
                logger.info("Successfully exchanged authorization code for tokens")
                return dict(token)
        except httpx.TimeoutException as e:
            logger.error(f"Token exchange timeout: {e}")
            raise TokenExchangeError("Token exchange timed out") from e
        except httpx.ConnectError as e:
            logger.error(f"Token exchange connection error: {e}")
            raise TokenExchangeError("Could not connect to Authentik") from e
        except Exception as e:
            logger.error(f"Token exchange failed: {e}")
            raise TokenExchangeError(f"Token exchange failed: {str(e)}") from e
    
    async def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh an expired access token.
        
        Args:
            refresh_token: The refresh token from initial auth
            
        Returns:
            New token response
            
        Raises:
            TokenExchangeError: If refresh fails
        """
        try:
            async with AsyncOAuth2Client(
                client_id=settings.authentik_client_id,
                client_secret=settings.authentik_client_secret,
                timeout=self.TIMEOUT,
            ) as client:
                token = await client.refresh_token(
                    settings.authentik_token_url,
                    refresh_token=refresh_token,
                )
                logger.info("Successfully refreshed access token")
                return dict(token)
        except Exception as e:
            logger.error(f"Token refresh failed: {e}")
            raise TokenExchangeError(f"Token refresh failed: {str(e)}") from e
    
    async def get_user_info(self, access_token: str) -> AuthenticatedUser:
        """
        Fetch user information from Authentik userinfo endpoint.
        
        Args:
            access_token: Valid access token
            
        Returns:
            AuthenticatedUser with profile information
            
        Raises:
            UserInfoError: If fetch fails
        """
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                response = await client.get(
                    settings.authentik_userinfo_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                response.raise_for_status()
                claims = response.json()
            
            return AuthenticatedUser(
                sub=claims.get("sub", ""),
                email=claims.get("email", ""),
                email_verified=claims.get("email_verified", False),
                name=claims.get("name", claims.get("preferred_username", "")),
                preferred_username=claims.get("preferred_username", ""),
                groups=claims.get("groups", []),
                raw_claims=claims,
            )
        except httpx.HTTPStatusError as e:
            logger.error(f"User info request failed with status {e.response.status_code}")
            raise UserInfoError(f"Failed to fetch user info: HTTP {e.response.status_code}") from e
        except Exception as e:
            logger.error(f"User info request failed: {e}")
            raise UserInfoError(f"Failed to fetch user info: {str(e)}") from e
    
    async def _get_jwks(self) -> JsonWebKey:
        """
        Fetch and cache JWKS (JSON Web Key Set) from Authentik.
        
        The JWKS contains the public keys used to verify JWT signatures.
        """
        now = time.time()
        
        # Return cached JWKS if still valid
        if self._jwks_cache and (now - self._jwks_cache_time) < self._jwks_cache_ttl:
            return self._jwks_cache
        
        # Fetch fresh JWKS
        async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
            response = await client.get(settings.authentik_jwks_url)
            response.raise_for_status()
            jwks_data = response.json()
        
        self._jwks_cache = JsonWebKey.import_key_set(jwks_data)
        self._jwks_cache_time = now
        
        return self._jwks_cache
    
    async def validate_id_token(self, id_token: str) -> Dict[str, Any]:
        """
        Validate and decode an ID token.
        
        Args:
            id_token: The ID token JWT
            
        Returns:
            Decoded claims if valid
            
        Raises:
            TokenValidationError: If token is invalid
        """
        try:
            jwks = await self._get_jwks()
            
            claims = jwt.decode(
                id_token,
                jwks,
                claims_options={
                    "iss": {"essential": True, "value": settings.authentik_url},
                    "aud": {"essential": True, "value": settings.authentik_client_id},
                },
            )
            claims.validate()
            
            return dict(claims)
        except JoseError as e:
            logger.error(f"ID token validation failed: {e}")
            raise TokenValidationError(f"Invalid ID token: {str(e)}") from e
    
    async def validate_access_token(self, access_token: str) -> Optional[Dict[str, Any]]:
        """
        Validate an access token by introspecting it or checking userinfo.
        
        For Authentik, we use the userinfo endpoint to validate access tokens.
        
        Returns:
            User claims if valid, None otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=self.TIMEOUT) as client:
                response = await client.get(
                    settings.authentik_userinfo_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if response.status_code == 200:
                    return response.json()
                return None
        except Exception:
            return None
    
    def get_logout_url(self, id_token: str, post_logout_redirect: Optional[str] = None) -> str:
        """
        Generate the logout URL for ending the Authentik session.
        
        Args:
            id_token: The ID token to invalidate
            post_logout_redirect: URL to redirect after logout
            
        Returns:
            Logout URL
        """
        url = settings.authentik_logout_url
        params = [f"id_token_hint={id_token}"]
        
        if post_logout_redirect:
            params.append(f"post_logout_redirect_uri={post_logout_redirect}")
        
        return f"{url}?{'&'.join(params)}"


# Singleton instance
authentik_service = AuthentikService()
