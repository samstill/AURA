# CLAUDE.md

Guidance for AI assistants (Claude Code and others) working in the **AURA** repository.
Read this before making changes. It captures the structure, workflows, and conventions
that are not obvious from any single file.

## What AURA is

AURA ("The World's Fastest AI Secretary" by Encresa) is a latency-optimized AI assistant.
Its defining idea is the **Aura Routing Algorithm / Secretary Protocol**: always acknowledge
the user instantly, stream answers continuously, and offload heavy work asynchronously so the
user never watches a spinner. Keep this philosophy in mind — most backend complexity exists to
serve perceived latency, not raw throughput.

## Monorepo layout

```
AURA/
├── src/                 # FastAPI backend (Python 3.11+) — the core of the system
├── flutter/             # Cross-platform mobile app (Flutter/Dart, Riverpod)
├── packages/            # Encresa SDKs published to pypi / npm / pub.dev
│   ├── encresa_pypi/    #   Python SDK
│   ├── encresa_npm/     #   JavaScript SDK
│   └── encresa_pub/     #   Dart SDK
├── k8s/                 # Kubernetes manifests (auth/, mcp/, deployments, ingress)
├── docs/                # Deep-dive docs (routing, memory, design system, setup)
├── scripts/             # Cluster/auth setup + test helpers
├── admin_console.html   # Standalone debug console served at /admin_console.html
├── dev.sh               # One-command local dev startup (primary entry point)
├── docker-compose.yaml  # Local Postgres (+ services) for dev.sh
├── Dockerfile           # Multi-stage backend image
└── skaffold.yaml        # Kubernetes dev loop (alternative to dev.sh)
```

`docs/` is authoritative for subsystems — consult it before changing behavior:
- `docs/ROUTING_ALGORITHM.md` — the Aura router / Secretary Protocol (v2)
- `docs/SUPER_MEMORY.md` — the 3-tier memory system
- `docs/DESIGN_SYSTEM.md` — Flutter design system / motion language
- `docs/AUTHENTIK_SETUP.md`, `docs/FLUTTER_NATIVE_SETUP.md`, `docs/dev_tts_worker.md`

## Backend (`src/`)

### Running it
The canonical way to run locally is **`./dev.sh`** from the repo root. It:
1. Starts Postgres via docker-compose (skipped if `DATABASE_URL` points at Supabase Cloud).
2. Activates `.venv` (you must create it first: `python3 -m venv .venv && source .venv/bin/activate && pip install -r src/requirements.txt`).
3. Kills stale processes, then launches the **MCP server on :8000** and the **backend API on :30000**.
4. Streams `logs/backend.log` and `logs/mcp.log`.

`skaffold dev` is the alternative Kubernetes-based loop.

> **Working directory matters.** The backend runs with **`src/` as the working directory**
> (`cd src && uvicorn main:app ...`). Imports are rooted at `src/`, i.e. `from config import settings`,
> `from routers import chat`, `from services.llm_service import llm_service` — **not** `from src.routers...`.
> `config.py` loads env from `../.env` (repo root). Run tests and scripts from inside `src/`.

Access points: API `http://localhost:30000`, Swagger `/docs`, admin console `/admin_console.html`,
health `/health`, readiness `/ready`, MCP `http://localhost:8000`.

### Structure & responsibilities
- `main.py` — FastAPI app. A `lifespan` handler initializes services **in dependency order**
  (Authentik → LLM → Database → Calendar DB → Router → ToolRegistry → Orchestrator). Routers are
  registered under `/api/v1/...`. Add new subsystem init here, guarded by try/except that logs a
  warning rather than crashing startup.
- `config.py` — single `Settings` (pydantic-settings) instance exported as `settings`, cached via
  `get_settings()`/`lru_cache`. All configuration and secrets flow through here; add new knobs as typed
  fields with sensible defaults. Never hard-code secrets elsewhere.
- `routers/` — thin HTTP layer (`auth`, `chat`, `voice`, `calendar`, `memory`, `tools`). Request/response
  models are Pydantic `BaseModel`s defined at the top of each file. Auth via the `CurrentUser` dependency
  from `dependencies/auth_dependencies.py`.
- `services/` — all business logic. This is where real work lives.
- `schemas/`, `tools/`, `dependencies/`, `scripts/`, `static/` — support modules.
- `mcp_server/` — a separate FastAPI process (JSON-RPC 2.0 tool executor). Tools register via the
  `@tool` decorator in `mcp_server/sdk.py`; importing a module under `mcp_server/tools/` (github, web,
  utils) triggers registration. Add a tool by writing a decorated function and importing its module in
  `mcp_server/main.py`.

### Key services (the Aura Algorithm)
The request pipeline for chat is orchestrated, not a single LLM call:
- `orchestrator_service.py` — implements the Secretary Protocol: Phase A ingestion + semantic-cache
  check + classification; Phase B parallel staller-stream vs. agent-execution; Phase C stitching with
  soft timeout (`aura_hard_timeout` 1.0s, `aura_grace_period` 0.5s); Phase D async handoff to the analyst.
- `router_service.py` — pure-LLM classifier that picks the execution path (FAST_SOLVER / SECRETARY_PROTOCOL /
  TOOL execution). Sets the `X-Aura-Route` response header (exposed via CORS).
