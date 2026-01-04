# 🧠 Super Memory 3.0 - Complete Documentation

Aura's memory system acts as a **Personal Executive Assistant/Secretary**, building a structured, evolving profile of the user.

---

## 🏗️ Architecture: The 3-Tier Model

| Tier | Name | Purpose | Speed |
|------|------|---------|-------|
| 🔥 **1** | Hot (Cheat Sheet) | Injected into every LLM call | < 10ms |
| 🌡️ **2** | Warm (Profile) | Active facts (max 5/category) | Fast |
| ❄️ **3** | Cold (Archive) | Everything else, searchable | Semantic |

### Tier 1: Fast Context
*   ~500 word summary auto-generated from Tier 2
*   Location: `user_profiles.tier_1_summary`

### Tier 2: Warm Profile
*   Structured JSON with categories:
    *   `identity` - Name, job, projects
    *   `preferences` - Beverages, meeting times
    *   `core_beliefs` - Work priorities
    *   `behavioral_patterns` - Routines
*   Location: `user_profiles.long_term_profile`
*   **Limit**: 2000 words total (no per-category caps)
*   **Control**: Relevance-based demotion + smart pruning

### Tier 3: Cold Archive
*   Vector embeddings for semantic search (`pgvector`)
*   Location: `archive_memories` table
*   Infinite storage

---

## 🔄 Data Flow

### Step 1: Smart Filter
```
User message → Should analyze?
  - Skip: "hi", "thanks", short commands
  - Analyze: Personal pronouns, preferences, calendar data
```

### Step 2: Freudian Analysis
LLM extracts facts using Secretary Persona:
```json
{
  "conscious": ["Name is Harshit"],
  "rational": ["Prefers no meetings before 10am"],
  "subconscious": ["Works out at 6pm"],
  "emotional": "neutral"
}
```

**Sarcasm filter**: "I love bugs" → Ignored, emotional = "amused"

### Step 3: Add ALL to Profile
All new facts are added first (nothing lost):
```
profile.identity += ["Name is Harshit"]
profile.preferences += ["Went to Goa last year"]
```

### Step 4: Relevance Agent Scans
LLM scans entire profile and identifies LOW priority facts:
```
"Name is Harshit" → HIGH → KEEP
"Went to Goa" → LOW → DEMOTE to Archive
```

### Step 5: Smart Pruning (2000 word limit)
When profile exceeds limit:
1. LLM reviews all facts for relevance
2. **Irrelevant** → Archived
3. **Relevant** → Kept
4. Fallback: Oldest-first if LLM fails

---

## 🔀 Bi-directional Flow

```
Profile (Tier 2)  ──DEMOTE──►  Archive (Tier 3)
                  ◄──PROMOTE──
```

*   **Demote**: Low-priority facts move from Profile → Archive
*   **Promote**: When archived fact is recalled and deemed important → Profile

---

## 💾 Database Schema

### `user_profiles`
| Column | Type | Description |
|--------|------|-------------|
| `user_id` | TEXT PK | Unique ID |
| `tier_1_summary` | TEXT | Hot summary |
| `long_term_profile` | JSONB | Tier 2 profile |
| `profile_version` | INT | Optimistic lock |

### `archive_memories`
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID PK | Unique ID |
| `user_id` | TEXT | FK |
| `content` | TEXT | The fact |
| `embedding` | VECTOR(768) | For search |
| `layer_tag` | TEXT | Category |

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/memory/profile/{id}` | Get profile |
| POST | `/api/v1/memory/profile/{id}/create` | Create profile |
| POST | `/api/v1/memory/analyze` | Manual analysis |
| POST | `/api/v1/memory/search` | Archive search |
| DELETE | `/api/v1/memory/profile/{id}/reset` | Delete all data |

---

## 🧪 Testing

Use **Aura Tester** (`src/static/aura-tester.html`):
1. Chat → Watch memory update
2. View profile JSON
3. Search archive
4. Delete Profile button

---

## 📁 Key Files

| File | Role |
|------|------|
| `memory_service.py` | Business logic |
| `memory_repository.py` | Database ops |
| `memory_schemas.py` | Pydantic models |
| `routers/memory.py` | API endpoints |
| `adapters/` | Vector store adapters |

---

## 🔌 Adapter Architecture (Portable Vector Store)

Switch between Supabase (dev) and Vertex AI (prod) via environment variable.

### File Structure
```
src/services/adapters/
├── __init__.py
├── base.py              # VectorStoreAdapter ABC
├── supabase_adapter.py  # pgvector implementation
├── vertex_adapter.py    # Vertex AI Matching Engine (stub)
└── factory.py           # get_vector_adapter()
```

### Environment Variables
```bash
# Dev (Supabase/pgvector)
VECTOR_STORE_PROVIDER=supabase

# Prod (Vertex AI)
VECTOR_STORE_PROVIDER=vertex_ai
GCP_PROJECT_ID=project-aura-prod
GCP_LOCATION=us-central1
VERTEX_INDEX_ENDPOINT=projects/.../endpoints/...
```

### Reindex Command
```bash
# Rebuild vectors after switching providers
python -m scripts.reindex_archive --all --force
```

