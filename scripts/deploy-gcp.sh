#!/bin/bash
# =============================================================================
# Project Aura — GCP Production Deployment Script
# =============================================================================
# One-shot script to deploy everything to GKE Autopilot.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - .env file with all secrets populated
#   - Docker installed
#
# Usage: ./scripts/deploy-gcp.sh [--setup | --deploy | --all]
#   --setup   : Create GCP infrastructure (run once)
#   --deploy  : Build, push, and deploy to existing cluster
#   --all     : Run both setup and deploy
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-asia-south1}"
CLUSTER_NAME="aura-prod-cluster"
REPO_NAME="aura"
IMAGE_NAME="aura-backend"
NAMESPACE="aura-prod"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

check_prerequisites() {
    command -v gcloud &>/dev/null || err "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
    command -v docker &>/dev/null || err "Docker not found."
    command -v kubectl &>/dev/null || err "kubectl not found."
    command -v helm &>/dev/null || err "Helm not found. Install: https://helm.sh/docs/intro/install/"
    [ -f ".env" ] || err ".env file not found. Copy .env.example and fill in values."
    
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
            err "GCP_PROJECT_ID not set. Either export GCP_PROJECT_ID or run: gcloud config set project YOUR_PROJECT_ID"
        fi
    fi
    
    ok "Prerequisites OK (project: $PROJECT_ID, region: $REGION)"
}

# -------------------------------------------------------------------------
# Phase 1: Infrastructure Setup (run once)
# -------------------------------------------------------------------------
setup_infrastructure() {
    log "━━━ Phase 1: GCP Infrastructure Setup ━━━"
    
    # Enable required APIs
    log "Enabling GCP APIs..."
    gcloud services enable \
        container.googleapis.com \
        artifactregistry.googleapis.com \
        secretmanager.googleapis.com \
        cloudbuild.googleapis.com \
        --project="$PROJECT_ID" --quiet
    ok "APIs enabled"
    
    # Create Artifact Registry repository
    log "Creating Artifact Registry repository..."
    if gcloud artifacts repositories describe "$REPO_NAME" \
        --location="$REGION" --project="$PROJECT_ID" &>/dev/null 2>&1; then
        ok "Artifact Registry '$REPO_NAME' already exists"
    else
        gcloud artifacts repositories create "$REPO_NAME" \
            --repository-format=docker \
            --location="$REGION" \
            --description="Project Aura container images" \
            --project="$PROJECT_ID" --quiet
        ok "Artifact Registry '$REPO_NAME' created"
    fi
    
    # Create GKE Autopilot cluster
    log "Creating GKE Autopilot cluster (this may take 5-10 minutes)..."
    if gcloud container clusters describe "$CLUSTER_NAME" \
        --region="$REGION" --project="$PROJECT_ID" &>/dev/null 2>&1; then
        ok "GKE cluster '$CLUSTER_NAME' already exists"
    else
        gcloud container clusters create-auto "$CLUSTER_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --release-channel=regular \
            --enable-master-authorized-networks=false \
            --quiet
        ok "GKE Autopilot cluster '$CLUSTER_NAME' created"
    fi
    
    # Get cluster credentials
    log "Getting cluster credentials..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" --project="$PROJECT_ID"
    ok "kubectl configured for $CLUSTER_NAME"
    
    log "━━━ Infrastructure setup complete! ━━━"
}

