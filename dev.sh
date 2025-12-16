#!/bin/bash
# =============================================================================
# AURA Development Startup Script
# =============================================================================
# Usage: ./dev.sh
# This script starts both the MCP server and the main backend for development.
# =============================================================================

set -e

# Configuration
PORT_BACKEND=30000
PORT_MCP=8000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ⚡ AURA Development Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create logs directory if it doesn't exist
mkdir -p logs

# -----------------------------------------------------------------------------
# 1. Database (Docker)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/6]${NC} Starting Database..."
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

# TTS Configuration (Mock mode for local dev - no GPU required)
export TTS_MOCK="true"
export TTS_URL="http://localhost:5002/api/tts"  # Not used when TTS_MOCK=true
echo -e "       TTS: ${GREEN}Mock Mode${NC} (no GPU required)"


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

# Start Main Backend
echo -e "${YELLOW}[5/6]${NC} Starting Main Backend on port ${PORT_BACKEND}..."
cd src
nohup uvicorn main:app --reload --host 0.0.0.0 --port ${PORT_BACKEND} > ../logs/backend.log 2>&1 &
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
    echo -e "${GREEN}Services stopped.${NC}"
    exit 0
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   🚀 AURA is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   Access: ${BLUE}http://localhost:${PORT_BACKEND}/admin_console.html${NC}"
echo ""
echo -e "${YELLOW}[6/6]${NC} Streaming logs (Press Ctrl+C to stop)..."
echo -e "      (backend.log, mcp.log)"
echo ""

# Stream logs
tail -f logs/backend.log logs/mcp.log
