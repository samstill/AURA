"""
Project Aura - Configuration
============================

Pydantic settings for environment-based configuration.
All sensitive values are loaded from Kubernetes secrets.
"""

from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    In Kubernetes, these are injected from the 'aura-secrets' Secret.
    For local development without K8s, create a .env file (NOT committed to Git).
    """
    
    # -------------------------------------------------------------------------
    # Application
    # -------------------------------------------------------------------------
    environment: str = "development"
    debug: bool = True
    log_level: str = "INFO"
    
    # Base URL for this service (used for OAuth redirects)
    base_url: str = "http://localhost:30000"
    
    # -------------------------------------------------------------------------
    # Authentik IDP (OAuth2/OIDC)
    # -------------------------------------------------------------------------
    # Browser-facing URL (for redirects - user's browser must reach this)
    authentik_url: str = "http://localhost:30080"
    
    # Internal URL (for server-to-server communication inside K8s cluster)
    authentik_internal_url: str = "http://authentik.aura-auth.svc.cluster.local"
    
    authentik_client_id: str = ""
    authentik_client_secret: str = ""
    
    # OIDC endpoints - browser-facing (redirects go through user's browser)
    @property
    def authentik_authorization_url(self) -> str:
        return f"{self.authentik_url}/application/o/authorize/"
    
    @property
    def authentik_logout_url(self) -> str:
        return f"{self.authentik_url}/application/o/aura/end-session/"
    
    # OIDC endpoints - internal (server-to-server, backend calls Authentik directly)
    @property
    def authentik_token_url(self) -> str:
        return f"{self.authentik_internal_url}/application/o/token/"
    
    @property
    def authentik_userinfo_url(self) -> str:
        return f"{self.authentik_internal_url}/application/o/userinfo/"
    
    @property
    def authentik_jwks_url(self) -> str:
        return f"{self.authentik_internal_url}/application/o/aura/jwks/"
    
    @property
    def authentik_redirect_uri(self) -> str:
        return f"{self.base_url}/api/v1/auth/callback"
    
    # OAuth2 scopes to request
    authentik_scopes: str = "openid profile email"

    
    # -------------------------------------------------------------------------
    # Session & JWT
    # -------------------------------------------------------------------------
    # Secret key for signing session cookies (generate with: openssl rand -hex 32)
    secret_key: str = "CHANGE_ME_IN_PRODUCTION_USE_OPENSSL_RAND_HEX_32"
    
    # JWT algorithm and expiration
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7
    
    # -------------------------------------------------------------------------
    # External Services (existing)
    # -------------------------------------------------------------------------
    database_url: Optional[str] = None
    redis_url: Optional[str] = None
    qdrant_url: Optional[str] = None
    qdrant_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    
    # -------------------------------------------------------------------------
    # Google Gemini Configuration
    # -------------------------------------------------------------------------
    google_api_key: Optional[str] = None
    gemini_fast_model: str = "models/gemini-2.5-flash"
    gemini_smart_model: str = "models/gemini-2.5-flash"
    
    # -------------------------------------------------------------------------
    # Multi-Provider Configuration (Groq & OpenRouter)
    # -------------------------------------------------------------------------
    groq_api_key: Optional[str] = None
    groq_fast_model: str = "llama-3.1-8b-instant"
    groq_smart_model: str = "llama-3.3-70b-versatile"
    
    openrouter_api_key: Optional[str] = None
    openrouter_fast_model: str = "meta-llama/llama-3-8b-instruct:free"
    openrouter_smart_model: str = "deepseek/deepseek-r1"
    
    # -------------------------------------------------------------------------
    # Integrations (OAuth credentials)
    # -------------------------------------------------------------------------
    github_client_id: Optional[str] = "Ov23li9L5k6tqPjRk70h"
    github_client_secret: Optional[str] = None
    
    # -------------------------------------------------------------------------
    # TTS (ElevenLabs)
    # -------------------------------------------------------------------------
    elevenlabs_api_key: Optional[str] = None
    elevenlabs_voice_id: Optional[str] = None
    elevenlabs_model: str = "eleven_turbo_v2_5"
    tts_mock: bool = False
    
    class Config:
        env_file = "../.env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance.
    
    Using lru_cache ensures settings are loaded once and reused.
    """
    return Settings()


# Convenience export
settings = get_settings()
