#!/bin/bash
# =============================================================================
# AURA Development Startup Script
# =============================================================================
# Usage: ./dev.sh [OPTIONS]
#   --with-authentik    Start Authentik IDP in dev mode (connects to Supabase)
#   --authentik-only    Start only Authentik services
#   --help              Show this help message
# =============================================================================

set -e

# Configuration
PORT_BACKEND=30000
PORT_MCP=8000
PORT_AUTHENTIK=9000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
WITH_AUTHENTIK=false
AUTHENTIK_ONLY=false

for arg in "$@"; do
    case $arg in
        --with-authentik)
            WITH_AUTHENTIK=true
            shift
            ;;
        --authentik-only)
            AUTHENTIK_ONLY=true
            WITH_AUTHENTIK=true
            shift
            ;;
        --help)
            echo "Usage: ./dev.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-authentik    Start Authentik IDP in dev mode (connects to Supabase)"
            echo "  --authentik-only    Start only Authentik services"
            echo "  --help              Show this help message"
            echo ""
            echo "Environment Variables for Authentik:"
            echo "  AUTHENTIK_DATABASE_URL   PostgreSQL connection URL"
            echo "                           Format: postgresql://user:password@host:port/dbname"
            echo "  AUTHENTIK_SECRET_KEY     Secret key for Authentik (auto-generated if not set)"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ⚡ AURA Development Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create logs directory if it doesn't exist
mkdir -p logs

# Load .env file if it exists
if [ -f ".env" ]; then
    set -a  # Export all variables
    source .env
    set +a
fi

# -----------------------------------------------------------------------------
# Parse AUTHENTIK_DATABASE_URL into components
# Format: postgresql://user:password@host:port/dbname
# -----------------------------------------------------------------------------
parse_database_url() {
    local url="$1"
    
    # Remove postgresql:// prefix
    local rest="${url#postgresql://}"
    
    # Extract user:password@host:port/dbname
    # Split on @ to get credentials and host parts
    local credentials="${rest%%@*}"
    local hostpart="${rest#*@}"
    
    # Extract user and password
    export AUTHENTIK_DB_USER="${credentials%%:*}"
    export AUTHENTIK_DB_PASSWORD="${credentials#*:}"
    
    # Extract host:port/dbname
    local hostport="${hostpart%%/*}"
    export AUTHENTIK_DB_NAME="${hostpart#*/}"
    
    # Extract host and port
    if [[ "$hostport" == *":"* ]]; then
        export AUTHENTIK_DB_HOST="${hostport%%:*}"
        export AUTHENTIK_DB_PORT="${hostport#*:}"
    else
        export AUTHENTIK_DB_HOST="$hostport"
        export AUTHENTIK_DB_PORT="5432"
    fi
    
    # Remove any query parameters from DB name
    export AUTHENTIK_DB_NAME="${AUTHENTIK_DB_NAME%%\?*}"
}

# -----------------------------------------------------------------------------
# Authentik Dev Mode
# -----------------------------------------------------------------------------
start_authentik() {
    echo -e "${YELLOW}[AUTHENTIK]${NC} Starting Authentik IDP..."
    
    # Generate secret key if not set
    if [ -z "$AUTHENTIK_SECRET_KEY" ]; then
        echo -e "       Generating AUTHENTIK_SECRET_KEY..."
        export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
        echo "AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY" >> .env
        echo -e "       ${GREEN}Secret key saved to .env${NC}"
    fi
    
    # Start Authentik services with local PostgreSQL
    echo -e "       Starting containers (PostgreSQL + Redis + Authentik)..."
    if command -v docker-compose &> /dev/null; then
        AUTHENTIK_SECRET_KEY="$AUTHENTIK_SECRET_KEY" \
        docker-compose -f docker-compose.authentik.yml pull
        AUTHENTIK_SECRET_KEY="$AUTHENTIK_SECRET_KEY" \
        docker-compose -f docker-compose.authentik.yml up -d > logs/authentik.log 2>&1
    else
        AUTHENTIK_SECRET_KEY="$AUTHENTIK_SECRET_KEY" \
        docker compose -f docker-compose.authentik.yml pull
        AUTHENTIK_SECRET_KEY="$AUTHENTIK_SECRET_KEY" \
        docker compose -f docker-compose.authentik.yml up -d > logs/authentik.log 2>&1
    fi
    
    # Wait for Authentik to be ready
    echo -n "       Waiting for Authentik..."
    for i in {1..60}; do
        if curl -s http://localhost:${PORT_AUTHENTIK}/api/v3/core/workers/ > /dev/null 2>&1; then
            echo -e " ${GREEN}OK!${NC}"
            echo -e "       Access: ${CYAN}http://localhost:${PORT_AUTHENTIK}/if/flow/initial-setup/${NC}"
            AUTHENTIK_READY=true
            break
        fi
        sleep 2
        echo -n "."
    done
    
    if [ "$AUTHENTIK_READY" != "true" ]; then
        echo -e " ${YELLOW}Starting (check logs/authentik.log)${NC}"
        echo -e "       Authentik may take a few minutes on first start."
        echo -e "       Access: ${CYAN}http://localhost:${PORT_AUTHENTIK}${NC}"
    fi
}

