"""
MCP Client
==========

Handles communication with remote Model Context Protocol (MCP) servers
via JSON-RPC 2.0 over HTTP or SSE.
"""

import httpx
import logging
import json
import asyncio
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

class RemoteMCPClient:
    """
    Talks to an MCP Server via HTTP or SSE.
    """
    def __init__(self, base_url: str, auth_config: Dict = None, transport: str = "http"):
        """
        Initialize the MCP Client.

        Args:
            base_url: The base URL of the MCP server
            auth_config: Optional dictionary containing authentication credentials
            transport: "http" (default) or "sse"
        """
        self.base_url = base_url.rstrip('/')
        self.auth_config = auth_config or {}
        self.transport = transport
        
        # SSE State
        self._sse_task = None
        self._sse_ready = asyncio.Event()
        self._post_endpoint = None
        self._pending_requests: Dict[str, asyncio.Future] = {}
        # We don't keep a persistent client for HTTP requests to avoid event loop issues across re-instantiations
        # but for SSE we need a long-running one.

    async def _ensure_connection(self):
        """Ensure SSE connection is active if transport is SSE."""
        if self.transport != "sse":
            return
            
        if self._sse_task and not self._sse_task.done():
            return

        logger.info(f"Connecting to SSE at {self.base_url}/sse")
        self._sse_ready.clear()
        self._sse_task = asyncio.create_task(self._sse_loop())
        
        # Wait for the 'endpoint' event to give us the POST URL
        try:
            await asyncio.wait_for(self._sse_ready.wait(), timeout=5.0)
        except asyncio.TimeoutError:
            logger.error("Timeout waiting for SSE 'endpoint' event")
            # We don't raise here, we attempt to proceed or let the caller fail

    async def _sse_loop(self):
        """Background task to listen for SSE events."""
        headers = {"Accept": "text/event-stream"}
        connect_url = f"{self.base_url}/sse"
        
        try:
            async with httpx.AsyncClient(timeout=None) as client:
                async with client.stream("GET", connect_url, headers=headers) as response:
                    async for line in response.aiter_lines():
                        if not line.strip():
                            continue
                            
                        # Simple SSE Parser
                        if line.startswith("event:"):
                            current_event = line.split(":", 1)[1].strip()
                            continue
                        
                        if line.startswith("data:"):
                            data_str = line.split(":", 1)[1].strip()
                            # Default event is message if not specified, but here we assume 'endpoint' or 'message'
                            # In standard SSE, event type persists until changed or reset. 
                            # But standard MCP implementation usually sends `event: endpoint\ndata: url`
                            
                            # We need to capture the event type from the previous line.
                            # Since we iterate line by line, we need state.
                            pass 

        except Exception as e:
            logger.error(f"SSE Loop Disconnected: {e}")
            self._sse_ready.clear()

    # Re-implementing _sse_loop properly with state
    async def _sse_loop(self):
        """Background task to listen for SSE events."""
        headers = {"Accept": "text/event-stream"}
        connect_url = f"{self.base_url}/sse"
        
        current_event = "message" # Default
        
        try:
            async with httpx.AsyncClient(timeout=None) as client:
                async with client.stream("GET", connect_url, headers=headers) as response:
                    async for line in response.aiter_lines():
                        line = line.strip()
                        if not line:
                            current_event = "message" # Reset on empty line (end of block)
                            continue
                            
                        if line.startswith("event:"):
                            current_event = line.split(":", 1)[1].strip()
                            continue
                        
                        if line.startswith("data:"):
                            data_str = line.split(":", 1)[1].strip()
                            
                            if current_event == "endpoint":
                                # Server telling us where to POST
                                endpoint = data_str
                                if not endpoint.startswith("http"):
                                    if endpoint.startswith("/"):
                                        self._post_endpoint = f"{self.base_url}{endpoint}"
                                    else:
                                        self._post_endpoint = f"{self.base_url}/{endpoint}"
                                else:
                                    self._post_endpoint = endpoint
                                        
                                logger.info(f"SSE Handshake complete. POST endpoint: {self._post_endpoint}")
                                self._sse_ready.set()
                                
                            elif current_event == "message":
                                # JSON-RPC Response
                                try:
                                    message = json.loads(data_str)
                                    req_id = message.get("id")
                                    if req_id and req_id in self._pending_requests:
                                        future = self._pending_requests.pop(req_id)
                                        if not future.done():
                                            future.set_result(message)
                                except Exception as e:
                                    logger.error(f"Error parsing SSE message: {e}")

        except Exception as e:
            logger.error(f"SSE Loop Disconnected: {e}")
            self._sse_ready.clear()

    async def _send_request(self, method: str, params: Dict, req_id: Any) -> Dict:
        """Internal helper to send JSON-RPC request."""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "id": req_id,
            "params": params
        }
        
        if self.transport == "sse":
            await self._ensure_connection()
            if not self._post_endpoint:
                # If we timed out or didn't get endpoint, try falling back to standard if possible, or raise
                raise ConnectionError("No SSE POST endpoint available (Handshake failed)")
                
            # Create Future for response
            future = asyncio.get_running_loop().create_future()
            self._pending_requests[req_id] = future
            
            # Send POST
            try:
                async with httpx.AsyncClient(timeout=30.0) as client:
                    resp = await client.post(self._post_endpoint, json=payload)
                    resp.raise_for_status()
                    # Some implementations might return the result immediately in POST response 
                    # even if SSE is active. But spec says response comes via SSE.
                    # If response body is not empty and looks like JSON-RPC, use it.
                    if resp.content:
                        try:
                            data = resp.json()
                            if "result" in data or "error" in data:
                                self._pending_requests.pop(req_id, None)
                                return data
                        except:
                            pass
            except Exception as e:
                self._pending_requests.pop(req_id, None)
                raise e
                
            # Wait for response via SSE
            try:
                return await asyncio.wait_for(future, timeout=30.0)
            except asyncio.TimeoutError:
                self._pending_requests.pop(req_id, None)
                raise TimeoutError(f"Timed out waiting for SSE response to {method}")
            
        else:
            # Standard HTTP
            endpoint = f"{self.base_url}/mcp"
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(endpoint, json=payload)
                resp.raise_for_status()
                return resp.json()

    async def list_tools(self) -> List[Dict]:
        """Discovery Phase: Ask the MCP server what it can do."""
        try:
            data = await self._send_request("tools/list", {}, 1)
            
            if "error" in data:
                logger.error(f"MCP List Error from {self.base_url}: {data['error']}")
                return []
            
            result = data.get("result", {})
            return result.get("tools", [])
                
        except Exception as e:
            logger.error(f"Failed to list tools from {self.base_url}: {e}")
            return []

    async def call_tool(self, tool_name: str, arguments: Dict) -> str:
        """Execution Phase: Run the tool."""
        params = {
            "name": tool_name,
            "arguments": arguments,
            "_meta": self.auth_config
        }

        try:
            data = await self._send_request("tools/call", params, 2)
            
            if "error" in data:
                error_msg = data['error'].get('message', 'Unknown error')
                logger.error(f"Tool execution error ({tool_name}): {error_msg}")
                return f"Error executing tool: {error_msg}"
            
            result = data.get("result", {})
            content_list = result.get("content", [])
            
            output_text = []
            for item in content_list:
                if item.get("type") == "text":
                    output_text.append(item.get("text", ""))
                elif item.get("type") == "resource":
                    output_text.append(f"[Resource: {item.get('uri')}]")
                    
            return "\n".join(output_text)

        except Exception as e:
            logger.error(f"Failed to execute tool {tool_name} at {self.base_url}: {e}")
            return f"System Error: Failed to execute tool. {str(e)}"