# -------------------------------------------------------------------------
# Phase 2: Build & Deploy
# -------------------------------------------------------------------------
build_and_deploy() {
    log "━━━ Phase 2: Build & Deploy ━━━"
    
    FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}"
    TAG=$(date +%Y%m%d-%H%M%S)
    
    # Authenticate Docker with Artifact Registry
    log "Authenticating Docker with Artifact Registry..."
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    ok "Docker authenticated"
    
    # Build Docker image
    log "Building Docker image..."
    docker build -t "${FULL_IMAGE}:${TAG}" -t "${FULL_IMAGE}:latest" .
    ok "Image built: ${FULL_IMAGE}:${TAG}"
    
    # Push to Artifact Registry
    log "Pushing image to Artifact Registry..."
    docker push "${FULL_IMAGE}:${TAG}"
    docker push "${FULL_IMAGE}:latest"
    ok "Image pushed"
    
    # Get cluster credentials (in case not already configured)
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" --project="$PROJECT_ID" 2>/dev/null
    
    # Update image references in manifests
    log "Patching manifests with image tag..."
    sed -i "s|REGION-docker.pkg.dev/PROJECT_ID/aura/aura-backend:latest|${FULL_IMAGE}:${TAG}|g" \
        k8s/gcp/deployment.yaml \
        k8s/gcp/mcp-deployment.yaml
    ok "Manifests patched"
    
    # Apply namespace first
    log "Creating namespace..."
    kubectl apply -f k8s/gcp/namespace.yaml
    ok "Namespace created"
    
    # Create secrets from .env file
    log "Creating Kubernetes secrets from .env..."
    create_secrets
    ok "Secrets created"
    
    # Deploy Authentik via Helm chart
    log "Deploying Authentik via Helm chart..."
    helm repo add authentik https://charts.goauthentik.io 2>/dev/null || true
    helm repo update authentik

    # Generate secure passwords for Authentik components
    AUTHENTIK_SECRET_KEY_VAL="${AUTHENTIK_SECRET_KEY:-$(openssl rand -base64 32)}"

    helm upgrade --install authentik authentik/authentik \
        --namespace "$NAMESPACE" \
        --values k8s/gcp/authentik-helm/values.yaml \
        --set authentik.secret_key="${AUTHENTIK_SECRET_KEY_VAL}" \
        --timeout 10m \
        --wait
    ok "Authentik Helm release deployed"

    # Apply GKE-specific BackendConfig for Authentik (not managed by Helm)
    kubectl apply -f k8s/gcp/authentik-helm/backend-config.yaml
    ok "Authentik BackendConfig applied"

    # Apply remaining non-Authentik manifests
    log "Applying application manifests..."
    kubectl apply -f k8s/gcp/configmap.yaml
    kubectl apply -f k8s/gcp/deployment.yaml
    kubectl apply -f k8s/gcp/mcp-deployment.yaml
    kubectl apply -f k8s/gcp/service.yaml
    kubectl apply -f k8s/gcp/hpa.yaml
    kubectl apply -f k8s/gcp/managed-cert.yaml
    kubectl apply -f k8s/gcp/ingress.yaml
    kubectl apply -f k8s/gcp/network-policy.yaml
    ok "All manifests applied"
    
    # Revert sed changes to keep manifests clean for git
    log "Reverting manifest placeholders..."
    sed -i "s|${FULL_IMAGE}:${TAG}|REGION-docker.pkg.dev/PROJECT_ID/aura/aura-backend:latest|g" \
        k8s/gcp/deployment.yaml \
        k8s/gcp/mcp-deployment.yaml
    
    # Wait for rollout
    log "Waiting for backend rollout..."
    kubectl rollout status deployment/aura-backend -n "$NAMESPACE" --timeout=300s || warn "Backend rollout still in progress"
    
    log "Waiting for Authentik rollout..."
    kubectl rollout status deployment/authentik-server -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    kubectl rollout status deployment -l app.kubernetes.io/name=authentik,app.kubernetes.io/component=server -n "$NAMESPACE" --timeout=300s || \
    warn "Authentik rollout still in progress"
    
    ok "━━━ Deployment complete! ━━━"
    echo ""
    print_status
}

