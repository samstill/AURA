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
    # Override in .env: GOOGLE_API_KEY, GEMINI_FAST_MODEL, GEMINI_SMART_MODEL, EMBEDDING_MODEL
    # -------------------------------------------------------------------------
    google_api_key: Optional[str] = None
    gemini_fast_model: str = "gemini-2.0-flash"           # Latest Flash model
    gemini_smart_model: str = "gemini-2.0-flash-thinking-exp"  # Smart/reasoning model
    embedding_model: str = "text-embedding-004"           # Latest embedding model
    
    
    # -------------------------------------------------------------------------
    # Multi-Provider Configuration (Groq & OpenRouter)
    # Override in .env: GROQ_API_KEY, GROQ_FAST_MODEL, GROQ_SMART_MODEL, etc.
    # -------------------------------------------------------------------------
    groq_api_key: Optional[str] = None
    groq_fast_model: str = "llama-3.3-70b-versatile"      # Latest Groq Llama
    groq_smart_model: str = "llama-3.3-70b-versatile"     # Best for complex tasks
    
    openrouter_api_key: Optional[str] = None
    openrouter_fast_model: str = "meta-llama/llama-3.3-70b-instruct"
    openrouter_smart_model: str = "deepseek/deepseek-r1"  # Reasoning model
    
    # -------------------------------------------------------------------------
    # OpenAI Configuration (Native API - best tool calling)
    # Override in .env: OPENAI_API_KEY, OPENAI_FAST_MODEL, OPENAI_SMART_MODEL, STALLER_MODEL
    # -------------------------------------------------------------------------
    openai_fast_model: str = "gpt-4.1-mini"               # Latest fast model
    openai_smart_model: str = "gpt-4.1"                   # Latest smart model
    staller_model: str = "gpt-4.1-nano"                   # Ultra-fast for staller
    
    # -------------------------------------------------------------------------
    # DeepSeek Configuration (Native API)
    # Override in .env: DEEPSEEK_API_KEY, DEEPSEEK_MODEL
    # -------------------------------------------------------------------------
    deepseek_api_key: Optional[str] = None
    deepseek_model: str = "deepseek-chat"                 # DeepSeek V3
    
    # -------------------------------------------------------------------------
    # Agent Autonomy Configuration
    # -------------------------------------------------------------------------
    # full = act until goal achieved, no confirmations
    # half = auto for safe actions, ask before delete/bulk (default)
    # minimal = ask before every write action
    agent_autonomy: str = "full"
    agent_max_iterations: int = 10  # max tool call turns per request
    
    # -------------------------------------------------------------------------
    # Aura Routing Algorithm Configuration
    # -------------------------------------------------------------------------
    # Hard timeout before checking agent status (seconds)
    aura_hard_timeout: float = 1.0
    # Extra grace period if agent has started generating (seconds)
    aura_grace_period: float = 0.5
    # Maximum background processing time before giving up (seconds)
    aura_max_async_wait: float = 30.0
    # Semantic cache TTL in seconds
    aura_cache_ttl: int = 3600
    # Minimum similarity score for cache hit (0.0 - 1.0)
    aura_cache_similarity_threshold: float = 0.95
    
    # -------------------------------------------------------------------------
    # Integrations (OAuth credentials)
    # -------------------------------------------------------------------------
    github_client_id: Optional[str] = "Ov23li9L5k6tqPjRk70h"
    github_client_secret: Optional[str] = None
    
    # -------------------------------------------------------------------------
    # Google Calendar OAuth
    # -------------------------------------------------------------------------
    google_calendar_client_id: Optional[str] = None
    google_calendar_client_secret: Optional[str] = None
    google_calendar_scopes: str = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.email"
    
    @property
    def google_calendar_redirect_uri(self) -> str:
        return f"{self.base_url}/api/v1/calendar/callback/google"
    
    # -------------------------------------------------------------------------
    # TTS (ElevenLabs)
    # -------------------------------------------------------------------------
    elevenlabs_api_key: Optional[str] = None
    elevenlabs_voice_id: Optional[str] = None
    elevenlabs_model: str = "eleven_turbo_v2_5"
    tts_mock: bool = False
    
    # -------------------------------------------------------------------------
    # XTTS Remote Worker (Colab GPU or K8s Cluster)
    # -------------------------------------------------------------------------
    # Mode: DEV = Colab ngrok tunnels, PROD = K8s internal DNS
    aura_env: str = "DEV"
    
    # Fish Audio Cloud API (preferred TTS provider)
    fish_audio_api_key: Optional[str] = None
    fish_audio_voice_id: str = "bf322df2096a46f18c579d0baa36f41d"  # Default: Adrian voice
    
    # Remote worker URLs (populated via env vars in DEV mode)
    tts_worker_url: Optional[str] = None      # XTTS-v2 synthesis worker
    voice_worker_url: Optional[str] = None    # TitaNet voice auth worker
    
    @property
    def tts_synthesis_url(self) -> str:
        """Get TTS synthesis endpoint URL based on environment."""
        if self.aura_env == "PROD":
            return "http://xtts-service.default.svc.cluster.local:8000"
        return self.tts_worker_url
    
    @property
    def voice_security_url(self) -> str:
        """Get voice security endpoint URL based on environment."""
        if self.aura_env == "PROD":
            return "http://titanet-service.default.svc.cluster.local:8000"
        return self.voice_worker_url
    
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
