-- =============================================================================
-- Super Memory 3.0 - Database Migration
-- =============================================================================
-- Run this in Supabase SQL Editor to create the 3-Tier memory system.
-- 
-- Tier 1: Short-term (context window) - handled in-memory
-- Tier 2: Warm Profile (user_profiles) - active 2000-word profile
-- Tier 3: Cold Archive (archive_memories) - vector-searchable long-term storage
-- =============================================================================

-- Enable pgvector extension for semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- =============================================================================
-- Tier 2: Warm Profile (Active Memory)
-- =============================================================================
-- Stores the current psychological profile and fast-access summary.
-- Uses optimistic locking via profile_version to prevent race conditions.

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id TEXT PRIMARY KEY,
    
    -- Tier 1 Summary: 500-word "Cheat Sheet" for fast LLM injection
    tier_1_summary TEXT DEFAULT '',
    
    -- Long-term Profile: Structured JSON with identity, beliefs, patterns, etc.
    -- Max ~2000 words when serialized
    long_term_profile JSONB DEFAULT '{
        "identity": [],
        "core_beliefs": [],
        "behavioral_patterns": [],
        "preferences": [],
        "active_projects": [],
        "emotional_baseline": "neutral",
        "relationship_context": {}
    }'::jsonb,
    
    -- Optimistic Concurrency Control: prevents race conditions
    profile_version INTEGER DEFAULT 1 NOT NULL,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    last_interaction TIMESTAMPTZ DEFAULT NOW(),
    
    -- Stats for pruning decisions
    total_interactions INTEGER DEFAULT 0,
    word_count INTEGER DEFAULT 0
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_updated 
    ON user_profiles(last_updated DESC);

-- =============================================================================
-- Tier 3: Cold Archive (Deep Storage)
-- =============================================================================
-- Stores old facts pruned from the active profile.
-- Uses pgvector for semantic similarity search.

CREATE TABLE IF NOT EXISTS archive_memories (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    
    -- Memory content
    content TEXT NOT NULL,
    
    -- Semantic search vector (Gemini embedding dimension)
    embedding vector(768),
    
    -- Categorization for filtering
    layer_tag TEXT CHECK (layer_tag IN (
        'conscious',      -- Explicit facts
        'rational',       -- Logic/reasoning
        'subconscious',   -- Implied habits
        'unconscious',    -- Hidden drivers
        'emotional',      -- Emotional states
        'fact',           -- General facts
        'preference',     -- Old preferences
        'project'         -- Completed projects
    )),
    
    -- Source tracking
    source_category TEXT,  -- Original profile section
    
    -- Timestamps
    archived_at TIMESTAMPTZ DEFAULT NOW(),
    original_created_at TIMESTAMPTZ,
    last_accessed TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_archive_user_id 
    ON archive_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_archive_layer_tag 
    ON archive_memories(layer_tag);
CREATE INDEX IF NOT EXISTS idx_archive_archived_at 
    ON archive_memories(archived_at DESC);

-- Vector index for semantic search (IVFFlat for balance of speed/accuracy)
CREATE INDEX IF NOT EXISTS idx_archive_embedding 
    ON archive_memories USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- =============================================================================
-- RPC Function: Semantic Search in Archive
-- =============================================================================
-- Allows Python to search the archive efficiently via Supabase RPC.

CREATE OR REPLACE FUNCTION search_archive(
    query_embedding vector(768),
    match_threshold FLOAT DEFAULT 0.75,
    match_count INT DEFAULT 5,
    p_user_id TEXT DEFAULT NULL,
    p_layer_tag TEXT DEFAULT NULL
)
RETURNS TABLE (
    id BIGINT,
    content TEXT,
    similarity FLOAT,
    layer_tag TEXT,
    archived_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        am.id,
        am.content,
        1 - (am.embedding <=> query_embedding) AS similarity,
        am.layer_tag,
        am.archived_at
    FROM archive_memories am
    WHERE 
        (p_user_id IS NULL OR am.user_id = p_user_id)
        AND (p_layer_tag IS NULL OR am.layer_tag = p_layer_tag)
        AND 1 - (am.embedding <=> query_embedding) > match_threshold
    ORDER BY am.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- =============================================================================
-- RPC Function: Update Profile with Optimistic Locking
-- =============================================================================
-- Atomic update that fails if version doesn't match (prevents race conditions).

CREATE OR REPLACE FUNCTION update_profile_with_version(
    p_user_id TEXT,
    p_tier_1_summary TEXT,
    p_long_term_profile JSONB,
    p_expected_version INT
)
RETURNS TABLE (
    success BOOLEAN,
    new_version INT,
    error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_version INT;
    v_rows_updated INT;
BEGIN
    -- Attempt atomic update with version check
    UPDATE user_profiles
    SET 
        tier_1_summary = p_tier_1_summary,
        long_term_profile = p_long_term_profile,
        profile_version = profile_version + 1,
        last_updated = NOW(),
        word_count = (
            SELECT COALESCE(
                array_length(regexp_split_to_array(p_tier_1_summary, '\s+'), 1), 0
            ) + COALESCE(
                array_length(regexp_split_to_array(p_long_term_profile::text, '\s+'), 1), 0
            )
        )
    WHERE user_id = p_user_id 
      AND profile_version = p_expected_version;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        -- Check if user exists
        SELECT profile_version INTO v_current_version
        FROM user_profiles WHERE user_id = p_user_id;
        
        IF v_current_version IS NULL THEN
            RETURN QUERY SELECT FALSE, 0, 'User profile not found'::TEXT;
        ELSE
            RETURN QUERY SELECT FALSE, v_current_version, 
                'Version mismatch: expected ' || p_expected_version || 
                ', current is ' || v_current_version;
        END IF;
    ELSE
        -- Success - return new version
        SELECT profile_version INTO v_current_version
        FROM user_profiles WHERE user_id = p_user_id;
        
        RETURN QUERY SELECT TRUE, v_current_version, NULL::TEXT;
    END IF;
END;
$$;

-- =============================================================================
-- RPC Function: Increment Access Count (for memory restoration)
-- =============================================================================

CREATE OR REPLACE FUNCTION touch_archive_memory(p_memory_id BIGINT)
RETURNS VOID
LANGUAGE sql
AS $$
    UPDATE archive_memories
    SET 
        last_accessed = NOW(),
        access_count = access_count + 1
    WHERE id = p_memory_id;
$$;

-- =============================================================================
-- Trigger: Auto-update last_updated timestamp
-- =============================================================================

CREATE OR REPLACE FUNCTION update_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_last_updated ON user_profiles;
CREATE TRIGGER trigger_update_last_updated
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_last_updated();
