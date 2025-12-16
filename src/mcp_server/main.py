"""
Aura MCP Server (v3 - SDK Based)
================================

Industry-grade MCP server with automatic tool discovery.
Tools are registered via the @tool decorator in sdk.py.
"""

import logging
import asyncio
from typing import Dict, Any
from fastapi import FastAPI
from pydantic import BaseModel

# Import tool modules to trigger @tool decorator registration
import mcp_server.tools.github
import mcp_server.tools.web
import mcp_server.tools.utils

# Import SDK functions
from mcp_server.sdk import get_all_tools, execute_tool

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mcp-server")

app = FastAPI(title="Aura MCP Server (v3 - SDK)")


# -----------------------------------------------------------------------------
# JSON-RPC Handling
# -----------------------------------------------------------------------------
class JsonRpcRequest(BaseModel):
    jsonrpc: str
    method: str
    params: Dict[str, Any] = {}
    id: Any


@app.get("/health")
async def health():
    """Health check endpoint."""
    tools = get_all_tools()
    return {"status": "healthy", "tools_count": len(tools)}


@app.post("/mcp")
async def handle_mcp(request: JsonRpcRequest):
    logger.info(f"MCP Request: {request.method} (ID: {request.id})")
    
    if request.method == "tools/list":
        # Get all tools from SDK registry
        all_tools = get_all_tools()
        
        tool_list = []
        for name, tool_def in all_tools.items():
            tool_list.append({
                "name": name,
                "description": tool_def["description"],
                "inputSchema": tool_def["inputSchema"]
            })
        
        logger.info(f"Returning {len(tool_list)} tools")
        
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "result": {
                "tools": tool_list
            }
        }
    
    elif request.method == "tools/call":
        params = request.params
        name = params.get("name")
        args = params.get("arguments", {})
        
        try:
            result = execute_tool(name, args)
            
            return {
                "jsonrpc": "2.0",
                "id": request.id,
                "result": {
                    "content": [{
                        "type": "text",
                        "text": str(result)
                    }]
                }
            }

        except ValueError as e:
            # Tool not found
            return {
                "jsonrpc": "2.0",
                "id": request.id,
                "error": {"code": -32601, "message": str(e)}
            }
        except Exception as e:
            logger.error(f"Execution Error: {e}")
            return {
                "jsonrpc": "2.0",
                "id": request.id,
                "error": {"code": -32603, "message": str(e)}
            }
    
    else:
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "error": {"code": -32601, "message": "Method not found"}
        }


if __name__ == "__main__":
    import uvicorn
    # Log registered tools at startup
    tools = get_all_tools()
    logger.info(f"🚀 Starting MCP Server with {len(tools)} tools: {list(tools.keys())}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
