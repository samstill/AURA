<![CDATA[<div align="center">

<img src="assets/logo.png" alt="AURA Logo" width="200"/>

# 🌟 AURA

### **The World's Fastest AI Secretary by Encresa**

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

*A "Digital Body Double" that learns to mimic you, equipped with a Hybrid Brain for split-second reflexes and a Supermemory for infinite context retention.*

</div>

---

## ✨ Features

- 🧠 **Hybrid AI Brain** — Split-second reflexes with deep reasoning via Gemini LLM
- 🛠️ **Agentic Skill Store** — Dynamically load and execute tools via MCP protocol
- 🎤 **Voice Interface** — Natural voice interaction with Kokoro/ElevenLabs TTS
- 💬 **Intelligent Chat** — Context-aware conversations with semantic routing
- 🔐 **Secure Authentication** — OAuth2/OIDC via Authentik IDP
- 📱 **Cross-Platform** — Native mobile apps for iOS and Android
- ☁️ **Cloud-Native** — Kubernetes-first architecture with Skaffold dev loop

---

## 🏗️ Architecture

| Layer | Technology | Strategy |
|-------|------------|----------|
| **Compute** | Kubernetes (Minikube) | Local development via dev.sh or Skaffold |
| **Backend** | Python (FastAPI) | Hot-reloads with uvicorn |
| **AI Engine** | Google Gemini | 1.5 Flash / 2.0 Flash for reasoning |
| **MCP Server** | JSON-RPC 2.0 | Tool execution microservice |
| **Frontend** | Flutter | Cross-platform mobile |
| **Auth** | Authentik | Local OIDC Provider |
| **Database** | PostgreSQL | Supabase (External) / Docker (Local) |
| **Cache** | Redis | Upstash (External) |
| **Vectors** | Qdrant | Qdrant Cloud (External) |

---

## 📁 Project Structure

```
AURA/
├── src/                        # FastAPI Backend
│   ├── main.py                 # Application entry point
│   ├── config.py               # Configuration management
│   ├── routers/                # API endpoints
│   │   ├── auth.py             # Authentication routes
│   │   ├── chat.py             # Chat API
│   │   ├── voice.py            # Voice/TTS API
│   │   └── tools.py            # Skill Store API
│   ├── services/               # Business logic
│   │   ├── agent_service.py    # ReAct agent with tool calling
│   │   ├── orchestrator_service.py  # Streaming orchestrator
│   │   ├── llm_service.py      # Gemini LLM integration
│   │   ├── router_service.py   # Semantic message routing
│   │   ├── tts_service.py      # Text-to-speech (Kokoro/ElevenLabs)
│   │   ├── mcp_client.py       # MCP protocol client
│   │   ├── tool_manager.py     # Tool hydration & management
│   │   ├── database_service.py # Supabase/PostgreSQL client
│   │   ├── qdrant_service.py   # Vector memory service
│   │   ├── redis_service.py    # Redis cache client
│   │   └── authentik_service.py # OIDC authentication
│   ├── mcp_server/             # MCP Server (JSON-RPC 2.0)
│   │   ├── main.py             # MCP server entry point
│   │   ├── sdk.py              # MCP SDK utilities
│   │   └── tools/              # Built-in tools
│   └── dependencies/           # FastAPI dependencies
│
├── flutter/                    # Flutter Mobile App
│   ├── lib/
│   │   ├── core/               # Core modules
│   │   │   ├── auth/           # Authentication (Authentik OIDC)
│   │   │   ├── api/            # API client
│   │   │   ├── design_system/  # UI components (Glassmorphism)
│   │   │   ├── router/         # GoRouter navigation
│   │   │   └── theme/          # App theming
│   │   ├── features/           # Feature modules
│   │   │   ├── chat/           # Chat interface
│   │   │   └── dashboard/      # Home dashboard
│   │   └── main.dart           # App entry point
│   ├── android/                # Android native
│   ├── ios/                    # iOS native
│   └── pubspec.yaml            # Dependencies
│
├── packages/                   # Encresa SDK Packages
│   ├── encresa_pypi/           # Python SDK (PyPI)
│   ├── encresa_npm/            # JavaScript SDK (NPM)
│   └── encresa_pub/            # Dart SDK (pub.dev)
│
├── k8s/                        # Kubernetes Manifests
│   ├── deployment.yaml         # Backend deployment
│   ├── service.yaml            # Service definitions
│   ├── ingress.yaml            # Ingress configuration
│   ├── secrets.yaml            # Secret templates
│   ├── tts-deployment.yaml     # TTS worker deployment
│   ├── auth/                   # Authentik IDP manifests
│   └── mcp/                    # MCP server manifests
│
├── scripts/                    # Automation scripts
│   ├── setup-cluster.sh        # Cluster initialization
│   ├── deploy-authentik.sh     # Authentik deployment
│   └── test_voice_backend.py   # Voice API tests
│
├── docs/                       # Documentation
│   ├── AUTHENTIK_SETUP.md      # Authentik IDP setup guide
│   ├── DESIGN_SYSTEM.md        # Flutter design system docs
│   ├── FLUTTER_NATIVE_SETUP.md # Flutter native setup
│   └── dev_tts_worker.md       # Kokoro TTS worker guide
│
├── dev.sh                      # 🚀 One-command dev startup
├── docker-compose.yaml         # Local PostgreSQL
├── Dockerfile                  # Multi-stage backend image
└── skaffold.yaml               # K8s development loop
```

---

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (limit to 4GB RAM)
- Python 3.11+ with venv
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- (Optional) [Minikube](https://minikube.sigs.k8s.io/docs/start/) + [Kubectl](https://kubernetes.io/docs/tasks/tools/) + [Skaffold](https://skaffold.dev/docs/install/) for K8s mode

### 1️⃣ Setup Environment

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r src/requirements.txt

# Create .env file with your keys
cp .env.example .env  # Edit with your API keys
```

### 2️⃣ Start Development Server (Recommended)

```bash
./dev.sh
```

This single command starts:
- 🐘 PostgreSQL (Docker)
- 🔧 MCP Server (port 8000)
- 🚀 Backend API (port 30000)
- 📊 Live log streaming

### 3️⃣ Start Flutter App

```bash
cd flutter && flutter run
```

---

## 🌐 Access Points

| Service | URL |
|---------|-----|
| 🚀 API Root | `http://localhost:30000` |
| 📚 Swagger Docs | `http://localhost:30000/docs` |
| 🎮 Admin Console | `http://localhost:30000/admin_console.html` |
| 🔧 MCP Server | `http://localhost:8000` |
| 🔐 Authentik | `http://localhost:9000` |
| ❤️ Health Check | `http://localhost:30000/health` |

---

## 🛠️ Development

### Backend Development

```bash
# One-command startup (recommended)
./dev.sh

# Or manually with skaffold (K8s mode)
skaffold dev

# Run tests
cd src && pytest

# Format code
ruff format .
```

### Flutter Development

```bash
cd flutter

# Get dependencies
flutter pub get

# Run code generation (for freezed, etc.)
dart run build_runner build

# Run app
flutter run

# Run with verbose logging
flutter run --verbose
```

---

## 🔊 Voice/TTS Setup

AURA supports multiple TTS backends:

### Option 1: ElevenLabs (Production)
Set `ELEVENLABS_API_KEY` in your `.env` file.

### Option 2: Kokoro TTS (Free, High Quality)
See [docs/dev_tts_worker.md](docs/dev_tts_worker.md) for Colab setup.

---

## ⚙️ Configuration

### Local Development (.env)

```bash
# Required
GEMINI_API_KEY=your-gemini-key
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-supabase-key

# Optional
ELEVENLABS_API_KEY=your-key     # For real TTS
TTS_WORKER_URL=https://...       # For Kokoro TTS
REDIS_URL=your-redis-url
QDRANT_URL=your-qdrant-url
```

### Kubernetes (Secrets)

```bash
kubectl create secret generic aura-secrets \
  --from-literal=GEMINI_API_KEY=your-key \
  --from-literal=SUPABASE_URL=your-url \
  --from-literal=SUPABASE_KEY=your-key
```

---

## 📋 API Overview

| Endpoint | Description |
|----------|-------------|
| `POST /api/v1/chat/stream` | Streaming chat with AI agent |
| `POST /api/v1/voice/synthesize` | Text-to-speech synthesis |
| `GET /api/v1/auth/status` | Authentication status |
| `GET /api/v1/tools` | List available tools |
| `POST /api/v1/tools/{id}/install` | Install a tool for user |

---

## 📋 Critical Rules

1. **RAM Discipline** — Backend limited to 512MB
2. **No Hardcoded Secrets** — Use `.env` or K8s secrets
3. **Modular Structure** — Backend in `/src`, Frontend in `/flutter`
4. **MCP Protocol** — All tools use JSON-RPC 2.0 via MCP

---

## 🗺️ Roadmap

- [x] FastAPI backend with health checks
- [x] Flutter mobile app foundation
- [x] Authentik authentication integration
- [x] Voice/TTS capabilities (Kokoro + ElevenLabs)
- [x] Gemini LLM integration
- [x] Semantic message routing
- [x] MCP Server & Tool execution
- [x] Agentic Skill Store API
- [ ] Vector memory with Qdrant
- [ ] Advanced ReAct reasoning loop
- [ ] Multi-modal input support
- [ ] Production Kubernetes deployment

---

## 📄 License

**Proprietary** — All Rights Reserved

---

<div align="center">

Made with ❤️ by the AURA Team

</div>
]]>
