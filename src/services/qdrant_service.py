"""
Qdrant Service
==============

Vector store operations via Qdrant Cloud.
Implements the "Supermemory" - semantic search over conversation history.
"""

import os
from typing import Optional, List
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    Filter,
    FieldCondition,
    MatchValue,
)


class QdrantService:
    """
    Handles vector storage and semantic search operations.
    
    Connection is established via QDRANT_URL and QDRANT_API_KEY
    secrets injected by Kubernetes.
    
    Primary Use Cases:
    1. Supermemory: Store conversation embeddings for context retrieval
    2. Semantic search: Find relevant past conversations
    3. User profiling: Build embeddings of user preferences
    """
    
    # Collection names
    CONVERSATIONS_COLLECTION = "aura_conversations"
    USER_PROFILES_COLLECTION = "aura_user_profiles"
    
    # Default embedding dimensions (OpenAI text-embedding-3-small)
    EMBEDDING_DIM = 1536
    
    def __init__(self):
        self.client: Optional[QdrantClient] = None
        self.qdrant_url = os.getenv("QDRANT_URL")
        self.qdrant_api_key = os.getenv("QDRANT_API_KEY")
    
    async def connect(self):
        """Initialize the Qdrant connection."""
        if not self.qdrant_url:
            raise ValueError("QDRANT_URL environment variable not set")
        
        self.client = QdrantClient(
            url=self.qdrant_url,
            api_key=self.qdrant_api_key,
            timeout=30,
        )
        
        # Ensure collections exist
        await self._ensure_collections()
        print("✅ Qdrant connection established")
    
    async def _ensure_collections(self):
        """Create collections if they don't exist."""
        if not self.client:
            return
        
        collections = self.client.get_collections().collections
        collection_names = [c.name for c in collections]
        
        if self.CONVERSATIONS_COLLECTION not in collection_names:
            self.client.create_collection(
                collection_name=self.CONVERSATIONS_COLLECTION,
                vectors_config=VectorParams(
                    size=self.EMBEDDING_DIM,
                    distance=Distance.COSINE,
                ),
            )
            print(f"📦 Created collection: {self.CONVERSATIONS_COLLECTION}")
    
    def health_check(self) -> bool:
        """Check if Qdrant is accessible."""
        if not self.client:
            return False
        try:
            self.client.get_collections()
            return True
        except Exception as e:
            print(f"❌ Qdrant health check failed: {e}")
            return False
    
    # -------------------------------------------------------------------------
    # Vector Operations
    # -------------------------------------------------------------------------
    def store_embedding(
        self,
        collection: str,
        point_id: str,
        vector: List[float],
        payload: dict,
    ):
        """Store a vector with metadata."""
        if not self.client:
            raise RuntimeError("Qdrant not connected")
        
        self.client.upsert(
            collection_name=collection,
            points=[
                PointStruct(
                    id=point_id,
                    vector=vector,
                    payload=payload,
                )
            ],
        )
    
    def search_similar(
        self,
        collection: str,
        query_vector: List[float],
        limit: int = 5,
        user_id: Optional[str] = None,
    ) -> List[dict]:
        """
        Search for similar vectors.
        
        Args:
            collection: Collection to search in
            query_vector: The query embedding
            limit: Maximum results to return
            user_id: Optional filter by user
            
        Returns:
            List of matching documents with scores
        """
        if not self.client:
            raise RuntimeError("Qdrant not connected")
        
        filter_condition = None
        if user_id:
            filter_condition = Filter(
                must=[
                    FieldCondition(
                        key="user_id",
                        match=MatchValue(value=user_id),
                    )
                ]
            )
        
        results = self.client.search(
            collection_name=collection,
            query_vector=query_vector,
            limit=limit,
            query_filter=filter_condition,
        )
        
        return [
            {
                "id": hit.id,
                "score": hit.score,
                "payload": hit.payload,
            }
            for hit in results
        ]
    
    def delete_by_user(self, collection: str, user_id: str):
        """Delete all vectors for a specific user."""
        if not self.client:
            raise RuntimeError("Qdrant not connected")
        
        self.client.delete(
            collection_name=collection,
            points_selector=Filter(
                must=[
                    FieldCondition(
                        key="user_id",
                        match=MatchValue(value=user_id),
                    )
                ]
            ),
        )


# Singleton instance
qdrant_service = QdrantService()
