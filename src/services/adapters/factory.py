"""
Vector Store Factory
====================

Factory pattern for creating vector store adapters based on environment variables.
Switch between Supabase (dev) and Vertex AI (prod) by changing VECTOR_STORE_PROVIDER.
"""

import os
import logging
from enum import Enum
from typing import Optional

from .base import VectorStoreAdapter

logger = logging.getLogger(__name__)


class VectorStoreProvider(Enum):
    """Supported vector store providers."""
    SUPABASE = "supabase"
    VERTEX_AI = "vertex_ai"
    # Add more as needed: QDRANT = "qdrant", PINECONE = "pinecone"


# Singleton instance
_adapter_instance: Optional[VectorStoreAdapter] = None


def get_vector_adapter(pool=None) -> VectorStoreAdapter:
    """
    Factory: Return adapter based on VECTOR_STORE_PROVIDER environment variable.
    
    Args:
        pool: Database connection pool (required for Supabase adapter)
        
    Returns:
        VectorStoreAdapter instance
        
    Environment Variables:
        VECTOR_STORE_PROVIDER: "supabase" (default) or "vertex_ai"
        
        For Vertex AI:
        - GCP_PROJECT_ID: Google Cloud project ID
        - GCP_LOCATION: Region (default: us-central1)
        - VERTEX_INDEX_ENDPOINT: Matching Engine endpoint
        - VERTEX_INDEX_ID: Matching Engine index ID
    """
    global _adapter_instance
    
    # Return existing instance if already created (singleton)
    if _adapter_instance is not None:
        return _adapter_instance
    
    # Use config if available, fallback to env var
    try:
        from config import settings
        provider = settings.vector_store_provider.lower()
    except:
        provider = os.getenv("VECTOR_STORE_PROVIDER", "supabase").lower()
    
    if provider == VectorStoreProvider.SUPABASE.value:
        from .supabase_adapter import SupabaseVectorAdapter
        
        _adapter_instance = SupabaseVectorAdapter(pool=pool)
        logger.info("🔌 Using Supabase/pgvector adapter (dev)")
        
    elif provider == VectorStoreProvider.VERTEX_AI.value:
        from .vertex_adapter import VertexAIVectorAdapter
        
        try:
            from config import settings
            _adapter_instance = VertexAIVectorAdapter(
                project_id=settings.gcp_project_id or "",
                location=settings.gcp_location,
                index_endpoint=settings.vertex_index_endpoint,
                index_id=settings.vertex_index_id
            )
        except:
            _adapter_instance = VertexAIVectorAdapter(
                project_id=os.getenv("GCP_PROJECT_ID", ""),
                location=os.getenv("GCP_LOCATION", "us-central1"),
                index_endpoint=os.getenv("VERTEX_INDEX_ENDPOINT"),
                index_id=os.getenv("VERTEX_INDEX_ID")
            )
        logger.info("🔌 Using Vertex AI Matching Engine adapter (prod)")
        
    else:
        raise ValueError(
            f"Unknown vector store provider: {provider}. "
            f"Valid options: {[p.value for p in VectorStoreProvider]}"
        )
    
    return _adapter_instance


def reset_adapter() -> None:
    """Reset the singleton adapter (for testing)."""
    global _adapter_instance
    _adapter_instance = None


async def initialize_adapter(pool=None) -> VectorStoreAdapter:
    """
    Get and initialize the vector adapter.
    
    Call this during application startup.
    """
    adapter = get_vector_adapter(pool=pool)
    await adapter.initialize(pool=pool) if hasattr(adapter, 'pool') else await adapter.initialize()
    return adapter
