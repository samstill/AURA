#!/usr/bin/env python3
"""
Reindex Archive Script
======================

Rebuilds the vector index from the archive table.
Use this when switching vector stores (e.g., Supabase → Vertex AI).

Usage:
    python -m scripts.reindex_archive --user test-user
    python -m scripts.reindex_archive --all
    
Environment:
    VECTOR_STORE_PROVIDER: Target vector store (supabase, vertex_ai)
    DATABASE_URL: PostgreSQL connection string
"""

import asyncio
import argparse
import logging
import os
import sys

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from config import settings
from services.database import DatabaseService
from services.adapters.factory import get_vector_adapter, reset_adapter

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def reindex_archive(
    user_id: str = None,
    batch_size: int = 50,
    force: bool = False
):
    """
    Rebuild vector index from archive.
    
    Args:
        user_id: Optional user filter (None = all users)
        batch_size: Number of records to process at once
        force: If True, reindex even if already indexed
    """
    # Initialize database
    db = DatabaseService()
    await db.initialize()
    pool = db.pool
    
    # Reset and get fresh adapter for target provider
    reset_adapter()
    adapter = get_vector_adapter(pool=pool)
    await adapter.initialize(pool=pool)
    
    provider = os.getenv("VECTOR_STORE_PROVIDER", "supabase")
    logger.info(f"🔄 Reindexing to: {provider}")
    
    try:
        async with pool.acquire() as conn:
            # Build query
            if force:
                # Reindex everything
                query = "SELECT id, user_id, content, layer_tag, source_category FROM archive_memories"
            else:
                # Only unindexed records
                query = """
                    SELECT id, user_id, content, layer_tag, source_category 
                    FROM archive_memories 
                    WHERE embedding IS NULL OR last_indexed_at IS NULL
                """
            
            if user_id:
                query += f" AND user_id = '{user_id}'"
            
            query += " ORDER BY created_at"
            
            rows = await conn.fetch(query)
        
        total = len(rows)
        logger.info(f"📊 Found {total} records to index")
        
        if total == 0:
            logger.info("✅ Nothing to reindex")
            return
        
        success = 0
        failed = 0
        
        for i, row in enumerate(rows):
            try:
                result = await adapter.embed_and_store(
                    id=str(row['id']),
                    content=row['content'],
                    user_id=row['user_id'],
                    layer_tag=row['layer_tag'] or 'fact',
                    source_category=row['source_category']
                )
                
                if result:
                    success += 1
                    if (i + 1) % 10 == 0:
                        logger.info(f"Progress: {i + 1}/{total} ({success} success, {failed} failed)")
                else:
                    failed += 1
                    logger.warning(f"Failed to index: {row['id']}")
                    
            except Exception as e:
                failed += 1
                logger.error(f"Error indexing {row['id']}: {e}")
        
        logger.info(f"✅ Reindex complete: {success} success, {failed} failed out of {total}")
        
    finally:
        await db.close()


async def clear_vectors(user_id: str = None):
    """
    Clear all vectors (useful before reindexing to a different store).
    """
    db = DatabaseService()
    await db.initialize()
    pool = db.pool
    
    try:
        async with pool.acquire() as conn:
            if user_id:
                result = await conn.execute("""
                    UPDATE archive_memories 
                    SET embedding = NULL, last_indexed_at = NULL
                    WHERE user_id = $1
                """, user_id)
                logger.info(f"Cleared vectors for user: {user_id}")
            else:
                result = await conn.execute("""
                    UPDATE archive_memories 
                    SET embedding = NULL, last_indexed_at = NULL
                """)
                logger.info("Cleared all vectors")
    finally:
        await db.close()


def main():
    parser = argparse.ArgumentParser(description='Reindex archive to vector store')
    parser.add_argument('--user', '-u', help='User ID to reindex (default: all users)')
    parser.add_argument('--all', '-a', action='store_true', help='Reindex all users')
    parser.add_argument('--force', '-f', action='store_true', help='Force reindex even if already indexed')
    parser.add_argument('--clear', action='store_true', help='Clear vectors before reindexing')
    parser.add_argument('--batch-size', '-b', type=int, default=50, help='Batch size')
    
    args = parser.parse_args()
    
    if not args.user and not args.all:
        print("Error: Specify --user <id> or --all")
        parser.print_help()
        sys.exit(1)
    
    user_id = args.user if args.user else None
    
    if args.clear:
        asyncio.run(clear_vectors(user_id))
    
    asyncio.run(reindex_archive(
        user_id=user_id,
        batch_size=args.batch_size,
        force=args.force
    ))


if __name__ == "__main__":
    main()
