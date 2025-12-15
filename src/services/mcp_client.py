"""
MCP Client
==========

Handles communication with remote Model Context Protocol (MCP) servers
via JSON-RPC 2.0 over HTTP.
"""

import httpx
import logging
import json
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

class RemoteMCPClient:
    """
    Talks to an MCP Server running in a Docker container via HTTP.
    """
    def __init__(self, base_url: str, auth_config: Dict = None):
        """
        Initialize the MCP Client.

        Args:
            base_url: The base URL of the MCP server (e.g., http://mcp-server:8000)
            auth_config: Optional dictionary containing authentication credentials
        """
        self.base_url = base_url.rstrip('/')
        self.auth_config = auth_config or {}

    async def list_tools(self) -> List[Dict]:
        """
        Discovery Phase: Ask the MCP server what it can do.
        Endpoint: POST /mcp (Standard MCP over HTTP)
        
        Returns:
            List of tool definitions in MCP format.
        """
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1,
            "params": {}
        }
        
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                # Note: The endpoint depends on the MCP server implementation.
                # Standard reference implementations might use /mcp or root.
                # We assume /mcp based on the spec provided.
                check_url = f"{self.base_url}/mcp"
                logger.debug(f"Connecting to MCP at {check_url}")
                
                resp = await client.post(check_url, json=payload)
                resp.raise_for_status()
                data = resp.json()
                
                if "error" in data:
                    logger.error(f"MCP List Error from {self.base_url}: {data['error']}")
                    return []
                
                # Extract tools list from MCP response structure
                # Expected response: {"result": {"tools": [...]}}
                result = data.get("result", {})
                return result.get("tools", [])
                
        except httpx.RequestError as e:
            logger.error(f"Failed to connect to MCP at {self.base_url}: {e}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error listing tools from {self.base_url}: {e}")
            return []

    async def call_tool(self, tool_name: str, arguments: Dict) -> str:
        """
        Execution Phase: Run the tool.
        
        Args:
            tool_name: Name of the tool to execute
            arguments: Dictionary of arguments for the tool
            
        Returns:
            String tool output
        """
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": 2,
            "params": {
                "name": tool_name,
                "arguments": arguments,
                "_meta": self.auth_config # Custom meta field for credentials if needed
            }
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(f"{self.base_url}/mcp", json=payload)
                resp.raise_for_status()
                data = resp.json()
                
                if "error" in data:
                    error_msg = data['error'].get('message', 'Unknown error')
                    logger.error(f"Tool execution error ({tool_name}): {error_msg}")
                    return f"Error executing tool: {error_msg}"
                
                # Extract content
                # Expected response: {"result": {"content": [{"type": "text", "text": "..."}]}}
                result = data.get("result", {})
                content_list = result.get("content", [])
                
                # Combine all text blocks
                output_text = []
                for item in content_list:
                    if item.get("type") == "text":
                        output_text.append(item.get("text", ""))
                    elif item.get("type") == "resource":
                        # Handle embedded resources if necessary
                        output_text.append(f"[Resource: {item.get('uri')}]")
                        
                return "\n".join(output_text)

        except Exception as e:
            logger.error(f"Failed to execute tool {tool_name} at {self.base_url}: {e}")
            return f"System Error: Failed to execute tool. {str(e)}"
