"""
Utility Tools
=============

General purpose utility tools.
"""

from datetime import datetime
from mcp_server.sdk import tool


@tool(description="Get current time in a specific timezone")
def get_current_time(timezone: str = "UTC") -> str:
    """Get the current date and time."""
    now = datetime.utcnow().isoformat()
    return f"Current time ({timezone}): {now}"


@tool(description="Perform basic arithmetic calculations")
def calculate(a: float, b: float, operation: str = "add") -> str:
    """
    Perform arithmetic: add, subtract, multiply, divide.
    """
    if operation == "add":
        return str(a + b)
    elif operation == "subtract":
        return str(a - b)
    elif operation == "multiply":
        return str(a * b)
    elif operation == "divide":
        if b == 0:
            return "Error: Division by zero"
        return str(a / b)
    return f"Error: Unknown operation '{operation}'"
