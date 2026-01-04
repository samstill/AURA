"""
Vector Store Adapters
=====================

Adapter pattern for switching between vector stores (Supabase, Vertex AI, etc.)
via environment variable. Keeps all existing Supermemory logic intact.
"""

from .base import VectorStoreAdapter, SearchResult
from .factory import get_vector_adapter, VectorStoreProvider

__all__ = [
    "VectorStoreAdapter",
    "SearchResult", 
    "get_vector_adapter",
    "VectorStoreProvider"
]
