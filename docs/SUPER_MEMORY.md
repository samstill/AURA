# 🧠 Multi-Layered Memory System (Super Memory 3.0)

Aura's memory system is designed to act as a **Personal Executive Assistant/Secretary**. It moves beyond simple "chat history" to build a structured, evolving psychological and logistical profile of the user.

## 🏗️ Architecture: The 3-Tier Model

The system organizes memory into three distinct tiers based on access speed and permanence:

### Tier 1: Fast Context (Hot Memory)
*   **Purpose**: Immediate context injection for every LLM call.
*   **Format**: A concise, ~500 word "Cheat Sheet" summary.
*   **Location**: `user_profiles.tier_1_summary` (PostgreSQL).
*   **Access**: < 10ms. Injected into system prompts.

### Tier 2: Warm Profile (Structured Memory)
*   **Purpose**: The "Active State" of the user. Explicit lists of known facts.
*   **Format**: Structured JSON (Secretary-focused).
*   **Components**:
    *   **Identity**: Name, job title, projects, team members.
    *   **Preferences**: Meeting times, comms style, beverages.
    *   **Work Patterns**: Decision styles, priorities.
    *   **Routines**: Daily schedule, gym times, deep work blocks.
    *   **Emotional State**: Current vibe (e.g., "Amused", "Neutral").
*   **Location**: `user_profiles.long_term_profile` (PostgreSQL JSONB).

### Tier 3: Cold Archive (Deep Memory)
*   **Purpose**: Infinite history of every meaningful interaction.
*   **Format**: Vector Embeddings + Raw Text.
*   **Mechanism**: `pgvector` semantic search.
*   **Location**: `archive_memories` table.
*   **Retrieval**: On-demand via "Deep Recall" (triggered by complex queries).

---

## 🔄 Data Flow & Analysis Pipeline

### 1. Smart Filtering
Not every message needs analysis. To save costs and reduce noise:
*   **Filter Logic**: `_should_analyze_with_llm`
*   **Skips**: Short greetings ("hi"), simple commands.
*   **Analyzes**: Messages with personal pronouns, emotional words, or **Calendar Results**.
*   **Nuance**: Checks *both* User Input and AI Response (e.g., extracting "Work Routine" from a calendar query result).

### 2. "Freudian" Analysis (Secretary Persona)
An LLM agent analyzes the conversation with a specific **Secretary Persona**:
*   **Role**: Executive Assistant.
*   **Goal**: Extract logistical & preference data.
*   **Rules**:
    *   ✅ **Extract**: Project names, specific times, stated preferences.
    *   ❌ **Ignore**: Temporary emotional outbursts (unless explicit).
    *   ⚠️ **Sarcasm Detection**: Explicitly warned to identify jokes (e.g., "walks with bugs") and label as `amused` rather than a factual preference.

### 3. Intelligent Consolidation
New facts aren't just appended; they are **merged**:
*   **Deduplication**: "My name is Harshit" + "I am Harshit" → "User's name is Harshit".
*   **Conflict Resolution**: Newer facts override older ones (e.g., changing coffee preference).
*   **Limit**: Max 5 key items per category to keep Tier 2 lean.

### 4. Background Integration
Memory analysis runs:
1.  **Post-Turn**: After a chat response is sent.
2.  **Post-Task**: When a background task (e.g., "Check Calendar") completes.

---

## 💾 Database Schema

### `user_profiles`
| Column | Type | Description |
|--------|------|-------------|
| `user_id` | TEXT (PK) | Unique user identifier. |
| `tier_1_summary` | TEXT | Generated summary for prompts. |
| `long_term_profile` | JSONB | The structured JSON profile (Tier 2). |
| `profile_version` | INT | For optimistic concurrency control. |

### `archive_memories`
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Unique ID. |
| `user_id` | TEXT | Foreign key. |
| `content` | TEXT | The actual memory/fact. |
| `embedding` | VECTOR(768) | Gemini embedding for semantic search. |
| `layer_tag` | TEXT | Category (identity, preference, etc.). |

---

## 🔌 API Reference

### Get Profile
`GET /api/v1/memory/profile/{user_id}`
Returns the full Tier 2 JSON profile.

### Manual Analysis
`POST /api/v1/memory/analyze`
Trigger an analysis run on a text snippet manually.

### Create Profile
`POST /api/v1/memory/profile/{user_id}/create`
Initialize a new profile.

### Archive Search
`POST /api/v1/memory/search`
Perform valid semantic search on Tier 3.

### Reset Memory
`DELETE /api/v1/memory/profile/{user_id}/reset`
**Dangerous**: Wipes `user_profiles` and `archive_memories` for the user.

---

## 🧪 Testing

Use the **Aura Tester** (`src/static/aura-tester.html`) to:
1.  Chat and see Memory updates in real-time.
2.  View the JSON profile.
3.  Search the Cold Archive.
4.  **Delete Profile** button available for resetting state.