stop_authentik() {
    echo -e "${YELLOW}Stopping Authentik...${NC}"
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.authentik.yml down
    else
        docker compose -f docker-compose.authentik.yml down
    fi
}

# If authentik-only mode, just start Authentik and exit
if [ "$AUTHENTIK_ONLY" = true ]; then
    start_authentik
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   🔐 Authentik is running!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   Admin:  ${CYAN}http://localhost:${PORT_AUTHENTIK}/if/admin/${NC}"
    echo -e "   Setup:  ${CYAN}http://localhost:${PORT_AUTHENTIK}/if/flow/initial-setup/${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop Authentik${NC}"
    
    # Trap for cleanup
    trap "stop_authentik; exit 0" SIGINT
    
    # Stream Authentik logs
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.authentik.yml logs -f
    else
        docker compose -f docker-compose.authentik.yml logs -f
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# 1. Database (Docker or Supabase Cloud)
# -----------------------------------------------------------------------------
# Check if using Supabase Cloud (URL contains supabase.co)
if [[ "$DATABASE_URL" == *"supabase.co"* ]]; then
    echo -e "${YELLOW}[1/6]${NC} Database: ${GREEN}Supabase Cloud${NC} (skipping Docker)"
    DB_READY=true
else
    echo -e "${YELLOW}[1/6]${NC} Starting Local Database..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d postgres > logs/docker.log 2>&1
    else
        docker compose up -d postgres > logs/docker.log 2>&1
    fi

    # Wait for DB
    echo -n "       Waiting for Postgres..."
    for i in {1..30}; do
        if docker exec aura-postgres pg_isready -U postgres > /dev/null 2>&1; then
            echo -e " ${GREEN}OK!${NC}"
            DB_READY=true
            break
        fi
        sleep 1
        echo -n "."
    done

    if [ "$DB_READY" != "true" ]; then
        echo -e " ${RED}Failed!${NC}"
        echo -e "${RED}Check logs/docker.log${NC}"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# 2. Environment Setup
# -----------------------------------------------------------------------------
# Activate virtual environment
if [ -d ".venv" ]; then
    echo -e "${YELLOW}[2/6]${NC} Activating virtual environment..."
    source .venv/bin/activate
else
    echo -e "${RED}Error: .venv directory not found! Run 'python3 -m venv .venv && source .venv/bin/activate && pip install -r src/requirements.txt' first.${NC}"
    exit 1
fi

# TTS Configuration (ElevenLabs API)
if [ -n "$ELEVENLABS_API_KEY" ]; then
    echo -e "       TTS: ${GREEN}ElevenLabs API${NC}"
else
    export TTS_MOCK="true"
    echo -e "       TTS: ${YELLOW}Mock Mode${NC} (set ELEVENLABS_API_KEY for real audio)"
fi

# Kill existing processes
echo -e "${YELLOW}[3/6]${NC} Cleaning up old processes..."
pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "mcp_server.main" 2>/dev/null || true
# Try killall for safety
killall uvicorn 2>/dev/null || true
killall python3 2>/dev/null || true # Be careful with this on shared systems, but safe for this dedicated env

# Kill processes on ports if any are lingering
fuser -k ${PORT_MCP}/tcp 2>/dev/null || true
fuser -k ${PORT_BACKEND}/tcp 2>/dev/null || true
sleep 2

