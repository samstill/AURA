<div align="center">

<img src="Icons/readme_200.png" alt="AURA Logo" width="200"/>

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
- 📅 **Google Calendar Integration** — OAuth connect, event CRUD, smart scheduling
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
| **AI Engine** | Google Gemini | 2.0 Flash / 2.0 Flash Thinking |
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
│   │   ├── calendar.py         # Google Calendar API
│   │   └── tools.py            # Skill Store API
│   ├── services/               # Business logic
│   │   ├── agent_service.py    # ReAct agent with tool calling
│   │   ├── orchestrator_service.py  # Streaming orchestrator
│   │   ├── llm_service.py      # Gemini LLM integration
│   │   ├── router_service.py   # Semantic message routing
│   │   ├── semantic_cache_service.py  # Response caching
│   │   ├── staller_service.py  # Quick acknowledgments
│   │   ├── google_calendar_service.py  # Google Calendar OAuth
│   │   ├── calendar_tools.py   # Calendar agent tools
│   │   ├── tts_service.py      # Text-to-speech
│   │   └── ...                 # Other services
│   └── mcp_server/             # MCP Server (JSON-RPC 2.0)
│
├── flutter/                    # Flutter Mobile App
│   ├── lib/
│   │   ├── core/               # Core modules (auth, api, design_system)
│   │   ├── features/           # Feature modules (chat, dashboard, splash)
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
├── scripts/                    # Automation scripts
├── docs/                       # Documentation
├── dev.sh                      # 🚀 One-command dev startup
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
```

---

## ⚙️ Configuration

### Local Development (.env)

```bash
# Required
GOOGLE_API_KEY=your-gemini-key

# Google Calendar (OAuth)
GOOGLE_CALENDAR_CLIENT_ID=your-google-client-id
GOOGLE_CALENDAR_CLIENT_SECRET=your-google-client-secret

# Optional
ELEVENLABS_API_KEY=your-key     # For real TTS
TTS_WORKER_URL=https://...       # For Kokoro TTS
REDIS_URL=your-redis-url
QDRANT_URL=your-qdrant-url
```

See [.env.example](.env.example) for full configuration options.

---

## 📋 API Overview

| Endpoint | Description |
|----------|-------------|
| `POST /api/v1/chat/stream` | Streaming chat with AI agent |
| `POST /api/v1/voice/synthesize` | Text-to-speech synthesis |
| `GET /api/v1/auth/status` | Authentication status |
| `GET /api/v1/tools` | List available tools |
| `GET /api/v1/calendar/connect` | Initiate Google Calendar OAuth |
| `GET /api/v1/calendar/events` | Get calendar events |

---

## 🗺️ Roadmap

- [x] FastAPI backend with health checks
- [x] Flutter mobile app foundation
- [x] Authentik authentication integration
- [x] Voice/TTS capabilities (Kokoro + ElevenLabs)
- [x] Gemini LLM integration
- [x] Semantic message routing
- [x] Semantic caching service
- [x] MCP Server & Tool execution
- [x] Google Calendar integration
- [ ] Vector memory with Qdrant
- [ ] Advanced ReAct reasoning loop
- [ ] Multi-modal input support
- [ ] Production Kubernetes deployment

---

## 📄 License

**Proprietary** — All Rights Reserved © Encresa

---

<div align="center">

Made with ❤️ by the AURA Team at **Encresa**

</div>
