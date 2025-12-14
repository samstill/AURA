#!/bin/bash
# =============================================================================
# Project Aura - Deploy Authentik
# =============================================================================
# Deploys local Authentik to Minikube for development
# =============================================================================

set -e

echo "🔐 Deploying Authentik to Minikube..."
echo "====================================="

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Start it with:"
    echo "   minikube start --cpus 2 --memory 3500 --driver=docker"
    exit 1
fi

# Apply Authentik resources
echo ""
echo "📦 Applying Authentik manifests..."
kubectl apply -k k8s/auth/

# Wait for pods to be ready
echo ""
echo "⏳ Waiting for pods to start (this may take 2-3 minutes)..."
echo "   Pulling images: postgres:16-alpine, redis:7-alpine, authentik:2024.10.4"

kubectl wait --for=condition=available --timeout=300s deployment/authentik-postgres -n aura-auth || {
    echo "⚠️  PostgreSQL not ready yet, checking logs..."
    kubectl logs -n aura-auth -l app.kubernetes.io/name=authentik-postgres --tail=20
}

kubectl wait --for=condition=available --timeout=300s deployment/authentik-redis -n aura-auth || {
    echo "⚠️  Redis not ready yet, checking logs..."
    kubectl logs -n aura-auth -l app.kubernetes.io/name=authentik-redis --tail=20
}

kubectl wait --for=condition=available --timeout=300s deployment/authentik-server -n aura-auth || {
    echo "⚠️  Authentik server not ready yet, checking logs..."
    kubectl logs -n aura-auth -l app.kubernetes.io/name=authentik-server --tail=20
}

echo ""
echo "✅ Authentik deployed!"
echo ""
echo "📊 Pod Status:"
kubectl get pods -n aura-auth

echo ""
echo "🌐 Access Authentik:"
echo ""
echo "   Option 1: Port-forward (recommended)"
echo "   kubectl port-forward -n aura-auth svc/authentik 9000:80"
echo "   Then visit: http://localhost:9000/if/flow/initial-setup/"
echo ""
echo "   Option 2: Minikube service"
echo "   minikube service authentik-nodeport -n aura-auth"
echo ""
echo "📝 Initial Setup:"
echo "   1. Visit the URL above"
echo "   2. Create admin account (akadmin)"
echo "   3. Create OAuth2 Provider for Aura"
echo "   4. Set redirect URI: http://localhost:30000/api/v1/auth/callback"
echo ""
