<div align="center">

# 🌟 AURA

### The World's Fastest, Most Intuitive AI Secretary

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![MCP](https://img.shields.io/badge/MCP-Enabled-orange?style=for-the-badge)](https://modelcontextprotocol.io)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

*A "Digital Body Double" that learns to mimic you, equipped with a **Hybrid Brain** for split-second reflexes and a **Supermemory** for infinite context retention.*

[Getting Started](#-quick-start) • [Architecture](#-architecture) • [Documentation](#-documentation) • [Roadmap](#-roadmap)

</div>

---

## ✨ Features

- **🧠 Hybrid AI Brain** - Combines fast reflexes with deep reasoning for optimal responses
- **🤖 Agent Orchestrator** - Intelligent task decomposition and multi-agent coordination
- **🔌 MCP Integration** - Standardized Model Context Protocol for seamless tool connection
- **💾 Supermemory** - Infinite context retention across all your interactions
- **🔐 Enterprise-Grade Security** - Authentik-powered OIDC authentication
- **📱 Cross-Platform** - Native Flutter apps for iOS, Android, Web, and Desktop
- **☸️ Cloud-Native** - Kubernetes-ready with Skaffold hot-reload development
- **⚡ Blazing Fast** - Optimized for low-latency responses with Redis caching
- **🔄 Real-Time Sync** - WebSocket support for instant communication

---

## 🏗️ Architecture

AURA uses a **Hybrid Agentic Architecture** powered by MCP:

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Compute** | Kubernetes (Minikube) | Local/Cloud orchestration |
| **Backend** | Python (FastAPI) | API Server & Agent Orchestrator |
| **Agents** | Custom + LangChain | Reasoning & Task Execution |
| **Tools** | MCP (Model Context Protocol) | Standardized Tool Interfaces |
| **Frontend** | Flutter | Cross-platform native apps |
| **Auth** | Authentik | Enterprise OIDC provider |
| **Database** | PostgreSQL (Supabase) | Persistent data storage |
| **Cache** | Redis (Upstash) | Fast session & data caching |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AURA AGENTIC SYSTEM                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐            ┌───────────────────┐                      │
│   │   Flutter   │◄──────────►│  FastAPI Backend  │                      │
│   │   (Client)  │  REST/WS   │   (Orchestrator)  │                      │
│   └─────────────┘            └─────────┬─────────┘                      │
│                                        │                                │
│                                        ▼                                │
│                            ┌───────────────────────┐                    │
│                            │    Agent Services     │                    │
│                            │ (LLM + MCP Clients)   │                    │
│                            └─────┬───────────┬─────┘                    │
│                                  │           │                          │
│                ┌─────────────────▼─┐       ┌─▼──────────────────┐       │
│                │    MCP Servers    │       │   Core Services    │       │
│                │ (Tools & Context) │       │ (DB, Redis, Auth)  │       │
│                └───────────────────┘       └────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
AURA/
├── src/                        # 🐍 FastAPI Backend & Agents
│   ├── main.py                 # Application entry point
│   ├── config.py               # Configuration management
│   ├── services/               # Core Business Logic
│   │   ├── agent_service.py    # AI Agent coordination
│   │   ├── orchestrator_service.py # Request routing logic
│   │   └── mcp_client.py       # MCP Protocol Client
│   ├── mcp_server/             # 🔌 Internal MCP Server
│   │   ├── main.py             # Server entry point
│   │   └── tools/              # Tool implementations
│   ├── routers/                # API route handlers
│   │   ├── tools.py            # Tool exposure endpoints
│   │   └── chat.py             # Chat functionality
│   └── scripts/                # Utility scripts
│
├── flutter/                    # 📱 Flutter Mobile/Web App
│   ├── lib/                    # Dart source code
│   └── pubspec.yaml            # Flutter dependencies
│
├── k8s/                        # ☸️ Kubernetes Manifests
│   ├── deployment.yaml         # Backend deployment
│   ├── mcp/                    # MCP Server manifests
│   └── auth/                   # Authentik IDP setup
│
├── dev.sh                      # 🛠️ Development Helper Script
├── Dockerfile                  # 🐳 Multi-stage build
└── skaffold.yaml               # 🔄 Dev loop configuration
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Docker](https://docker.com) | 20.10+ | Container runtime |
| [Minikube](https://minikube.sigs.k8s.io) | 1.30+ | Local Kubernetes |
| [Skffold](https://skaffold.dev) | 2.0+ | Dev workflow |
| [Flutter](https://flutter.dev) | 3.0+ | Mobile/Web frontend |

### 1️⃣ Initialize Cluster

```bash
# Start Minikube with optimized settings
./scripts/setup-cluster.sh
```

### 2️⃣ Start Development Environment

We provide a convenience script to manage the entire lifecycle:

```bash
# Verify environment and start dev loop
./dev.sh
```

Or manually:

```bash
# Deploy Authentik
./scripts/deploy-authentik.sh

# Start Backend & Agents
skaffold dev
```

### 3️⃣ Run Flutter App

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
| **MCP Inspect** | `http://localhost:30000/mcp/debug` | Tool Inspector |

---

## 🗺️ Roadmap

- [x] FastAPI backend with hot-reload
- [x] Kubernetes deployment manifests
- [x] Authentik OIDC integration
- [x] Agent Orchestrator & MCP Framework
- [ ] Multi-modal AI capabilities
- [ ] Advanced memory & context system
- [ ] Production deployment pipelines

---

## ⚠️ Development Guidelines

| Rule | Description |
|------|-------------|
| **RAM Discipline** | Backend limited to **512MB** |
| **Structure** | Agents in `/services`, Tools in `/mcp_server` |
| **Code Style** | Follow PEP8 (Python) and Dart conventions |

---

## 🛠️ Tech Stack

<div align="center">

![Python](https://img.shields.io/badge/Python-FFD43B?style=flat-square&logo=python&logoColor=blue)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat-square&logo=fastapi)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![MCP](https://img.shields.io/badge/MCP-Protocol-orange?style=flat-square)
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