- `llm_service.py` — **multi-provider** adapter. Gemini is optional; OpenAI/Groq/OpenRouter/DeepSeek are
  supported via an OpenAI-compatible `AsyncOpenAI` client. Startup tolerates missing providers. Fast vs.
  smart model split is central — respect it.
- `staller_service.py` (instant acknowledgments), `stitcher_service.py` (seam-free merge),
  `analyst_service.py` (post-hoc processing), `semantic_cache_service.py` (≈0.95 similarity cache hits).
- `agent_service.py` — ReAct-style agent with tool calling; `tool_registry.py` / `tool_manager.py` /
  `mcp_client.py` bridge to the MCP server.
- Memory (Super Memory 3.0): `memory_service.py`, `memory_repository.py` — 3 tiers (Fast Context / Warm
  Profile / Cold Archive) over Postgres + `pgvector`. `qdrant_service.py`, `redis_service.py` optional.
- Integrations: `google_calendar_service.py` + `calendar_tools.py` + `calendar_db_service.py` (aiosqlite),
  `authentik_service.py` (OIDC), `tts_service.py`, `database_service.py` (asyncpg pool).

### Backend conventions
- **Services are module-level singletons.** Each service file ends with `xxx_service = XxxService()`.
  Import and use that instance; don't instantiate services ad hoc.
- Async everywhere (`async def`, asyncpg, httpx/aiohttp). Don't block the event loop.
- Streaming chat endpoints return `StreamingResponse(..., media_type="text/event-stream")` (SSE).
- Logging uses emoji-prefixed messages (`✅`/`⚠️`/`❌`/`🚀`) by existing convention — match it for
  consistency in lifecycle logs.
- Config reads use `getattr(settings, 'name', default)` in some services to stay resilient to missing fields.
- **Never fabricate tool output.** The Aura system prompt mandates reporting tool errors truthfully.

## Flutter app (`flutter/`)

- **State management:** Riverpod 2.x with code generation (`riverpod_annotation`, `@riverpod`).
- **Routing:** `go_router`. **Auth:** `flutter_appauth` (OIDC) + `flutter_secure_storage`.
- **Networking:** `dio` (see `core/api/dio_client.dart`); endpoints in `core/config/api_endpoints.dart`.
- **Serialization:** `freezed` + `json_serializable`.
- **Structure:** feature-first. `lib/core/` holds cross-cutting modules (`api`, `auth`, `config`,
  `design_system`, `router`, `theme`); `lib/features/` holds `chat`, `dashboard`, `splash`. Within a
  feature/module, code is split into `data/`, `domain`, `presentation/` (controllers + screens).
- **Design system:** `core/design_system/` (atoms, motion, theme) — glassmorphic aesthetic, "jelly"
  micro-interactions via `flutter_animate`, haptics. Follow `docs/DESIGN_SYSTEM.md`.

**Generated files** (`*.g.dart`, `*.freezed.dart`) are committed. After editing annotated classes, run
codegen — do **not** hand-edit generated files:
```bash
cd flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Development workflows

### Backend
```bash
./dev.sh                          # full local stack (recommended)
cd src && pytest                  # run tests (from inside src/)
ruff format .                     # format
```
There is currently **no committed pytest/ruff config file and few unit tests** — the main automated
checks are ad hoc scripts under `src/scripts/` and `scripts/` (e.g. `test_voice_backend.py`,
`check_models.py`). If you add tests, place them near the code and run pytest from `src/`.

### Environment
Copy `.env.example` (root) to `.env` and fill keys. `.env` is git-ignored — **never commit secrets**.
Minimum useful config is `GOOGLE_API_KEY` (or any one LLM provider key); calendar/TTS/memory features
need their respective keys. In Kubernetes these values come from the `aura-secrets` Secret, not `.env`.

### API surface (v1)
Chat (`/api/v1/chat/...` incl. streaming `/send` & stream endpoints), voice (`/api/v1/voice/...`),
auth (`/api/v1/auth/...`), calendar (`/api/v1/calendar/...`), memory (`/api/v1/memory/...`), tools
(`/api/v1/...`). System: `/`, `/health`, `/ready`.

## Git & contribution conventions

- Commit messages use Conventional-Commit prefixes (`feat:`, `fix:`, …) as seen in history.
- Do **not** create pull requests unless explicitly asked.
- Keep changes scoped; match the surrounding code's style, comment density, and section-comment banners
  (the `# ---- ... ----` dividers) already used throughout `src/`.
- License is **proprietary** (© Encresa) — treat the codebase accordingly.

## Quick orientation for a new task

1. Backend behavior change → start in `src/services/`, wire HTTP in `src/routers/`, config in `config.py`.
2. Changing how requests are classified/streamed → `router_service.py` + `orchestrator_service.py`
   (read `docs/ROUTING_ALGORITHM.md` first).
3. Adding an LLM provider → `llm_service.py` + provider fields in `config.py`.
4. Adding a tool → `mcp_server/tools/` with `@tool`, register in `mcp_server/main.py`, surface via
   `tool_registry.py`.
5. Memory changes → `memory_service.py` / `memory_repository.py` + `docs/SUPER_MEMORY.md`.
6. Mobile change → `flutter/lib/features/` or `core/`, then run build_runner.
