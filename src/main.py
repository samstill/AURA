"""
Project Aura - FastAPI Backend Entry Point
==========================================

The AI Secretary backend service with:
- Health check endpoints for K8s probes
- CORS configuration for Flutter clients
- Modular router architecture
- Authentik IDP integration
"""

import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import chat, voice, auth
from services.authentik_service import authentik_service
from services.llm_service import llm_service
from services.router_service import router_service
from services.database_service import database_service

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    
    Startup: Initialize connections to external services.
    Shutdown: Clean up resources gracefully.
    """
    # Startup
    logger.info("🚀 Project Aura starting up...")
    logger.info(f"   Environment: {settings.environment}")
    logger.info(f"   Debug: {settings.debug}")
    
    # Initialize Authentik service
    try:
        await authentik_service.initialize()
        logger.info("✅ Authentik service initialized")
    except Exception as e:
        logger.warning(f"⚠️  Authentik initialization warning: {e}")
    
    # Initialize Router Service (sentence-transformers)
    try:
        router_service.initialize()
        logger.info("✅ Router service initialized")
    except Exception as e:
        logger.warning(f"⚠️  Router initialization warning: {e}")
    
    # Initialize LLM Service (Gemini)
    try:
        llm_service.initialize()
        logger.info("✅ LLM service initialized")
    except Exception as e:
        logger.warning(f"⚠️  LLM initialization warning: {e}")

    # Initialize Database Service
    try:
        await database_service.connect()
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
    
    # TODO: Initialize other services
    # - Database pool
    # - Redis client
    # - Qdrant client
    
    yield
    
    # Shutdown
    logger.info("🛑 Project Aura shutting down...")
    await database_service.disconnect()


app = FastAPI(
    title="Project Aura",
    description="The World's Fastest AI Secretary",
    version="0.1.0",
    lifespan=lifespan,
)

# -----------------------------------------------------------------------------
# CORS Configuration
# -----------------------------------------------------------------------------
# Allow Flutter clients from various origins during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",      # Web dev server
        "http://localhost:8080",      # Alternative web port
        "http://localhost:9000",      # Authentik
        "http://10.0.2.2:30000",      # Android emulator
        "*",                          # TODO: Restrict in production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Aura-Route"],
)

# -----------------------------------------------------------------------------
# Health Endpoints (Kubernetes Probes)
# -----------------------------------------------------------------------------
@app.get("/health", tags=["System"])
async def health_check():
    """
    Liveness probe for Kubernetes.
    Returns 200 if the service is running.
    """
    return {"status": "ok", "service": "aura-backend"}


@app.get("/ready", tags=["System"])
async def readiness_check():
    """
    Readiness probe for Kubernetes.
    Returns 200 if the service is ready to accept traffic.
    
    Checks:
    - Authentik IDP connectivity
    - Database connectivity (TODO)
    - Redis connectivity (TODO)
    """
    checks = {}
    overall_status = "ready"
    
    # Check Authentik
    try:
        authentik_health = await authentik_service.health_check()
        checks["authentik"] = authentik_health.get("status", "unknown")
        if checks["authentik"] != "ok":
            overall_status = "degraded"
    except Exception as e:
        checks["authentik"] = "error"
        checks["authentik_error"] = str(e)
        overall_status = "degraded"
    
    # TODO: Add other checks
    checks["database"] = "ok"  # TODO: Implement actual check
    checks["redis"] = "ok"     # TODO: Implement actual check
    
    return {
        "status": overall_status,
        "checks": checks
    }


@app.get("/", tags=["System"])
async def root():
    """API root - basic info endpoint."""
    return {
        "service": "Project Aura",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/health",
        "auth": "/api/v1/auth/status",
    }


# -----------------------------------------------------------------------------
# Register Routers
# -----------------------------------------------------------------------------
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(voice.router, prefix="/api/v1/voice", tags=["Voice"])

# Late import to avoid circular dependencies if any
from routers import tools
app.include_router(tools.router, prefix="/api/v1", tags=["Tools"])

