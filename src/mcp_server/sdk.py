"""
Aura Tool SDK
=============

Provides a simple decorator-based API for creating MCP tools.
Inspired by Flask routes and FastAPI endpoints.

Usage:
    from mcp_server.sdk import tool, get_all_tools

    @tool(description="Get current weather")
    def get_weather(city: str, unit: str = "celsius") -> str:
        return f"Weather in {city}: 25°{unit[0].upper()}"
"""

import inspect
import logging
from typing import Callable, Dict, Any, get_type_hints, Optional
from functools import wraps

logger = logging.getLogger("mcp-sdk")

# Global registry of all decorated tools
_TOOL_REGISTRY: Dict[str, Dict[str, Any]] = {}


def _python_type_to_json_type(py_type) -> str:
    """Convert Python type hints to JSON Schema types."""
    type_map = {
        str: "string",
        int: "integer",
        float: "number",
        bool: "boolean",
        list: "array",
        dict: "object",
    }
    # Handle Optional types (typing.Union[X, None])
    origin = getattr(py_type, "__origin__", None)
    if origin is type(None):
        return "null"
    
    return type_map.get(py_type, "string")


def _generate_schema_from_function(fn: Callable) -> Dict[str, Any]:
    """
    Introspect a function's signature and type hints to generate JSON Schema.
    """
    sig = inspect.signature(fn)
    hints = get_type_hints(fn)
    
    properties = {}
    required = []
    
    for param_name, param in sig.parameters.items():
        if param_name == "self":
            continue
            
        param_type = hints.get(param_name, str)
        json_type = _python_type_to_json_type(param_type)
        
        prop_def = {"type": json_type}
        
        # Add description from docstring if available (future enhancement)
        # For now, use param name as description
        prop_def["description"] = param_name.replace("_", " ").title()
        
        properties[param_name] = prop_def
        
        # If no default value, it's required
        if param.default is inspect.Parameter.empty:
            required.append(param_name)
    
    return {
        "type": "object",
        "properties": properties,
        "required": required
    }


def tool(description: str = ""):
    """
    Decorator to register a function as an MCP tool.
    
    Args:
        description: Human-readable description of what the tool does.
        
    Example:
        @tool(description="Create a calendar event")
        def create_event(title: str, date: str, duration_minutes: int = 60) -> str:
            return f"Created event: {title}"
    """
    def decorator(fn: Callable):
        tool_name = fn.__name__
        schema = _generate_schema_from_function(fn)
        
        _TOOL_REGISTRY[tool_name] = {
            "fn": fn,
            "description": description or f"Tool: {tool_name}",
            "inputSchema": schema
        }
        
        logger.info(f"📦 Registered tool: {tool_name}")
        
        @wraps(fn)
        def wrapper(*args, **kwargs):
            return fn(*args, **kwargs)
        
        return wrapper
    
    return decorator


def get_all_tools() -> Dict[str, Dict[str, Any]]:
    """Return all registered tools."""
    return _TOOL_REGISTRY


def execute_tool(name: str, arguments: Dict[str, Any]) -> str:
    """
    Execute a registered tool by name with given arguments.
    
    Args:
        name: Tool name (function name)
        arguments: Dictionary of arguments
        
    Returns:
        Tool execution result as string
    """
    if name not in _TOOL_REGISTRY:
        raise ValueError(f"Tool '{name}' not found")
    
    tool_def = _TOOL_REGISTRY[name]
    fn = tool_def["fn"]
    
    try:
        result = fn(**arguments)
        return str(result)
    except Exception as e:
        logger.error(f"Tool execution failed: {e}")
        raise
