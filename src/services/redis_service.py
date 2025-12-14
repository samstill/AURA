"""
Redis Service
=============

Cache and event bus operations via Upstash.
Used for the "Echo Loop" - real-time event streaming.
"""

import os
from typing import Optional, Any
import json
import redis.asyncio as redis


class RedisService:
    """
    Handles Redis operations for caching and pub/sub.
    
    Connection is established via the REDIS_URL secret
    injected by Kubernetes.
    
    Primary Use Cases:
    1. Echo Loop: Real-time event broadcasting
    2. Session caching: Fast user session lookups
    3. Rate limiting: API throttling
    """
    
    def __init__(self):
        self.client: Optional[redis.Redis] = None
        self.redis_url = os.getenv("REDIS_URL")
    
    async def connect(self):
        """Initialize the Redis connection."""
        if not self.redis_url:
            raise ValueError("REDIS_URL environment variable not set")
        
        self.client = redis.from_url(
            self.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
        print("✅ Redis connection established")
    
    async def disconnect(self):
        """Close the Redis connection."""
        if self.client:
            await self.client.close()
            print("🔌 Redis connection closed")
    
    async def health_check(self) -> bool:
        """Check if Redis is accessible."""
        if not self.client:
            return False
        try:
            await self.client.ping()
            return True
        except Exception as e:
            print(f"❌ Redis health check failed: {e}")
            return False
    
    # -------------------------------------------------------------------------
    # Cache Operations
    # -------------------------------------------------------------------------
    async def cache_set(self, key: str, value: Any, ttl_seconds: int = 3600):
        """Set a cache value with TTL."""
        if not self.client:
            raise RuntimeError("Redis not connected")
        
        serialized = json.dumps(value) if not isinstance(value, str) else value
        await self.client.setex(key, ttl_seconds, serialized)
    
    async def cache_get(self, key: str) -> Optional[Any]:
        """Get a cached value."""
        if not self.client:
            raise RuntimeError("Redis not connected")
        
        value = await self.client.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return value
        return None
    
    async def cache_delete(self, key: str):
        """Delete a cached value."""
        if not self.client:
            raise RuntimeError("Redis not connected")
        
        await self.client.delete(key)
    
    # -------------------------------------------------------------------------
    # Pub/Sub Operations (Echo Loop)
    # -------------------------------------------------------------------------
    async def publish(self, channel: str, message: dict):
        """Publish a message to a channel."""
        if not self.client:
            raise RuntimeError("Redis not connected")
        
        await self.client.publish(channel, json.dumps(message))
    
    async def subscribe(self, channel: str):
        """
        Subscribe to a channel.
        Returns an async generator that yields messages.
        """
        if not self.client:
            raise RuntimeError("Redis not connected")
        
        pubsub = self.client.pubsub()
        await pubsub.subscribe(channel)
        return pubsub


# Singleton instance
redis_service = RedisService()
