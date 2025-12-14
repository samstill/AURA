"""
Database Service
================

PostgreSQL operations via Supabase.
Uses asyncpg for async database access.
"""

import os
from typing import Optional
import asyncpg


class DatabaseService:
    """
    Handles all PostgreSQL database operations.
    
    Connection is established via the DATABASE_URL secret
    injected by Kubernetes.
    """
    
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
        self.database_url = os.getenv("DATABASE_URL")
    
    async def connect(self):
        """Initialize the connection pool."""
        if not self.database_url:
            raise ValueError("DATABASE_URL environment variable not set")
        
        self.pool = await asyncpg.create_pool(
            self.database_url,
            min_size=2,
            max_size=10,
            command_timeout=30,
        )
        print("✅ Database connection pool established")
    
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


# Singleton instance
database_service = DatabaseService()
