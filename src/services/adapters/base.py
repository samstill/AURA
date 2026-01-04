"""
Vector Store Adapter - Base Interface
======================================

Abstract base class for vector store adapters.
All vector stores (Supabase, Vertex AI, Qdrant, etc.) must implement this interface.
"""

from abc import ABC, abstractmethod
from typing import List, Optional
from dataclasses import dataclass


@dataclass
class SearchResult:
    """Result from vector similarity search."""
    id: str
    content: str
    similarity: float
    metadata: dict
    layer_tag: Optional[str] = None
    source_category: Optional[str] = None


class VectorStoreAdapter(ABC):
    """
    Abstract interface for vector stores.
    
    The application code calls these generic methods,
    unaware of whether Supabase or Vertex AI is running underneath.
    """
    
    @abstractmethod
    async def initialize(self) -> None:
        """Initialize connection to the vector store."""
        pass
    
    @abstractmethod
    async def get_embedding(self, text: str) -> List[float]:
        """
        Generate embedding vector for text.
        
        Args:
            text: The text to embed
            
        Returns:
            List of floats representing the embedding vector
        """
        pass
    
    @abstractmethod
    async def embed_and_store(
        self, 
        id: str, 
        content: str, 
        user_id: str,
        layer_tag: str = "fact",
        source_category: Optional[str] = None
    ) -> bool:
        """
        Generate embedding and store in vector index.
        
        Args:
            id: Unique identifier (matches archive table)
            content: Text content to embed
            user_id: User identifier
            layer_tag: Category tag
            source_category: Source of the memory
            
        Returns:
            True if successful
        """
        pass
    
    @abstractmethod
    async def search(
        self, 
        query: str, 
        user_id: str, 
        k: int = 5,
        threshold: float = 0.75,
        layer_tag: Optional[str] = None
    ) -> List[SearchResult]:
        """
        Semantic search in vector store.
        
        Args:
            query: Search query text
            user_id: Filter by user
            k: Number of results
            threshold: Minimum similarity threshold
            layer_tag: Optional filter by category
            
        Returns:
            List of SearchResult objects
        """
        pass
    
    @abstractmethod
    async def delete(self, id: str) -> bool:
        """
        Delete from vector index.
        
        Args:
            id: ID of the vector to delete
            
        Returns:
            True if successful
        """
        pass
    
    @abstractmethod
    async def delete_user_vectors(self, user_id: str) -> bool:
        """
        Delete all vectors for a user.
        
        Args:
            user_id: User identifier
            
        Returns:
            True if successful
        """
        pass
