"""
Memory Service - Business Logic Layer
======================================

Implements the Psychodynamic Memory System business logic.
Orchestrates the Freudian analysis pipeline and profile management.

Architecture:
- Fast Path: Fetch tier1_summary for instant context injection
- Slow Path: Background analysis + profile update with optimistic locking
- Deep Recall: Semantic search in archive with memory restoration
"""

import logging
import asyncio
import json
from typing import Optional, List, Dict, Any
from datetime import datetime

from schemas.memory_schemas import (
    FreudianAnalysis,
    UserProfile,
    UserProfileRecord,
    ArchiveMemory,
    ArchiveSearchResult,
    ProfileMergeResult,
    LayerTag,
    MemoryOperation,
    MemoryOperationAction
)
from services.memory_repository import memory_repository
from config import settings

logger = logging.getLogger(__name__)


class MemoryService:
    """
    Business Logic Layer for Super Memory system.
    
    Implements:
    - Profile management with optimistic concurrency control
    - Freudian analysis merging
    - Profile pruning and archiving
    - Deep recall with memory restoration
    """
    
    # Configuration
    MAX_PROFILE_WORDS = 2000
    MAX_SUMMARY_WORDS = 500
    MAX_RETRY_ATTEMPTS = 3
    ARCHIVE_SIMILARITY_THRESHOLD = 0.75
    
    def __init__(self):
        self.repository = memory_repository
        self._initialized = False
    
    async def initialize(self, pool=None):
        """Initialize the memory service."""
        if pool:
            await self.repository.initialize(pool)
        
        # Load config
        self.MAX_PROFILE_WORDS = getattr(settings, 'memory_profile_max_words', 2000)
        self.ARCHIVE_SIMILARITY_THRESHOLD = getattr(
            settings, 'memory_archive_similarity_threshold', 0.75
        )
        
        self._initialized = True
        logger.info("✅ Memory Service initialized")
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized and self.repository.is_initialized
    
    # =========================================================================
    # Fast Path Operations
    # =========================================================================
    
    async def get_user_context(self, user_id: str) -> str:
        """
        FAST PATH: Get the tier1 summary for LLM context injection.
        
        Called in the hot path - must be fast (<50ms).
        """
        if not self.is_initialized:
            return ""
        
        summary = await self.repository.get_tier1_summary(user_id)
        
        # Track interaction
        asyncio.create_task(self.repository.increment_interaction(user_id))
        
        return summary
    
    async def get_full_profile(self, user_id: str) -> Optional[UserProfileRecord]:
        """Get the complete user profile record."""
        if not self.is_initialized:
            return None
        
        data = await self.repository.get_profile(user_id)
        if not data:
            return None
        
        # Handle long_term_profile - may be str (from JSON) or dict
        ltp = data.get('long_term_profile', {})
        if isinstance(ltp, str):
            import json
            ltp = json.loads(ltp) if ltp else {}
        
        return UserProfileRecord(
            user_id=data['user_id'],
            tier_1_summary=data.get('tier_1_summary', ''),
            long_term_profile=UserProfile(**ltp),
            profile_version=data.get('profile_version', 1),
            created_at=data.get('created_at'),
            last_updated=data.get('last_updated'),
            last_interaction=data.get('last_interaction'),
            total_interactions=data.get('total_interactions', 0),
            word_count=data.get('word_count', 0)
        )
    
    async def ensure_profile_exists(self, user_id: str) -> UserProfileRecord:
        """Ensure a profile exists for the user, creating if necessary."""
        profile = await self.get_full_profile(user_id)
        if profile:
            return profile
        
        # Create new profile
        await self.repository.create_profile(user_id)
        return await self.get_full_profile(user_id)
    
    async def reset_user_memory(self, user_id: str) -> bool:
        """
        Hard reset: Delete all memory profile and archives for a user.
        """
        if not self.is_initialized:
            return False
            
        success = await self.repository.delete_user_data(user_id)
        if success:
            logger.warning(f"⚠️ Reset memory for user {user_id}")
        return success
    
    # =========================================================================
    # Slow Path Operations (Background Processing)
    # =========================================================================
    
    async def update_profile_safely(
        self,
        user_id: str,
        analysis: FreudianAnalysis,
        retry_count: int = 0,
        llm_service=None
    ) -> bool:
        """
        SLOW PATH: Update profile with optimistic locking.
        
        Implements retry logic for race conditions.
        """
        if not self.is_initialized:
            logger.warning("Memory service not initialized")
            return False
        
        if retry_count >= self.MAX_RETRY_ATTEMPTS:
            logger.error(f"Max retries exceeded for user {user_id}")
            return False
        
        try:
            # 1. Fetch current profile
            profile_record = await self.ensure_profile_exists(user_id)
            if not profile_record:
                logger.error(f"Failed to get/create profile for {user_id}")
                return False
            
            current_version = profile_record.profile_version
            current_profile = profile_record.long_term_profile
            
            # 2. Merge new analysis with LLM consolidation
            merge_result = await self._merge_analysis(
                current_profile, 
                analysis,
                user_id,
                llm_service=llm_service
            )
            
            # 3. Generate new summary
            new_summary = merge_result.updated_profile.get_summary(self.MAX_SUMMARY_WORDS)
            
            # 4. Update with version check
            result = await self.repository.update_profile_with_version(
                user_id=user_id,
                tier_1_summary=new_summary,
                long_term_profile=merge_result.updated_profile.model_dump(),
                expected_version=current_version
            )
            
            if result.get('success'):
                logger.info(f"✅ Profile updated for {user_id} (v{result.get('new_version')})")
                
                # Archive pruned facts if any
                if merge_result.archived_facts:
                    await self._archive_facts(merge_result.archived_facts)
                
                return True
            else:
                # Version mismatch - retry
                logger.warning(
                    f"Version conflict for {user_id}: {result.get('error_message')}. "
                    f"Retrying ({retry_count + 1}/{self.MAX_RETRY_ATTEMPTS})..."
                )
                await asyncio.sleep(0.1 * (retry_count + 1))  # Exponential backoff
                return await self.update_profile_safely(user_id, analysis, retry_count + 1, llm_service)
                
        except Exception as e:
            logger.error(f"Profile update failed for {user_id}: {e}")
            return False
    
    async def _merge_analysis(
        self,
        profile: UserProfile,
        analysis: FreudianAnalysis,
        user_id: str,
        llm_service=None
    ) -> ProfileMergeResult:
        """
        Merge new Freudian analysis into existing profile using LLM consolidation.
        
        Instead of just appending, this:
        1. Combines new facts with existing profile
        2. Uses LLM to deduplicate semantically similar facts
        3. Resolves contradictions (newer facts win)
        4. Produces a clean, coherent profile
        """
        from services.llm_service import llm_service as default_llm
        llm = llm_service or default_llm
        
        archived_facts = []
        
        # First, collect all new facts
        new_facts = {
            "identity": analysis.conscious[:3] if analysis.conscious else [],
            "preferences": [],
            "core_beliefs": analysis.rational[:3] if analysis.rational else [],
            "behavioral_patterns": analysis.subconscious[:3] if analysis.subconscious else [],
        }
        
        # Categorize conscious facts
        for fact in analysis.conscious:
            if self._is_identity_fact(fact):
                if fact not in new_facts["identity"]:
                    new_facts["identity"].append(fact)
            else:
                new_facts["preferences"].append(fact)
        
        # Add unconscious to core_beliefs
        for fact in (analysis.unconscious or []):
            new_facts["core_beliefs"].append(fact)
        
        # === STEP 1: Add ALL new facts to profile first ===
        for fact in new_facts["identity"]:
            if fact and fact not in profile.identity:
                profile.identity.append(fact)
                logger.info(f"➕ Added to identity: {fact[:50]}...")
        for fact in new_facts["preferences"]:
            if fact and fact not in profile.preferences:
                profile.preferences.append(fact)
                logger.info(f"➕ Added to preferences: {fact[:50]}...")
        for fact in new_facts["core_beliefs"]:
            if fact and fact not in profile.core_beliefs:
                profile.core_beliefs.append(fact)
                logger.info(f"➕ Added to core_beliefs: {fact[:50]}...")
        for fact in new_facts["behavioral_patterns"]:
            if fact and fact not in profile.behavioral_patterns:
                profile.behavioral_patterns.append(fact)
                logger.info(f"➕ Added to behavioral_patterns: {fact[:50]}...")
        
        # === STEP 2: Scan entire profile and demote low-priority facts ===
        try:
            relevance = await self._evaluate_profile_relevance(
                profile, {}, user_id, llm  # Empty new_facts since already added
            )
            
            # Demote low-priority facts to archive
            if relevance.get("demote_to_archive"):
                profile = await self._demote_facts_to_archive(
                    profile, relevance["demote_to_archive"], user_id
                )
                archived_facts.extend([
                    ArchiveMemory(user_id=user_id, content=item.get("fact", ""))
                    for item in relevance["demote_to_archive"]
                ])
                logger.info(f"📦 Demoted {len(relevance['demote_to_archive'])} low-priority facts to archive")
            
            logger.info("✅ Memory flow complete: Add first, then demote")
            
        except Exception as e:
            logger.warning(f"Relevance scan failed (facts still added): {e}")
        
        # Emotional baseline
        if analysis.emotional and analysis.emotional != "neutral":
            profile.emotional_baseline = analysis.emotional
        
        # Check capacity and prune if needed
        was_pruned = False
        if profile.is_over_capacity(self.MAX_PROFILE_WORDS):
            profile, pruned = await self._prune_profile(profile, user_id)
            archived_facts.extend(pruned)
            was_pruned = True
        
        return ProfileMergeResult(
            updated_profile=profile,
            archived_facts=archived_facts,
            was_pruned=was_pruned,
            new_word_count=profile.word_count()
        )
    
    async def _prune_profile(
        self,
        profile: UserProfile,
        user_id: str
    ) -> tuple[UserProfile, List[ArchiveMemory]]:
        """
        Smart pruning: LLM checks if oldest facts are still relevant.
        
        If relevant: Move to end of list (refresh)
        If not relevant: Archive
        """
        from services.llm_service import llm_service
        
        archived = []
        target_words = int(self.MAX_PROFILE_WORDS * 0.8)
        
        # Collect all pruneable facts with their category
        pruneable = []
        for fact in profile.preferences:
            pruneable.append({"category": "preferences", "fact": fact})
        for fact in profile.behavioral_patterns:
            pruneable.append({"category": "behavioral_patterns", "fact": fact})
        for fact in profile.core_beliefs:
            pruneable.append({"category": "core_beliefs", "fact": fact})
        
        if not pruneable:
            return profile, archived
        
        # Ask LLM which facts are no longer relevant
        try:
            irrelevant = await self._identify_irrelevant_facts(pruneable, llm_service)
            
            # Process irrelevant facts (archive them)
            for item in irrelevant:
                category = item.get("category", "")
                fact = item.get("fact", "")
                
                target_list = {
                    'preferences': profile.preferences,
                    'behavioral_patterns': profile.behavioral_patterns,
                    'core_beliefs': profile.core_beliefs,
                }.get(category)
                
                if target_list and fact in target_list:
                    target_list.remove(fact)
                    archived.append(ArchiveMemory(
                        user_id=user_id,
                        content=fact,
                        layer_tag=LayerTag.PREFERENCE,
                        source_category=category
                    ))
                    logger.info(f"🗑️ Smart prune: archived '{fact[:40]}...'")
            
            # If still over capacity, fall back to oldest-first
            while profile.word_count() > target_words:
                if len(profile.preferences) > 3:
                    pruned = profile.preferences.pop(0)
                elif len(profile.behavioral_patterns) > 3:
                    pruned = profile.behavioral_patterns.pop(0)
                elif len(profile.core_beliefs) > 2:
                    pruned = profile.core_beliefs.pop(0)
                else:
                    break
                    
                archived.append(ArchiveMemory(
                    user_id=user_id,
                    content=pruned,
                    layer_tag=LayerTag.PREFERENCE,
                    source_category="fallback"
                ))
                
        except Exception as e:
            logger.warning(f"Smart pruning failed, using oldest-first: {e}")
            # Fallback to oldest-first
            while profile.word_count() > target_words:
                if len(profile.preferences) > 3:
                    pruned = profile.preferences.pop(0)
                    archived.append(ArchiveMemory(user_id=user_id, content=pruned, layer_tag=LayerTag.PREFERENCE))
                elif len(profile.behavioral_patterns) > 3:
                    pruned = profile.behavioral_patterns.pop(0)
                    archived.append(ArchiveMemory(user_id=user_id, content=pruned, layer_tag=LayerTag.SUBCONSCIOUS))
                else:
                    break
        
        return profile, archived
    
    async def _identify_irrelevant_facts(
        self,
        facts: List[dict],
        llm_service
    ) -> List[dict]:
        """
        Ask LLM which facts are no longer secretary-relevant.
        """
        system_prompt = """You are AURA's memory curator.

Review these facts and identify which are NO LONGER RELEVANT:

Irrelevant = 
- Outdated information (old preferences that may have changed)
- One-time events (trips, meetings from the past)
- Temporary states that are no longer true

Still Relevant = 
- Ongoing preferences (coffee, meeting times)
- Current job/projects
- Regular routines

Return JSON: {"irrelevant": [{"category": "...", "fact": "..."}]}
Return empty if all are still relevant: {"irrelevant": []}"""

        prompt = f"Facts to review: {json.dumps(facts)}"

        try:
            response = llm_service.get_reflex_response(
                user_query=prompt,
                system_prompt=system_prompt,
                include_model_header=False
            )
            
            full_response = ""
            async for chunk in response:
                full_response += chunk
            
            json_start = full_response.find('{')
            json_end = full_response.rfind('}') + 1
            
            if json_start >= 0 and json_end > json_start:
                data = json.loads(full_response[json_start:json_end])
                return data.get("irrelevant", [])
            
            return []
        except Exception as e:
            logger.error(f"Irrelevant fact detection failed: {e}")
            return []
    
    async def _archive_facts(self, facts: List[ArchiveMemory]) -> None:
        """Archive pruned facts to cold storage."""
        for fact in facts:
            try:
                await self.repository.insert_archive_memory(
                    user_id=fact.user_id,
                    content=fact.content,
                    layer_tag=fact.layer_tag.value,
                    source_category=fact.source_category
                )
                logger.debug(f"Archived: {fact.content[:50]}...")
            except Exception as e:
                logger.error(f"Failed to archive fact: {e}")
    
    def _is_identity_fact(self, fact: str) -> bool:
        """Check if a fact is about identity (name, role, etc.)."""
        identity_keywords = [
            "name is", "i am", "i'm", "i work", "my job",
            "i live", "my age", "years old", "born in"
        ]
        return any(kw in fact.lower() for kw in identity_keywords)
    
    def _is_preference_fact(self, fact: str) -> bool:
        """Check if a fact is a preference."""
        pref_keywords = [
            "like", "love", "prefer", "hate", "dislike",
            "favorite", "favourite", "enjoy", "can't stand"
        ]
        return any(kw in fact.lower() for kw in pref_keywords)
    
    async def _evaluate_profile_relevance(
        self,
        profile: UserProfile,
        new_facts: dict,
        user_id: str,
        llm_service
    ) -> dict:
        """
        Scan profile for low-priority facts that should be demoted to archive.
        
        Called AFTER new facts are added. Identifies what to demote.
        """
        system_prompt = """You are AURA's memory curator - a personal AI secretary.

Scan the profile and identify LOW PRIORITY facts to move to archive.

HIGH PRIORITY (KEEP in profile):
- Identity: Name, job, projects
- Scheduling: Meeting preferences, work hours
- Preferences: Beverages, communication style
- Routines: Regular schedule patterns

LOW PRIORITY (DEMOTE to archive):
- One-time events ("went to Goa", "visited Paris")
- Old/outdated information
- Historical trivia not affecting scheduling
- Non-work opinions

Return ONLY facts to demote as JSON:
{"demote_to_archive": [{"category": "preferences", "fact": "Visited Goa last year"}]}

If nothing to demote, return: {"demote_to_archive": []}"""

        prompt = f"""CURRENT PROFILE:
- identity: {profile.identity}
- preferences: {profile.preferences}
- core_beliefs: {profile.core_beliefs}
- behavioral_patterns: {profile.behavioral_patterns}

Which facts are LOW PRIORITY and should be moved to archive? Return JSON."""

        try:
            response = llm_service.get_reflex_response(
                user_query=prompt,
                system_prompt=system_prompt,
                include_model_header=False
            )
            
            full_response = ""
            async for chunk in response:
                full_response += chunk
            
            # Parse JSON
            json_start = full_response.find('{')
            json_end = full_response.rfind('}') + 1
            
            if json_start >= 0 and json_end > json_start:
                json_str = full_response[json_start:json_end]
                data = json.loads(json_str)
                
                demotions = data.get("demote_to_archive", [])
                logger.info(f"📊 Relevance scan: {len(demotions)} facts to demote")
                return {"demote_to_archive": demotions}
            
            logger.warning("No valid JSON in relevance response")
            return {"demote_to_archive": []}
            
        except Exception as e:
            logger.error(f"Relevance evaluation failed: {e}")
            return {"demote_to_archive": []}
    
    async def _demote_facts_to_archive(
        self,
        profile: UserProfile,
        demotions: List[dict],
        user_id: str
    ) -> UserProfile:
        """
        Move demoted facts from profile to archive.
        """
        category_map = {
            'identity': profile.identity,
            'preferences': profile.preferences,
            'core_beliefs': profile.core_beliefs,
            'behavioral_patterns': profile.behavioral_patterns
        }
        
        for item in demotions:
            category = item.get('category', '')
            fact = item.get('fact', '')
            
            if not category or not fact:
                continue
            
            target_list = category_map.get(category)
            if target_list and fact in target_list:
                # Remove from profile
                target_list.remove(fact)
                
                # Add to archive
                try:
                    await self.repository.insert_archive_memory(
                        user_id=user_id,
                        content=fact,
                        layer_tag="demoted",
                        source_category=category
                    )
                    logger.info(f"📦 Demoted to archive: {fact[:50]}...")
                except Exception as e:
                    logger.error(f"Failed to archive demoted fact: {e}")
        
        return profile
    
    async def _add_facts_to_archive(
        self,
        facts: List[dict],
        user_id: str
    ):
        """
        Add low-priority new facts directly to archive.
        """
        for item in facts:
            category = item.get('category', 'general')
            fact = item.get('fact', '')
            
            if not fact:
                continue
            
            try:
                await self.repository.insert_archive_memory(
                    user_id=user_id,
                    content=fact,
                    layer_tag="low_priority",
                    source_category=category
                )
                logger.info(f"📥 Added to archive (low priority): {fact[:50]}...")
            except Exception as e:
                logger.error(f"Failed to add to archive: {e}")
    
    async def _get_profile_operations(
        self,
        profile: UserProfile,
        new_facts: dict,
        llm_service
    ) -> List[MemoryOperation]:
        """
        Use LLM to determine surgical operations needed to update the profile.
        
        Returns a list of ADD/UPDATE/REMOVE operations instead of a full new profile.
        """
        system_prompt = """You are AURA's memory surgeon. Your job is to surgically update a user profile.

Given the CURRENT profile and NEW facts, output a JSON list of operations.

OPERATION TYPES:
- {"action": "ADD", "category": "...", "fact": "..."} - Add a new fact
- {"action": "UPDATE", "category": "...", "old_fact": "...", "fact": "..."} - Replace an existing fact
- {"action": "REMOVE", "category": "...", "fact": "..."} - Remove an outdated/contradicted fact

CATEGORIES: identity, preferences, core_beliefs, behavioral_patterns

RULES:
1. ADD only genuinely new information not already in profile
2. UPDATE when a new fact refines/contradicts an existing one (include old_fact)
3. REMOVE when something is explicitly negated ("don't like X anymore")
4. If no changes needed, return: {"operations": []}
5. Deduplicate: Don't add if similar fact exists
6. Max 5 items per category - if adding would exceed, also REMOVE oldest

Return ONLY valid JSON: {"operations": [...]}"""

        prompt = f"""CURRENT PROFILE:
- identity: {profile.identity[:5]}
- preferences: {profile.preferences[:5]}
- core_beliefs: {profile.core_beliefs[:5]}
- behavioral_patterns: {profile.behavioral_patterns[:5]}

NEW FACTS TO INTEGRATE:
- identity: {new_facts.get('identity', [])}
- preferences: {new_facts.get('preferences', [])}
- core_beliefs: {new_facts.get('core_beliefs', [])}
- behavioral_patterns: {new_facts.get('behavioral_patterns', [])}

What operations are needed? Return JSON."""

        try:
            response = llm_service.get_reflex_response(
                user_query=prompt,
                system_prompt=system_prompt,
                include_model_header=False
            )
            
            full_response = ""
            async for chunk in response:
                full_response += chunk
            
            # Parse JSON
            json_start = full_response.find('{')
            json_end = full_response.rfind('}') + 1
            
            if json_start >= 0 and json_end > json_start:
                json_str = full_response[json_start:json_end]
                data = json.loads(json_str)
                
                operations = []
                for op_data in data.get('operations', []):
                    try:
                        op = MemoryOperation(
                            action=MemoryOperationAction(op_data.get('action', 'ADD')),
                            category=op_data.get('category', 'identity'),
                            fact=op_data.get('fact', ''),
                            old_fact=op_data.get('old_fact')
                        )
                        operations.append(op)
                    except Exception as e:
                        logger.warning(f"Skipping invalid operation: {op_data} - {e}")
                
                logger.info(f"🔧 Got {len(operations)} profile operations")
                return operations
            
            logger.warning("No valid JSON in operations response")
            return []
            
        except Exception as e:
            logger.error(f"Profile operations failed: {e}")
            return []
    
    def _apply_operations(
        self,
        profile: UserProfile,
        operations: List[MemoryOperation]
    ) -> UserProfile:
        """
        Apply surgical operations to the profile.
        
        Executes ADD, UPDATE, REMOVE operations on the appropriate categories.
        """
        category_map = {
            'identity': profile.identity,
            'preferences': profile.preferences,
            'core_beliefs': profile.core_beliefs,
            'behavioral_patterns': profile.behavioral_patterns
        }
        
        for op in operations:
            target_list = category_map.get(op.category)
            if target_list is None:
                logger.warning(f"Unknown category: {op.category}")
                continue
            
            if op.action == MemoryOperationAction.ADD:
                # Check for duplicates before adding
                if op.fact not in target_list:
                    target_list.append(op.fact)
                    logger.debug(f"➕ ADD to {op.category}: {op.fact[:50]}...")
                    # No item cap - rely on relevance-based demotion + 2000 word smart pruning
            
            elif op.action == MemoryOperationAction.UPDATE:
                # Find and replace old fact
                if op.old_fact and op.old_fact in target_list:
                    idx = target_list.index(op.old_fact)
                    target_list[idx] = op.fact
                    logger.debug(f"✏️ UPDATE {op.category}: '{op.old_fact[:30]}' -> '{op.fact[:30]}'")
                else:
                    # Old fact not found, just add the new one
                    if op.fact not in target_list:
                        target_list.append(op.fact)
                        logger.debug(f"➕ UPDATE->ADD to {op.category}: {op.fact[:50]}...")
            
            elif op.action == MemoryOperationAction.REMOVE:
                if op.fact in target_list:
                    target_list.remove(op.fact)
                    logger.debug(f"➖ REMOVE from {op.category}: {op.fact[:50]}...")
        
        logger.info(f"✅ Applied {len(operations)} operations to profile")
        return profile
    
    # =========================================================================
    # Deep Recall Operations
    # =========================================================================
    
    async def deep_recall(
        self,
        query: str,
        user_id: str,
        restore_to_profile: bool = True
    ) -> List[ArchiveSearchResult]:
        """
        Search the archive for relevant memories.
        
        Triggered when:
        - User says "Remember when...", "I told you before..."
        - Context gap detected (LTM has no answer but query implies history)
        
        Args:
            query: User's query
            user_id: User ID
            restore_to_profile: If True, restore found memories to active profile
        """
        if not self.is_initialized:
            return []
        
        logger.info(f"🔍 Deep recall triggered for: {query[:50]}...")
        
        results = await self.repository.search_archive(
            query=query,
            user_id=user_id,
            match_threshold=self.ARCHIVE_SIMILARITY_THRESHOLD,
            match_count=5
        )
        
        if not results:
            logger.info("❌ No archive matches found")
            return []
        
        search_results = [
            ArchiveSearchResult(
                id=r['id'],
                content=r['content'],
                similarity=r['similarity'],
                layer_tag=r['layer_tag'],
                archived_at=r.get('archived_at')
            )
            for r in results
        ]
        
        logger.info(f"✅ Found {len(search_results)} archived memories")
        
        # Touch accessed memories
        for result in search_results:
            await self.repository.touch_memory(result.id)
        
        # Optionally restore to profile
        if restore_to_profile and search_results:
            await self._restore_memories(user_id, search_results[:2])  # Top 2
        
        return search_results
    
    async def _restore_memories(
        self,
        user_id: str,
        memories: List[ArchiveSearchResult]
    ) -> None:
        """Restore retrieved memories to active profile."""
        try:
            profile_record = await self.get_full_profile(user_id)
            if not profile_record:
                return
            
            profile = profile_record.long_term_profile
            
            for memory in memories:
                # Add to appropriate section based on layer_tag
                if memory.layer_tag == 'preference':
                    if memory.content not in profile.preferences:
                        profile.preferences.insert(0, memory.content)
                elif memory.layer_tag == 'project':
                    if memory.content not in profile.active_projects:
                        profile.active_projects.insert(0, memory.content)
                elif memory.layer_tag in ['conscious', 'fact']:
                    if memory.content not in profile.identity:
                        profile.identity.insert(0, memory.content)
                else:
                    # Default to preferences
                    if memory.content not in profile.preferences:
                        profile.preferences.insert(0, memory.content)
            
            # Update profile
            new_summary = profile.get_summary(self.MAX_SUMMARY_WORDS)
            await self.repository.update_profile_with_version(
                user_id=user_id,
                tier_1_summary=new_summary,
                long_term_profile=profile.model_dump(),
                expected_version=profile_record.profile_version
            )
            
            logger.info(f"✅ Restored {len(memories)} memories to profile")
            
        except Exception as e:
            logger.error(f"Memory restoration failed: {e}")
    
    # =========================================================================
    # Freudian Analysis Integration
    # =========================================================================
    
    async def analyze_and_update(
        self,
        user_id: str,
        user_text: str,
        ai_response: str,
        llm_service
    ) -> bool:
        """
        Full Freudian pipeline: Analyze interaction and update profile.
        
        This is the main entry point for background processing.
        """
        try:
            # 0. Pre-filter: Use smart filter that checks BOTH user text AND AI response
            should_analyze = await self._should_analyze_with_llm(user_text, ai_response, llm_service)
            if not should_analyze:
                logger.debug(f"Skipping analysis: no personal info detected")
                return True
            
            # 1. Run Freudian analysis on BOTH user text and AI response
            analysis = await self._run_freudian_analysis(
                user_text, ai_response, llm_service
            )
            
            if analysis.is_empty():
                logger.debug("Analysis yielded no insights, skipping update")
                return True
            
            # 2. Update profile with LLM consolidation
            return await self.update_profile_safely(user_id, analysis, llm_service=llm_service)
            
        except Exception as e:
            logger.error(f"Freudian pipeline failed: {e}")
            return False
    
    def _should_analyze(self, user_text: str) -> bool:
        """
        Pre-filter to determine if a message is worth analyzing.
        
        Skip routine/transactional messages, only analyze personal info.
        """
        text_lower = user_text.lower()
        
        # Skip if too short (likely a command)
        if len(user_text) < 10:
            return False
        
        # Skip simple greetings/farewells only
        simple_greetings = [
            "hello", "hi", "hey", "thanks", "thank you", "bye", "goodbye",
            "ok", "okay", "sure", "yes", "no", "cool", "great"
        ]
        
        # Only skip if the ENTIRE message is just a greeting
        if text_lower.strip() in simple_greetings:
            return False
        
        # Otherwise, analyze - even calendar requests might have context
        return True
    
    async def _should_analyze_with_llm(
        self, 
        user_text: str, 
        ai_response: str,
        llm_service
    ) -> bool:
        """
        Use a fast, cheap LLM call to determine if content has personal info.
        
        Checks BOTH user message AND AI response (e.g., calendar results).
        """
        # Quick keyword pre-filter for obvious skips
        combined = (user_text + " " + ai_response).lower()
        
        # If it contains personal indicators, definitely analyze
        personal_indicators = [
            "my name", "i am", "i'm", "i like", "i love", "i hate", 
            "i work", "i live", "my job", "prefer", "coffee", "tea"
        ]
        if any(ind in combined for ind in personal_indicators):
            return True
        
        # If it's just a calendar command with no personal info, skip
        if len(user_text) < 30 and len(ai_response) < 100:
            return False
        
        # For longer responses (like calendar results), analyze
        return True
    
    async def _run_freudian_analysis(
        self,
        user_text: str,
        ai_response: str,
        llm_service
    ) -> FreudianAnalysis:
        """
        Extract 5 layers of meaning from conversation.
        
        Uses LLM with structured output for reliable JSON.
        """
        system_prompt = """You are AURA's memory system - a personal AI secretary/executive assistant.

Your job is to build a profile that helps a secretary serve their employer better.

EXTRACT SECRETARY-RELEVANT FACTS ONLY:

1. CONSCIOUS (Identity & Work):
   - Name, job title, company/projects they work on
   - Team members, clients, or people they mention
   - Work locations or time zones

2. RATIONAL (Work Preferences):
   - Preferred meeting times ("no meetings before 10am")
   - Communication preferences ("prefer Slack over email")
   - Decision-making patterns

3. SUBCONSCIOUS (Routines & Habits):
   - Daily routines visible from calendar (workout at 6pm, lunch at 1pm)
   - Work patterns (deep work mornings, meetings afternoons)
   - Project priorities from schedule frequency

4. UNCONSCIOUS: LEAVE EMPTY (not secretary-relevant)

5. EMOTIONAL: Only if they explicitly state stress/excitement about work

SECRETARY FOCUS:
- DO extract: work schedule patterns, project names, meeting preferences, beverage preferences (for offering)
- DO NOT extract: psychological analysis, impatience, personality disorders
- FILTER SARCASM/JOKES: If user says "walks with bugs" or "married to my job", do NOT take literally.
  - If user is joking/sarcastic, set emotional state to "amused" but DO NOT add fake facts.
- Calendar data = valuable (shows routines, projects, priorities)

Return ONLY valid JSON:
{
    "conscious": ["Name is X", "Works on Project Y"],
    "rational": ["Prefers no meetings before 10am"],
    "subconscious": ["Works out at 6pm daily"],
    "unconscious": [],
    "emotional": "neutral"
}"""

        prompt = f"""USER message: {user_text}

ASSISTANT response: {ai_response[:500]}

Extract facts about the USER:
- From their message (explicit statements)
- From calendar/schedule data (their routines, work patterns, project names)

Only extract USER facts, not app behavior. Return empty lists if nothing personal found."""

        try:
            # Use the fast model for analysis (async generator - don't await)
            response = llm_service.get_reflex_response(
                user_query=prompt,
                system_prompt=system_prompt,
                include_model_header=False
            )
            
            # Collect full response from async generator
            full_response = ""
            async for chunk in response:
                full_response += chunk

            
            # Parse JSON
            # Find JSON in response
            json_start = full_response.find('{')
            json_end = full_response.rfind('}') + 1
            
            if json_start >= 0 and json_end > json_start:
                json_str = full_response[json_start:json_end]
                data = json.loads(json_str)
                return FreudianAnalysis(**data)
            
            logger.warning("No valid JSON found in analysis response")
            return FreudianAnalysis()
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse analysis JSON: {e}")
            return FreudianAnalysis()
        except Exception as e:
            logger.error(f"Freudian analysis failed: {e}")
            return FreudianAnalysis()


# Singleton instance
memory_service = MemoryService()
