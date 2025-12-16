"""
Web Tools
=========

Tools for web-related operations.
"""

from mcp_server.sdk import tool


@tool(description="Search the internet for information")
def web_search(query: str) -> str:
    """Perform a web search."""
    # TODO: Implement real web search API
    return f"Error: Web Search API key missing. Cannot search for '{query}'."
