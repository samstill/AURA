# =============================================================================
# Project Aura - Multi-Stage Dockerfile
# =============================================================================
# Optimized for:
# - Small final image (<100MB)
# - Fast builds via layer caching
# - Hot-reload support with Skaffold file sync
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder - Install dependencies
# -----------------------------------------------------------------------------
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY src/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# -----------------------------------------------------------------------------
# Stage 2: Runner - Production image
# -----------------------------------------------------------------------------
FROM python:3.11-slim as runner

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Ensure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Copy application source
COPY src/ .

# Create non-root user for security (optional, uncomment for production)
# RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
# USER appuser

# Expose the application port
EXPOSE 8000

# Health check for Docker/K8s
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run with Uvicorn
# --reload is enabled for development (Skaffold file sync)
# Remove --reload for production builds
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