# Check if ports are still in use
if ss -tln | grep -q ":${PORT_BACKEND} "; then
    echo -e "${RED}Error: Port ${PORT_BACKEND} is still in use!${NC}"
    echo -e "${YELLOW}A process (likely running as root) is holding the port.${NC}"
    echo -e "${YELLOW}Please run this command to force kill it:${NC}"
    echo -e "    ${RED}sudo fuser -k ${PORT_BACKEND}/tcp${NC}"
    echo -e "${YELLOW}Then run ./dev.sh again.${NC}"
    exit 1
fi

if ss -tln | grep -q ":${PORT_MCP} "; then
     # Try one last time for MCP port which is less likely to be root
     fuser -k ${PORT_MCP}/tcp 2>/dev/null || true
     sleep 1
     if ss -tln | grep -q ":${PORT_MCP} "; then
        echo -e "${RED}Error: Port ${PORT_MCP} is in use.${NC}"
        echo -e "${YELLOW}Please free port ${PORT_MCP} manually.${NC}"
        exit 1
     fi
fi

# -----------------------------------------------------------------------------
# 3. Start Authentik (if requested)
# -----------------------------------------------------------------------------
if [ "$WITH_AUTHENTIK" = true ]; then
    start_authentik
fi

# Start MCP Server
echo -e "${YELLOW}[4/6]${NC} Starting MCP Server on port ${PORT_MCP}..."
cd src
nohup python3 -m mcp_server.main > ../logs/mcp.log 2>&1 &
MCP_PID=$!
cd ..

# Wait for MCP to start
echo -n "       Waiting for MCP..."
for i in {1..10}; do
    if curl -s http://localhost:${PORT_MCP}/health > /dev/null 2>&1; then
        echo -e " ${GREEN}OK!${NC} (PID: $MCP_PID)"
        MCP_READY=true
        break
    fi
    sleep 1
    echo -n "."
done

if [ "$MCP_READY" != "true" ]; then
    echo -e " ${RED}Failed!${NC}"
    echo -e "${RED}Check logs/mcp.log for details:${NC}"
    tail -n 10 logs/mcp.log
    exit 1
fi

# Start Main Backend with verbose logging
echo -e "${YELLOW}[5/6]${NC} Starting Main Backend on port ${PORT_BACKEND}..."
cd src
nohup uvicorn main:app --reload --host 0.0.0.0 --port ${PORT_BACKEND} --log-level debug > ../logs/backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo -n "       Waiting for Backend..."
for i in {1..15}; do
    if curl -s http://localhost:${PORT_BACKEND}/health > /dev/null 2>&1; then
        echo -e " ${GREEN}OK!${NC} (PID: $BACKEND_PID)"
        BACKEND_READY=true
        break
    fi
    sleep 1
    echo -n "."
done

if [ "$BACKEND_READY" != "true" ]; then
    echo -e " ${RED}Failed!${NC}"
    echo -e "${RED}Check logs/backend.log for details:${NC}"
    tail -n 10 logs/backend.log
    exit 1
fi

# -----------------------------------------------------------------------------
# 6. Log Streaming & Cleanup
# -----------------------------------------------------------------------------

# Function to kill processes on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 Stopping services...${NC}"
    kill $MCP_PID 2>/dev/null || true
    kill $BACKEND_PID 2>/dev/null || true
    # Also kill any other instances
    pkill -P $$ 2>/dev/null || true
    
    # Stop Authentik if it was started
    if [ "$WITH_AUTHENTIK" = true ]; then
        stop_authentik
    fi
    
    echo -e "${GREEN}Services stopped.${NC}"
    exit 0
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   🚀 AURA is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   Backend: ${BLUE}http://localhost:${PORT_BACKEND}/admin_console.html${NC}"
if [ "$WITH_AUTHENTIK" = true ]; then
    echo -e "   Authentik: ${CYAN}http://localhost:${PORT_AUTHENTIK}/if/admin/${NC}"
fi
echo ""
echo -e "${YELLOW}[6/6]${NC} Streaming logs (Press Ctrl+C to stop)..."
echo -e "      (backend.log, mcp.log)"
echo ""

# Stream logs
tail -f logs/backend.log logs/mcp.log
