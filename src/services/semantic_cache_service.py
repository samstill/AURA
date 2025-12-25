"""
Semantic Cache Service
======================

Provides instant responses (~10ms) for semantically similar queries.
Uses Gemini embeddings + Qdrant for vector similarity search,
with Redis as a fast exact-match fallback.

Part of the Aura Routing Algorithm - Phase A (Ingestion).
"""

import logging
import hashlib
from typing import Optional, Tuple
from dataclasses import dataclass

import google.generativeai as genai

from config import settings

logger = logging.getLogger(__name__)


@dataclass
class CacheHit:
    """Represents a cache hit with the cached response and metadata."""
    response: str
    similarity: float
    source: str  # "exact" or "semantic"
    query_hash: str


class SemanticCacheService:
    """
    Semantic cache for instant response retrieval.
    
    Two-tier caching:
    1. Exact match (Redis): O(1) lookup, ~10ms
    2. Semantic match (Qdrant): Vector similarity, ~50ms
    
    Cache isolation is per-user for personalized responses.
    """
    
    CACHE_COLLECTION = "aura_cache"
    EMBEDDING_DIM = 768  # Gemini embedding dimension
    
    def __init__(self):
        self._initialized = False
        self.redis_client = None
        self.qdrant_client = None
        self.similarity_threshold = 0.95  # Minimum similarity for cache hit
        self.ttl_seconds = 3600  # 1 hour default TTL
    
    def initialize(self):
        """Initialize the cache service with external connections."""
        from services.redis_service import redis_service
        from services.qdrant_service import qdrant_service
        
        self.redis_client = redis_service
        self.qdrant_client = qdrant_service
        
        # Update settings from config
        self.similarity_threshold = getattr(settings, 'aura_cache_similarity_threshold', 0.95)
        self.ttl_seconds = getattr(settings, 'aura_cache_ttl', 3600)
        
        self._initialized = True
        logger.info("✅ Semantic Cache Service initialized")
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized
    
    def _get_query_hash(self, query: str, user_id: str) -> str:
        """Generate a deterministic hash for exact-match lookups."""
        content = f"{user_id}:{query.lower().strip()}"
        return hashlib.sha256(content.encode()).hexdigest()[:32]
    
    async def _get_embedding(self, text: str) -> list[float]:
        """
        Get embedding vector for text using Gemini.
        
        Uses embedding model from settings for high-quality semantic embeddings.
        """
        try:
            result = genai.embed_content(
                model=settings.embedding_model,
                content=text,
                task_type="retrieval_query"
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            raise
    
    async def check(self, query: str, user_id: str) -> Optional[CacheHit]:
        """
        Check cache for a matching response.
        
        Flow:
        1. Exact match check (Redis) - ~10ms
        2. Semantic match check (Qdrant) - ~50ms
        
        Args:
            query: User's input query
            user_id: User ID for cache isolation
            
        Returns:
            CacheHit if found, None otherwise
        """
        if not self._initialized:
            logger.warning("Semantic cache not initialized, skipping check")
            return None
        
        query_hash = self._get_query_hash(query, user_id)
        
        # 1. Exact match check (Redis)
        try:
            if self.redis_client and self.redis_client.client:
                cached = await self.redis_client.cache_get(f"cache:{query_hash}")
                if cached:
                    logger.info(f"🎯 [Cache] Exact hit for query hash {query_hash[:8]}")
                    return CacheHit(
                        response=cached,
                        similarity=1.0,
                        source="exact",
                        query_hash=query_hash
                    )
        except Exception as e:
            logger.warning(f"Redis exact-match check failed: {e}")
        
        # 2. Semantic match check (Qdrant)
        try:
            if self.qdrant_client and self.qdrant_client.client:
                embedding = await self._get_embedding(query)
                
                results = self.qdrant_client.search_similar(
                    collection=self.CACHE_COLLECTION,
                    query_vector=embedding,
                    limit=1,
                    user_id=user_id
                )
                
                if results and results[0]["score"] >= self.similarity_threshold:
                    hit = results[0]
                    logger.info(f"🎯 [Cache] Semantic hit (score: {hit['score']:.3f})")
                    return CacheHit(
                        response=hit["payload"]["response"],
                        similarity=hit["score"],
                        source="semantic",
                        query_hash=query_hash
                    )
        except Exception as e:
            logger.warning(f"Qdrant semantic check failed: {e}")
        
        logger.debug(f"❌ [Cache] Miss for query: {query[:30]}...")
        return None
    
    async def store(
        self, 
        query: str, 
        response: str, 
        user_id: str,
        ttl: Optional[int] = None
    ) -> bool:
        """
        Store a query-response pair in the cache.
        
        Stores in both Redis (exact match) and Qdrant (semantic match).
        
        Args:
            query: Original query
            response: Generated response
            user_id: User ID for isolation
            ttl: Optional TTL override in seconds
            
        Returns:
            True if stored successfully
        """
        if not self._initialized:
            logger.warning("Semantic cache not initialized, skipping store")
            return False
        
        query_hash = self._get_query_hash(query, user_id)
        ttl = ttl or self.ttl_seconds
        
        # 1. Store in Redis (exact match)
        try:
            if self.redis_client and self.redis_client.client:
                await self.redis_client.cache_set(
                    f"cache:{query_hash}",
                    response,
                    ttl_seconds=ttl
                )
                logger.debug(f"📦 [Cache] Stored exact match: {query_hash[:8]}")
        except Exception as e:
            logger.warning(f"Redis store failed: {e}")
        
        # 2. Store in Qdrant (semantic match)
        try:
            if self.qdrant_client and self.qdrant_client.client:
                embedding = await self._get_embedding(query)
                
                self.qdrant_client.store_embedding(
                    collection=self.CACHE_COLLECTION,
                    point_id=query_hash,
                    vector=embedding,
                    payload={
                        "query": query,
                        "response": response,
                        "user_id": user_id,
                    }
                )
                logger.debug(f"📦 [Cache] Stored semantic embedding: {query_hash[:8]}")
        except Exception as e:
            logger.warning(f"Qdrant store failed: {e}")
        
        return True
    
    async def invalidate(self, query: str, user_id: str) -> bool:
        """
        Invalidate a cached entry.
        
        Removes from both Redis and Qdrant.
        """
        if not self._initialized:
            return False
        
        query_hash = self._get_query_hash(query, user_id)
        
        try:
            if self.redis_client and self.redis_client.client:
                await self.redis_client.cache_delete(f"cache:{query_hash}")
        except Exception as e:
            logger.warning(f"Redis invalidation failed: {e}")
        
        # Note: Qdrant deletion by ID would need to be implemented
        # For now, TTL-based expiration handles cleanup
        
        return True
    
    async def clear_user_cache(self, user_id: str) -> bool:
        """Clear all cached entries for a user."""
        if not self._initialized:
            return False
        
        try:
            if self.qdrant_client and self.qdrant_client.client:
                self.qdrant_client.delete_by_user(self.CACHE_COLLECTION, user_id)
                logger.info(f"🗑️ [Cache] Cleared cache for user: {user_id}")
        except Exception as e:
            logger.warning(f"User cache clear failed: {e}")
        
        return True


# Singleton instance
semantic_cache_service = SemanticCacheService()
