<![CDATA[<div align="center">

# 🌟 AURA

### **The World's Fastest, Most Intuitive AI Secretary**

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

*A "Digital Body Double" that learns to mimic you, equipped with a Hybrid Brain for split-second reflexes and a Supermemory for infinite context retention.*

</div>

---

## ✨ Features

- 🧠 **Hybrid AI Brain** — Split-second reflexes with deep reasoning capabilities
- 🎤 **Voice Interface** — Natural voice interaction with real-time TTS
- 💬 **Intelligent Chat** — Context-aware conversations with persistent memory
- 🔐 **Secure Authentication** — OAuth2/OIDC via Authentik IDP
- 📱 **Cross-Platform** — Native mobile apps for iOS and Android
- ☁️ **Cloud-Native** — Kubernetes-first architecture with Skaffold dev loop

---

## 🏗️ Architecture

| Layer | Technology | Strategy |
|-------|------------|----------|
| **Compute** | Kubernetes (Minikube) | Local development via Skaffold |
| **Backend** | Python (FastAPI) | Hot-reloads inside K8s |
| **Frontend** | Flutter | Cross-platform mobile |
| **Auth** | Authentik | Local OIDC Provider |
| **Database** | PostgreSQL | Supabase (External) |
| **Cache** | Redis | Upstash (External) |
| **Vectors** | Qdrant | Qdrant Cloud (External) |

---

## 📁 Project Structure

```
AURA/
├── src/                    # FastAPI Backend
│   ├── main.py             # Application entry point
│   ├── config.py           # Configuration management
│   ├── routers/            # API endpoints
│   │   ├── auth.py         # Authentication routes
│   │   ├── chat.py         # Chat API
│   │   └── voice.py        # Voice/TTS API
│   ├── services/           # Business logic
│   │   ├── authentik_service.py
│   │   ├── tts_service.py
│   │   └── ...
│   ├── mcp_server/         # MCP Server integration
│   └── dependencies/       # FastAPI dependencies
│
├── flutter/                # Flutter Mobile App
│   ├── lib/
│   │   ├── core/           # Core modules
│   │   │   ├── auth/       # Authentication
│   │   │   └── design_system/  # UI components
│   │   ├── features/       # Feature modules
│   │   └── main.dart       # App entry point
│   ├── android/            # Android native
│   ├── ios/                # iOS native
│   └── pubspec.yaml        # Dependencies
│
├── k8s/                    # Kubernetes Manifests
│   ├── deployment.yaml     # Aura backend deployment
│   ├── service.yaml        # Service definitions
│   ├── ingress.yaml        # Ingress configuration
│   └── auth/               # Authentik IDP manifests
│
├── scripts/                # Automation scripts
│   ├── setup-cluster.sh    # Cluster initialization
│   └── deploy-authentik.sh # Authentik deployment
│
├── docs/                   # Documentation
├── Dockerfile              # Multi-stage backend image
└── skaffold.yaml           # Development loop config
```

---

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (limit to 4GB RAM)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Skaffold](https://skaffold.dev/docs/install/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- Python 3.11+

### 1️⃣ Initialize Cluster

```bash
./scripts/setup-cluster.sh
```

### 2️⃣ Start Authentik (Local IDP)

```bash
./scripts/deploy-authentik.sh
kubectl port-forward -n aura-auth svc/authentik 9000:80
```

### 3️⃣ Start Backend

```bash
skaffold dev
```

### 4️⃣ Start Flutter App

```bash
cd flutter && flutter run
```

---

## 🌐 Access Points

| Service | URL |
|---------|-----|
| 🚀 API Root | `http://localhost:30000` |
| 📚 Swagger Docs | `http://localhost:30000/docs` |
| 🔐 Authentik | `http://localhost:9000` |
| ❤️ Health Check | `http://localhost:30000/health` |

---

## 🛠️ Development

### Backend Development

```bash
# Start with hot-reload
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

# Run code generation
dart run build_runner build

# Run app
flutter run
```

---

## ⚙️ Configuration

Environment variables are managed via Kubernetes secrets:

```bash
# Create secrets
kubectl create secret generic aura-secrets \
  --from-literal=SUPABASE_URL=your-url \
  --from-literal=SUPABASE_KEY=your-key \
  --from-literal=REDIS_URL=your-redis-url
```

---

## 📋 Critical Rules

1. **RAM Discipline** — Backend limited to 512MB
2. **No Hardcoded Secrets** — Use `kubectl create secret`
3. **Modular Structure** — Backend in `/src`, Frontend in `/flutter`

---

## 🗺️ Roadmap

- [x] FastAPI backend with health checks
- [x] Flutter mobile app foundation
- [x] Authentik authentication integration
- [x] Voice/TTS capabilities
- [ ] Vector memory with Qdrant
- [ ] Advanced AI reasoning
- [ ] Multi-modal input support

---

## 📄 License

**Proprietary** — All Rights Reserved

---

<div align="center">

Made with ❤️ by the AURA Team

</div>
]]>
