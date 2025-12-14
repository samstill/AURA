#!/bin/bash
# =============================================================================
# Project Aura - Cluster Setup Script
# =============================================================================
# Initializes Minikube with low-spec settings for 8GB RAM machines.
# Run this ONCE after installing prerequisites.
# =============================================================================

set -e

echo "🚀 Project Aura - Cluster Setup"
echo "================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop."
    exit 1
fi

if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install Minikube."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl."
    exit 1
fi

if ! command -v skaffold &> /dev/null; then
    echo "❌ Skaffold is not installed. Please install Skaffold."
    exit 1
fi

echo "✅ All prerequisites installed"

# Check if minikube is already running
if minikube status &> /dev/null; then
    echo "⚠️  Minikube is already running."
    read -p "   Do you want to delete and recreate? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        echo "🗑️  Deleting existing cluster..."
        minikube delete
    else
        echo "   Keeping existing cluster."
        exit 0
    fi
fi

# Start Minikube with low-spec settings
echo ""
echo "🎯 Starting Minikube (Low-Spec Mode)"
echo "   CPUs: 2"
echo "   Memory: 3500MB"
echo "   Driver: docker"
echo ""

minikube start \
    --cpus 2 \
    --memory 3500 \
    --driver=docker \
    --container-runtime=docker

# Verify cluster is ready
echo ""
echo "🔍 Verifying cluster..."
kubectl get nodes

# Point Docker CLI to Minikube's Docker daemon
echo ""
echo "🔧 Configuring Docker environment..."
echo "   Run this command to use Minikube's Docker daemon:"
echo ""
echo "   eval \$(minikube docker-env)"
echo ""

# Create namespace (optional)
# kubectl create namespace aura --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Cluster setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Inject secrets:    kubectl create secret generic aura-secrets --from-literal=..."
echo "   2. Start development: skaffold dev"
echo "   3. Access API:        http://localhost:30000"
echo ""
