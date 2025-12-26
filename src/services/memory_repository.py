"""
Memory Repository - Data Access Layer
======================================

Repository pattern implementation for memory storage.
Handles all database operations for user profiles and archive memories.

Uses asyncpg for async PostgreSQL access.
"""

import logging
import json
from typing import Optional, List, Dict, Any
from datetime import datetime

import google.generativeai as genai

from config import settings

logger = logging.getLogger(__name__)


class MemoryRepository:
    """
    Data Access Layer for Super Memory system.
    
    Provides CRUD operations with:
    - Optimistic Concurrency Control via versioning
    - Vector embedding generation for archive search
    - Efficient batch operations
    """
    
    EMBEDDING_DIM = 768  # Gemini embedding dimension
    
    def __init__(self):
        self.pool = None
        self._initialized = False
    
    async def initialize(self, pool):
        """Initialize with database connection pool."""
        self.pool = pool
        self._initialized = True
        logger.info("✅ Memory Repository initialized")
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized and self.pool is not None
    
    # =========================================================================
    # Embedding Generation
    # =========================================================================
    
    async def get_embedding(self, text: str) -> List[float]:
        """Generate embedding vector for text using Gemini."""
        try:
            result = genai.embed_content(
                model=settings.embedding_model,
                content=text,
                task_type="retrieval_document"
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            raise
    
    async def get_query_embedding(self, text: str) -> List[float]:
        """Generate query embedding (optimized for search)."""
        try:
            result = genai.embed_content(
                model=settings.embedding_model,
                content=text,
                task_type="retrieval_query"
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Query embedding generation failed: {e}")
            raise
    
    # =========================================================================
    # User Profile Operations
    # =========================================================================
    
    async def get_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Fetch complete user profile.
        
        Returns full profile including version for optimistic locking.
        """
        if not self.is_initialized:
            logger.warning("Memory repository not initialized")
            return None
        
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT 
                    user_id, tier_1_summary, long_term_profile, profile_version,
                    created_at, last_updated, last_interaction,
                    total_interactions, word_count
                FROM user_profiles 
                WHERE user_id = $1
                """,
                user_id
            )
            if row:
                return dict(row)
            return None
    
    async def get_tier1_summary(self, user_id: str) -> str:
        """
        FAST PATH: Fetch only the cheat sheet summary.
        
        Optimized for minimal latency in the hot path.
        """
        if not self.is_initialized:
            return ""
        
        async with self.pool.acquire() as conn:
            result = await conn.fetchval(
                "SELECT tier_1_summary FROM user_profiles WHERE user_id = $1",
                user_id
            )
            return result or ""
    
    async def create_profile(
        self, 
        user_id: str, 
        initial_profile: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """Create a new user profile."""
        if not self.is_initialized:
            raise RuntimeError("Memory repository not initialized")
        
        default_profile = {
            "identity": [],
            "core_beliefs": [],
            "behavioral_patterns": [],
            "preferences": [],
            "active_projects": [],
            "emotional_baseline": "neutral",
            "relationship_context": {}
        }
        
        profile = initial_profile or default_profile
        
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO user_profiles (user_id, long_term_profile, tier_1_summary)
                VALUES ($1, $2, '')
                ON CONFLICT (user_id) DO NOTHING
                RETURNING *
                """,
                user_id,
                json.dumps(profile)
            )
            if row:
                return dict(row)
            # Profile already exists, fetch it
            return await self.get_profile(user_id)
    
    async def update_profile_with_version(
        self,
        user_id: str,
        tier_1_summary: str,
        long_term_profile: Dict,
        expected_version: int
    ) -> Dict[str, Any]:
        """
        Update profile with optimistic locking.
        
        Uses version check to prevent race conditions.
        Returns: {"success": bool, "new_version": int, "error_message": str}
        """
        if not self.is_initialized:
            raise RuntimeError("Memory repository not initialized")
        
        async with self.pool.acquire() as conn:
            # Use the RPC function for atomic update
            row = await conn.fetchrow(
                """
                SELECT * FROM update_profile_with_version($1, $2, $3, $4)
                """,
                user_id,
                tier_1_summary,
                json.dumps(long_term_profile),
                expected_version
            )
            if row:
                return dict(row)
            return {"success": False, "new_version": 0, "error_message": "Update failed"}
    
    async def increment_interaction(self, user_id: str) -> None:
        """Increment interaction count and update last_interaction."""
        if not self.is_initialized:
            return
        
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE user_profiles 
                SET 
                    total_interactions = total_interactions + 1,
                    last_interaction = NOW()
                WHERE user_id = $1
                """,
                user_id
            )
    
    # =========================================================================
    # Archive Memory Operations
    # =========================================================================
    
    async def insert_archive_memory(
        self,
        user_id: str,
        content: str,
        layer_tag: str,
        source_category: Optional[str] = None,
        original_created_at: Optional[datetime] = None
    ) -> int:
        """
        Insert a memory into cold storage with embedding.
        
        Returns the ID of the inserted memory.
        """
        if not self.is_initialized:
            raise RuntimeError("Memory repository not initialized")
        
        # Generate embedding for the content
        embedding = await self.get_embedding(content)
        
        async with self.pool.acquire() as conn:
            memory_id = await conn.fetchval(
                """
                INSERT INTO archive_memories 
                    (user_id, content, embedding, layer_tag, source_category, original_created_at)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id
                """,
                user_id,
                content,
                embedding,
                layer_tag,
                source_category,
                original_created_at or datetime.utcnow()
            )
            return memory_id
    
    async def insert_archive_memories_batch(
        self,
        memories: List[Dict[str, Any]]
    ) -> List[int]:
        """
        Batch insert memories into cold storage.
        
        More efficient for archiving multiple facts at once.
        """
        if not self.is_initialized or not memories:
            return []
        
        ids = []
        async with self.pool.acquire() as conn:
            for memory in memories:
                # Generate embedding
                embedding = await self.get_embedding(memory['content'])
                
                memory_id = await conn.fetchval(
                    """
                    INSERT INTO archive_memories 
                        (user_id, content, embedding, layer_tag, source_category)
                    VALUES ($1, $2, $3, $4, $5)
                    RETURNING id
                    """,
                    memory['user_id'],
                    memory['content'],
                    embedding,
                    memory.get('layer_tag', 'fact'),
                    memory.get('source_category')
                )
                ids.append(memory_id)
        
        return ids
    
    async def delete_user_data(self, user_id: str) -> bool:
        """
        Delete ALL data for a user (profile and archive).
        
        Returns True if successful.
        """
        if not self.is_initialized:
            return False
            
        try:
            async with self.pool.acquire() as conn:
                async with conn.transaction():
                    # 1. Delete profile
                    await conn.execute(
                        "DELETE FROM user_profiles WHERE user_id = $1",
                        user_id
                    )
                    
                    # 2. Delete archive memories
                    await conn.execute(
                        "DELETE FROM archive_memories WHERE user_id = $1",
                        user_id
                    )
            
            logger.info(f"🗑️ Deleted all data for user {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to delete user data for {user_id}: {e}")
            return False
    
    async def search_archive(
        self,
        query: str,
        user_id: str,
        match_threshold: float = 0.75,
        match_count: int = 5,
        layer_tag: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Semantic search in the archive.
        
        Uses vector similarity to find relevant memories.
        """
        if not self.is_initialized:
            return []
        
        try:
            # Generate query embedding
            query_embedding = await self.get_query_embedding(query)
            
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(
                    """
                    SELECT * FROM search_archive($1, $2, $3, $4, $5)
                    """,
                    query_embedding,
                    match_threshold,
                    match_count,
                    user_id,
                    layer_tag
                )
                return [dict(row) for row in rows]
        except Exception as e:
            logger.error(f"Archive search failed: {e}")
            return []
    
    async def touch_memory(self, memory_id: int) -> None:
        """Update last_accessed and increment access_count."""
        if not self.is_initialized:
            return
        
        async with self.pool.acquire() as conn:
            await conn.execute(
                "SELECT touch_archive_memory($1)",
                memory_id
            )
    
    async def get_archive_memories_by_user(
        self,
        user_id: str,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Fetch archived memories for a user (paginated)."""
        if not self.is_initialized:
            return []
        
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT id, content, layer_tag, source_category, 
                       archived_at, last_accessed, access_count
                FROM archive_memories
                WHERE user_id = $1
                ORDER BY archived_at DESC
                LIMIT $2 OFFSET $3
                """,
                user_id,
                limit,
                offset
            )
            return [dict(row) for row in rows]


# Singleton instance
memory_repository = MemoryRepository()
