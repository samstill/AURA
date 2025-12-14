<div align="center">

# 🌟 AURA

### The World's Fastest, Most Intuitive AI Secretary

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

*A "Digital Body Double" that learns to mimic you, equipped with a **Hybrid Brain** for split-second reflexes and a **Supermemory** for infinite context retention.*

[Getting Started](#-quick-start) • [Architecture](#-architecture) • [Documentation](#-documentation) • [Roadmap](#-roadmap)

</div>

---

## ✨ Features

- **🧠 Hybrid AI Brain** - Combines fast reflexes with deep reasoning for optimal responses
- **💾 Supermemory** - Infinite context retention across all your interactions
- **🔐 Enterprise-Grade Security** - Authentik-powered OIDC authentication
- **📱 Cross-Platform** - Native Flutter apps for iOS, Android, Web, and Desktop
- **☸️ Cloud-Native** - Kubernetes-ready with Skaffold hot-reload development
- **⚡ Blazing Fast** - Optimized for low-latency responses with Redis caching
- **🔄 Real-Time Sync** - WebSocket support for instant communication

---

## 🏗️ Architecture

AURA uses a **Hybrid Architecture** optimized for development and production:

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Compute** | Kubernetes (Minikube) | Local/Cloud orchestration |
| **Backend** | Python (FastAPI) | High-performance API server |
| **Frontend** | Flutter | Cross-platform native apps |
| **Auth** | Authentik | Enterprise OIDC provider |
| **Database** | PostgreSQL (Supabase) | Persistent data storage |
| **Cache** | Redis (Upstash) | Fast session & data caching |
| **Vectors** | Qdrant Cloud | Semantic search & embeddings |

```
┌──────────────────────────────────────────────────────────────┐
│                        AURA ECOSYSTEM                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────┐          ┌─────────────┐                   │
│   │   Flutter   │◄────────►│   FastAPI   │                   │
│   │   (Client)  │   REST   │  (Backend)  │                   │
│   └─────────────┘  + WS    └──────┬──────┘                   │
│                                   │                          │
│         ┌─────────────────────────┼─────────────────────┐    │
│         │                         │                     │    │
│         ▼                         ▼                     ▼    │
│   ┌───────────┐           ┌───────────┐          ┌──────────┐│
│   │ Authentik │           │  Supabase │          │  Qdrant  ││
│   │  (Auth)   │           │   (DB)    │          │(Vectors) ││
│   └───────────┘           └───────────┘          └──────────┘│
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
AURA/
├── src/                    # 🐍 FastAPI Backend
│   ├── main.py             # Application entry point
│   ├── config.py           # Configuration management
│   ├── routers/            # API route handlers
│   │   ├── auth.py         # Authentication endpoints
│   │   ├── chat.py         # Chat functionality
│   │   └── voice.py        # Voice processing
│   ├── services/           # Business logic layer
│   └── dependencies/       # Dependency injection
│
├── flutter/                # 📱 Flutter Mobile/Web App
│   ├── lib/                # Dart source code
│   │   └── core/           # Core modules (auth, etc.)
│   ├── android/            # Android-specific code
│   ├── ios/                # iOS-specific code
│   └── pubspec.yaml        # Flutter dependencies
│
├── k8s/                    # ☸️ Kubernetes Manifests
│   ├── deployment.yaml     # Backend deployment
│   ├── service.yaml        # Service networking
│   ├── ingress.yaml        # Ingress routing
│   └── auth/               # Authentik IDP setup
│
├── scripts/                # 🔧 Automation Scripts
│   ├── setup-cluster.sh    # Initialize Minikube
│   └── deploy-authentik.sh # Deploy auth provider
│
├── docs/                   # 📚 Documentation
│   ├── AUTHENTIK_SETUP.md  # Auth configuration guide
│   └── FLUTTER_NATIVE_SETUP.md
│
├── Dockerfile              # 🐳 Multi-stage build
└── skaffold.yaml           # 🔄 Dev loop configuration
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Docker](https://docker.com) | 20.10+ | Container runtime |
| [Minikube](https://minikube.sigs.k8s.io) | 1.30+ | Local Kubernetes |
| [Kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.27+ | K8s CLI |
| [Skaffold](https://skaffold.dev) | 2.0+ | Dev workflow |
| [Flutter](https://flutter.dev) | 3.0+ | Mobile/Web frontend |

### 1️⃣ Initialize Cluster

```bash
# Start Minikube with optimized settings
./scripts/setup-cluster.sh
```

### 2️⃣ Deploy Authentik (Identity Provider)

```bash
# Deploy Authentik to the cluster
./scripts/deploy-authentik.sh

# Port-forward for local access
kubectl port-forward -n aura-auth svc/authentik 9000:80
```

### 3️⃣ Start Backend (Hot-Reload)

```bash
# Start with Skaffold for live development
skaffold dev
```

### 4️⃣ Run Flutter App

```bash
# Navigate to Flutter directory and run
cd flutter && flutter run
```

---

## 🌐 Access Points

| Service | URL | Description |
|---------|-----|-------------|
| **API Root** | `http://localhost:30000` | Backend base URL |
| **Swagger Docs** | `http://localhost:30000/docs` | Interactive API docs |
| **Authentik** | `http://localhost:9000` | Identity provider |
| **Health Check** | `http://localhost:30000/health` | K8s liveness probe |
| **Readiness** | `http://localhost:30000/ready` | K8s readiness probe |

---

## 📚 Documentation

- [Authentik Setup Guide](docs/AUTHENTIK_SETUP.md) - Configure OIDC authentication
- [Flutter Native Setup](docs/FLUTTER_NATIVE_SETUP.md) - Platform-specific configuration

---

## 🗺️ Roadmap

- [x] FastAPI backend with hot-reload
- [x] Kubernetes deployment manifests
- [x] Authentik OIDC integration
- [x] Flutter app with state management
- [ ] Voice assistant integration
- [ ] Multi-modal AI capabilities
- [ ] Advanced memory & context system
- [ ] Production deployment pipelines

---

## ⚠️ Development Guidelines

| Rule | Description |
|------|-------------|
| **RAM Discipline** | Backend limited to **512MB** |
| **No Hardcoded Secrets** | Use `kubectl create secret` |
| **Modular Structure** | Backend in `/src`, Frontend in `/flutter` |
| **Code Style** | Follow PEP8 (Python) and Dart conventions |

---

## 🛠️ Tech Stack

<div align="center">

![Python](https://img.shields.io/badge/Python-FFD43B?style=flat-square&logo=python&logoColor=blue)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat-square&logo=fastapi)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2CA5E0?style=flat-square&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat-square&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=flat-square&logo=redis&logoColor=white)

</div>

---

## 📄 License

**Proprietary** - All Rights Reserved

---

<div align="center">

**Built with ❤️ by the AURA Team**

</div>
