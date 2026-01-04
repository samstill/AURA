"""
Supabase Vector Adapter
=======================

Implementation of VectorStoreAdapter for Supabase/PostgreSQL with pgvector.
This wraps the existing pgvector logic from memory_repository.
"""

import logging
from typing import List, Optional
from datetime import datetime

import google.generativeai as genai

from .base import VectorStoreAdapter, SearchResult
from config import settings

logger = logging.getLogger(__name__)


class SupabaseVectorAdapter(VectorStoreAdapter):
    """
    Supabase/pgvector implementation of VectorStoreAdapter.
    
    Uses:
    - PostgreSQL with pgvector extension
    - Gemini for embeddings
    - Existing archive_memories table for vector storage
    """
    
    def __init__(self, pool=None):
        """
        Initialize adapter.
        
        Args:
            pool: asyncpg connection pool (optional, can be set later via initialize)
        """
        self.pool = pool
        self._embedding_model = "models/text-embedding-004"
    
    async def initialize(self, pool=None) -> None:
        """Initialize with database connection pool."""
        if pool:
            self.pool = pool
        logger.info("✅ Supabase vector adapter initialized")
    
    async def get_embedding(self, text: str) -> List[float]:
        """Generate embedding using Gemini."""
        try:
            result = genai.embed_content(
                model=self._embedding_model,
                content=text,
                task_type="retrieval_document"
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            return []
    
    async def get_query_embedding(self, text: str) -> List[float]:
        """Generate query embedding (optimized for search)."""
        try:
            result = genai.embed_content(
                model=self._embedding_model,
                content=text,
                task_type="retrieval_query"
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Query embedding generation failed: {e}")
            return []
    
    def _embedding_to_pgvector(self, embedding: List[float]) -> Optional[str]:
        """Convert embedding list to pgvector string format."""
        if not embedding:
            return None
        return "[" + ",".join(str(x) for x in embedding) + "]"
    
    async def embed_and_store(
        self, 
        id: str, 
        content: str, 
        user_id: str,
        layer_tag: str = "fact",
        source_category: Optional[str] = None
    ) -> bool:
        """
        Generate embedding and store/update in archive_memories.
        
        This ONLY updates the embedding - the raw content should already
        be in the archive table (archive-first pattern).
        """
        if not self.pool:
            logger.error("Pool not initialized")
            return False
        
        try:
            embedding = await self.get_embedding(content)
            embedding_str = self._embedding_to_pgvector(embedding)
            
            if not embedding_str:
                logger.warning(f"Empty embedding for content: {content[:50]}...")
                return False
            
            async with self.pool.acquire() as conn:
                # Update embedding for existing archive record
                result = await conn.execute("""
                    UPDATE archive_memories 
                    SET embedding = $2::vector,
                        last_indexed_at = NOW(),
                        embedding_model = $3
                    WHERE id = $1::uuid
                """, id, embedding_str, self._embedding_model)
                
                # If no record exists, this is a direct insert (for backward compat)
                if result == "UPDATE 0":
                    await conn.execute("""
                        INSERT INTO archive_memories 
                            (id, user_id, content, embedding, layer_tag, source_category, created_at)
                        VALUES ($1::uuid, $2, $3, $4::vector, $5, $6, NOW())
                    """, id, user_id, content, embedding_str, layer_tag, source_category)
            
            logger.debug(f"✅ Embedded and stored: {id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to embed and store {id}: {e}")
            return False
    
    async def search(
        self, 
        query: str, 
        user_id: str, 
        k: int = 5,
        threshold: float = 0.75,
        layer_tag: Optional[str] = None
    ) -> List[SearchResult]:
        """Semantic search using pgvector cosine similarity."""
        if not self.pool:
            logger.error("Pool not initialized")
            return []
        
        try:
            query_embedding = await self.get_query_embedding(query)
            embedding_str = self._embedding_to_pgvector(query_embedding)
            
            if not embedding_str:
                return []
            
            async with self.pool.acquire() as conn:
                # Build query with optional layer_tag filter
                base_query = """
                    SELECT 
                        id,
                        content,
                        layer_tag,
                        source_category,
                        metadata,
                        1 - (embedding <=> $1::vector) as similarity
                    FROM archive_memories
                    WHERE user_id = $2
                      AND embedding IS NOT NULL
                      AND 1 - (embedding <=> $1::vector) >= $3
                """
                
                if layer_tag:
                    base_query += " AND layer_tag = $5"
                    base_query += " ORDER BY embedding <=> $1::vector LIMIT $4"
                    rows = await conn.fetch(base_query, embedding_str, user_id, threshold, k, layer_tag)
                else:
                    base_query += " ORDER BY embedding <=> $1::vector LIMIT $4"
                    rows = await conn.fetch(base_query, embedding_str, user_id, threshold, k)
            
            return [
                SearchResult(
                    id=str(row['id']),
                    content=row['content'],
                    similarity=float(row['similarity']),
                    metadata=row['metadata'] or {},
                    layer_tag=row['layer_tag'],
                    source_category=row['source_category']
                )
                for row in rows
            ]
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            return []
    
    async def delete(self, id: str) -> bool:
        """Delete a single vector (sets embedding to NULL, keeps archive record)."""
        if not self.pool:
            return False
        
        try:
            async with self.pool.acquire() as conn:
                await conn.execute("""
                    UPDATE archive_memories 
                    SET embedding = NULL, last_indexed_at = NULL
                    WHERE id = $1::uuid
                """, id)
            return True
        except Exception as e:
            logger.error(f"Delete vector failed: {e}")
            return False
    
    async def delete_user_vectors(self, user_id: str) -> bool:
        """Delete all vectors for a user (keeps archive records)."""
        if not self.pool:
            return False
        
        try:
            async with self.pool.acquire() as conn:
                await conn.execute("""
                    UPDATE archive_memories 
                    SET embedding = NULL, last_indexed_at = NULL
                    WHERE user_id = $1
                """, user_id)
            return True
        except Exception as e:
            logger.error(f"Delete user vectors failed: {e}")
            return False
