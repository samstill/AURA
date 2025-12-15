from fastapi import FastAPI, Body, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
import datetime
import uvicorn
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mcp-basic")

app = FastAPI()

# -----------------------------------------------------------------------------
# MCP Models
# -----------------------------------------------------------------------------
class JsonRpcRequest(BaseModel):
    jsonrpc: str
    method: str
    params: Dict[str, Any]
    id: int

# -----------------------------------------------------------------------------
# Tool Definitions
# -----------------------------------------------------------------------------
TOOLS = [
    {
        "name": "get_current_time",
        "description": "Get the current time in a specific timezone.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "timezone": {"type": "string", "description": "Timezone (e.g. 'UTC', 'US/Pacific')"}
            },
            "required": []
        }
    },
    {
        "name": "calculate_sum",
        "description": "Add two numbers together.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {"type": "number"},
                "b": {"type": "number"}
            },
            "required": ["a", "b"]
        }
    }
]

# -----------------------------------------------------------------------------
# Tool Implementations
# -----------------------------------------------------------------------------
def get_current_time(timezone: str = "UTC") -> str:
    # Simplified: always UTC for demo
    now = datetime.datetime.utcnow().isoformat()
    return f"Current time ({timezone}): {now}"

def calculate_sum(a: float, b: float) -> str:
    return str(a + b)

# -----------------------------------------------------------------------------
# MCP Endpoint
# -----------------------------------------------------------------------------
@app.post("/mcp")
async def handle_mcp(request: JsonRpcRequest):
    logger.info(f"MCP Request: {request.method}")
    
    if request.method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "result": {
                "tools": TOOLS
            }
        }
    
    elif request.method == "tools/call":
        params = request.params
        name = params.get("name")
        args = params.get("arguments", {})
        
        result_text = ""
        
        if name == "get_current_time":
            result_text = get_current_time(args.get("timezone", "UTC"))
            
        elif name == "calculate_sum":
            try:
                val = calculate_sum(float(args.get("a", 0)), float(args.get("b", 0)))
                result_text = val
            except Exception as e:
                result_text = f"Error: {e}"
        else:
            return {
                "jsonrpc": "2.0",
                "id": request.id,
                "error": {"code": -32601, "message": "Method not found"}
            }
            
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": result_text
                    }
                ]
            }
        }

    else:
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "error": {"code": -32601, "message": "Method not found"}
        }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