# -------------------------------------------------------------------------
# Create K8s secrets from .env file
# -------------------------------------------------------------------------
create_secrets() {
    # Source .env
    set -a
    source .env
    set +a
    
    # Generate SECRET_KEY if not set
    if [ -z "${SECRET_KEY:-}" ] || [ "${SECRET_KEY:-}" = "CHANGE_ME_IN_PRODUCTION_USE_OPENSSL_RAND_HEX_32" ]; then
        SECRET_KEY=$(openssl rand -hex 32)
        warn "Generated new SECRET_KEY for JWT signing"
    fi
    
    # Note: Authentik PostgreSQL password is now generated and injected via Helm (see helm upgrade --install)
    
    # Create aura-secrets
    kubectl create secret generic aura-secrets \
        --namespace="$NAMESPACE" \
        --from-literal=GOOGLE_API_KEY="${GOOGLE_API_KEY:-}" \
        --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
        --from-literal=GROQ_API_KEY="${GROQ_API_KEY:-}" \
        --from-literal=OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}" \
        --from-literal=DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}" \
        --from-literal=DATABASE_URL="${DATABASE_URL:-}" \
        --from-literal=SECRET_KEY="${SECRET_KEY}" \
        --from-literal=AUTHENTIK_CLIENT_ID="${AUTHENTIK_CLIENT_ID:-}" \
        --from-literal=AUTHENTIK_CLIENT_SECRET="${AUTHENTIK_CLIENT_SECRET:-}" \
        --from-literal=AUTHENTIK_SECRET_KEY="${AUTHENTIK_SECRET_KEY:-}" \
        --from-literal=GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-}" \
        --from-literal=GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-}" \
        --from-literal=ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}" \
        --from-literal=GOOGLE_CALENDAR_CLIENT_ID="${GOOGLE_CALENDAR_CLIENT_ID:-}" \
        --from-literal=GOOGLE_CALENDAR_CLIENT_SECRET="${GOOGLE_CALENDAR_CLIENT_SECRET:-}" \
        --dry-run=client -o yaml | kubectl apply -f -
    # Note: authentik-secrets are now managed by the Helm chart (see helm upgrade --install above)
}

# -------------------------------------------------------------------------
# Print deployment status
# -------------------------------------------------------------------------
print_status() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   🚀 AURA Production Deployment Status${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || true
    echo ""
    
    echo -e "${BLUE}Services:${NC}"
    kubectl get svc -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    
    echo -e "${BLUE}HPA:${NC}"
    kubectl get hpa -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    
    echo -e "${BLUE}Ingress:${NC}"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    
    echo -e "${BLUE}Managed Certificates:${NC}"
    kubectl get managedcertificates -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get ingress aura-ingress -n "$NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   External IP: ${BLUE}${EXTERNAL_IP}${NC}"
    echo -e "   API:         ${BLUE}https://api.encresa.com${NC}"
    echo -e "   Auth:        ${BLUE}https://auth.encresa.com${NC}"
    echo -e "   API Docs:    ${BLUE}https://api.encresa.com/docs${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  DNS Setup Required:${NC}"
    echo -e "   Point these DNS A records to the external IP:"
    echo -e "     api.encresa.com  → ${EXTERNAL_IP}"
    echo -e "     auth.encresa.com → ${EXTERNAL_IP}"
    echo ""
    echo -e "${YELLOW}⚠️  SSL Certificate:${NC}"
    echo -e "   Google-managed certs may take 15-60 minutes to provision."
    echo -e "   Check status: kubectl get managedcertificates -n $NAMESPACE"
    echo ""
}

# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

case "${1:---all}" in
    --setup)
        check_prerequisites
        setup_infrastructure
        ;;
    --deploy)
        check_prerequisites
        build_and_deploy
        ;;
    --all)
        check_prerequisites
        setup_infrastructure
        build_and_deploy
        ;;
    --status)
        NAMESPACE="${NAMESPACE:-aura-prod}"
        print_status
        ;;
    *)
        echo "Usage: $0 [--setup | --deploy | --all | --status]"
        echo ""
        echo "  --setup   Create GCP infrastructure (GKE cluster, Artifact Registry)"
        echo "  --deploy  Build image and deploy to existing cluster"
        echo "  --all     Run both setup and deploy (default)"
        echo "  --status  Print current deployment status"
        exit 1
        ;;
esac
