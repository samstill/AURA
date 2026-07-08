"""
Encresa AURA - FastAPI Backend Entry Point
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
from routers import chat, voice, auth, calendar, memory
from services.authentik_service import authentik_service
from services.llm_service import llm_service
from services.router_service import router_service
from services.database_service import database_service
from services.calendar_db_service import calendar_db_service

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
    logger.info("🚀 Encresa AURA starting up...")
    logger.info(f"   Environment: {settings.environment}")
    logger.info(f"   Debug: {settings.debug}")
    
    # Security check: Warn about insecure secret key in production
    if settings.environment == "production":
        if not settings.validate_secret_key():
            logger.critical("❌ SECURITY WARNING: Using insecure default SECRET_KEY in production!")
            logger.critical("   Please set a secure SECRET_KEY environment variable.")
            raise RuntimeError("Insecure SECRET_KEY in production environment")
    
    # Initialize Authentik service
    try:
        await authentik_service.initialize()
        logger.info("✅ Authentik service initialized")
    except Exception as e:
        logger.warning(f"⚠️  Authentik initialization warning: {e}")
    
    # Initialize LLM Service first (needed by router and other services)
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
    
    # Initialize Calendar SQLite Database
    try:
        await calendar_db_service.initialize()
        logger.info("✅ Calendar database initialized")
    except Exception as e:
        logger.warning(f"⚠️  Calendar DB initialization warning: {e}")
    
    # Initialize Orchestrator (Aura Algorithm)
    # This initializes sub-services: staller, analyst, semantic cache
    try:
        from services.orchestrator_service import orchestrator_service
        from services.tool_registry import tool_registry
        
        # Initialize router with LLM for dynamic tool detection
        # Use the already-initialized llm_service from module level import
        router_service.initialize(llm_service=llm_service)
        
        # Initialize tool registry
        tool_registry.initialize()
        
        # Initialize orchestrator with database pool for memory service
        await orchestrator_service.initialize(database_service.pool)
        logger.info("✅ Orchestrator service initialized (Aura Algorithm v2 + Super Memory 3.0)")
    except Exception as e:
        logger.warning(f"⚠️  Orchestrator initialization warning: {e}")
    
    yield
    
    # Shutdown
    logger.info("🛑 Encresa AURA shutting down...")
    await database_service.disconnect()


app = FastAPI(
    title="Encresa AURA",
    description="The World's Fastest AI Secretary by Encresa",
    version="0.1.0",
    lifespan=lifespan,
)

# -----------------------------------------------------------------------------
# CORS Configuration
# -----------------------------------------------------------------------------
# Allow Flutter clients from various origins
# In production, only specific origins are allowed
_cors_origins = [
    "http://localhost:3000",      # Web dev server
    "http://localhost:8080",      # Alternative web port
    "http://localhost:9000",      # Authentik
    "http://10.0.2.2:30000",      # Android emulator
]

# Only allow wildcard in development mode
if settings.environment == "development" and settings.debug:
    _cors_origins.append("*")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Requested-With"],
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
        "service": "Encresa AURA",
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
app.include_router(calendar.router, prefix="/api/v1", tags=["Calendar"])
app.include_router(memory.router, prefix="/api/v1/memory", tags=["Memory"])

# Late import to avoid circular dependencies if any
from routers import tools
app.include_router(tools.router, prefix="/api/v1", tags=["Tools"])

