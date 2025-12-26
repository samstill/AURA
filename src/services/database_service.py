"""
Database Service
================

PostgreSQL operations via Supabase.
Uses asyncpg for async database access.
"""

import os
from typing import Optional
import asyncpg
from config import settings


class DatabaseService:
    """
    Handles all PostgreSQL database operations.
    
    Connection is established via the DATABASE_URL secret
    injected by Kubernetes.
    """
    
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
        self.database_url = settings.database_url
    
    async def connect(self):
        """Initialize the connection pool."""
        if not self.database_url:
            raise ValueError("DATABASE_URL environment variable not set")
        
        try:
            # For Supabase connections, we need to parse URL and add SSL
            if "supabase.co" in self.database_url:
                from urllib.parse import urlparse
                
                parsed = urlparse(self.database_url)
                
                # Use ssl='require' string which is simpler and works with asyncpg
                self.pool = await asyncpg.create_pool(
                    host=parsed.hostname,
                    port=parsed.port or 5432,
                    user=parsed.username,
                    password=parsed.password,
                    database=parsed.path.lstrip('/'),
                    min_size=1,
                    max_size=5,
                    command_timeout=30,
                    ssl='require',  # Simple SSL mode
                )
            else:
                # Local PostgreSQL connection
                self.pool = await asyncpg.create_pool(
                    self.database_url,
                    min_size=2,
                    max_size=10,
                    command_timeout=30,
                )
            print("✅ Database connection pool established")
        except Exception as e:
            print(f"⚠️ Database connection failed: {e}")
            import traceback
            traceback.print_exc()
            self.pool = None
            raise
    
    async def disconnect(self):
        """Close the connection pool."""
        if self.pool:
            await self.pool.close()
            print("🔌 Database connection pool closed")
    
    async def health_check(self) -> bool:
        """Check if the database is accessible."""
        if not self.pool:
            return False
        try:
            async with self.pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            return True
        except Exception as e:
            print(f"❌ Database health check failed: {e}")
            return False
    
    # -------------------------------------------------------------------------
    # User Operations
    # -------------------------------------------------------------------------
    async def get_user_by_id(self, user_id: str) -> Optional[dict]:
        """Fetch a user by their ID."""
        if not self.pool:
            raise RuntimeError("Database not connected")
        
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM users WHERE id = $1",
                user_id
            )
            return dict(row) if row else None
    
    async def get_user_by_email(self, email: str) -> Optional[dict]:
        """Fetch a user by their email."""
        if not self.pool:
            raise RuntimeError("Database not connected")
        
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM users WHERE email = $1",
                email
            )
            return dict(row) if row else None

    # -------------------------------------------------------------------------
    # Tool Operations
    # -------------------------------------------------------------------------
    async def get_active_tools_for_user(self, user_id: str) -> list[dict]:
        """
        Fetch active tools for a specific user.
        Returns a list of tools with their config and endpoints.
        """
        if not self.pool:
            # If missing DB connection, return empty list to not crash the agent
            print("⚠️ Database not connected, returning empty tools list")
            return []
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(
                    """
                    SELECT t.name, t.mcp_endpoint, ut.config, t.auth_type
                    FROM tools t
                    JOIN user_tools ut ON t.id = ut.tool_id
                    WHERE ut.user_id = $1 AND ut.is_enabled = TRUE AND t.is_active = TRUE
                    """,
                    user_id
                )
                return [dict(row) for row in rows]
        except Exception as e:
            print(f"❌ Failed to fetch tools: {e}")
            return []

    async def register_tool(self, tool: dict) -> dict:
        """Register a new tool in the global registry."""
        if not self.pool:
            raise RuntimeError("Database not connected")
        
        async with self.pool.acquire() as conn:
            # Assuming 'id' is a serial or uuid generated by DB. 
            # If using UUID, we might need to generate it here or let DB do it.
            # We'll assume DB generates it or we use name as ID?
            # Let's assume standard serial/uuid default.
            # Schema deduction: name, description, mcp_endpoint, auth_type
            row = await conn.fetchrow(
                """
                INSERT INTO tools (name, description, mcp_endpoint, auth_type, is_active)
                VALUES ($1, $2, $3, $4, TRUE)
                RETURNING *
                """,
                tool["name"],
                tool["description"],
                tool["mcp_endpoint"],
                tool["auth_type"]
            )
            return dict(row)

    async def get_all_tools(self, user_id: str) -> list[dict]:
        """
        List all available tools and their connection status for a user.
        """
        if not self.pool:
            raise RuntimeError("Database not connected")
            
        async with self.pool.acquire() as conn:
            # Left join to see if connected
            rows = await conn.fetch(
                """
                SELECT 
                    t.id, t.name, t.description, t.mcp_endpoint, t.auth_type, t.is_active,
                    ut.is_enabled, ut.config
                FROM tools t
                LEFT JOIN user_tools ut ON t.id = ut.tool_id AND ut.user_id = $1
                WHERE t.is_active = TRUE
                """,
                user_id
            )
            return [dict(row) for row in rows]
            
    async def update_user_tool(self, user_id: str, tool_id: str, enabled: bool, config: dict = None) -> bool:
        """Connect/Disconnect a tool for a user."""
        if not self.pool:
            raise RuntimeError("Database not connected")

        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO user_tools (user_id, tool_id, is_enabled, config)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (user_id, tool_id)
                DO UPDATE SET 
                    is_enabled = EXCLUDED.is_enabled,
                    config = COALESCE(EXCLUDED.config, user_tools.config)
                """,
                user_id, tool_id, enabled, config
            )
            return True

    async def delete_tool(self, tool_id: str) -> bool:
        """Soft delete a tool (set is_active = FALSE)."""
        if not self.pool:
            raise RuntimeError("Database not connected")

        async with self.pool.acquire() as conn:
            # Check if tool exists
            result = await conn.execute(
                """
                UPDATE tools 
                SET is_active = FALSE 
                WHERE id = $1
                """,
                tool_id
            )
            # result string format: "UPDATE <count>"
            return result != "UPDATE 0"


# Singleton instance
database_service = DatabaseService()
