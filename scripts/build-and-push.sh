#!/bin/bash

# Kubernetes Homelab - Build and Push Docker Images
# This script builds and pushes all application Docker images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Configuration
DOCKER_REGISTRY="docker.io"
GHCR_REGISTRY="ghcr.io"
USERNAME="jconover"
PROJECT_NAME="kubernetes-homelab"

# Check if Docker is running
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker and try again."
fi

# Check authentication for both registries
DOCKER_AUTH=false
GHCR_AUTH=false

# Check Docker Hub authentication
if docker info | grep -qi "username"; then
    DOCKER_AUTH=true
    log "Docker Hub authentication: ✅ Authenticated"
else
    warn "Docker Hub authentication: ❌ Not authenticated"
fi

# Check GitHub Container Registry authentication
if docker login $GHCR_REGISTRY --username $USERNAME --password-stdin < /dev/null 2>/dev/null; then
    GHCR_AUTH=true
    log "GitHub Container Registry authentication: ✅ Authenticated"
else
    warn "GitHub Container Registry authentication: ❌ Not authenticated"
fi

# Determine push strategy
if [[ "$DOCKER_AUTH" == "true" && "$GHCR_AUTH" == "true" ]]; then
    PUSH_STRATEGY="both"
    log "Will push to both Docker Hub and GitHub Container Registry"
elif [[ "$DOCKER_AUTH" == "true" ]]; then
    PUSH_STRATEGY="docker"
    log "Will push to Docker Hub only"
elif [[ "$GHCR_AUTH" == "true" ]]; then
    PUSH_STRATEGY="ghcr"
    log "Will push to GitHub Container Registry only"
else
    warn "No registry authentication found!"
    warn ""
    warn "To authenticate with Docker Hub:"
    warn "docker login -u $USERNAME"
    warn ""
    warn "To authenticate with GitHub Container Registry:"
    warn "echo \$GITHUB_TOKEN | docker login $GHCR_REGISTRY -u $USERNAME --password-stdin"
    warn ""
    warn "You need a GitHub Personal Access Token with 'write:packages' permission"
    warn "Create one at: https://github.com/settings/tokens"
    warn ""
    read -p "Do you want to continue with build only (no push)? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Build cancelled. Please authenticate first."
    fi
    PUSH_STRATEGY="none"
fi

log "Building and pushing Docker images for Kubernetes Homelab applications..."

# Build and push React Frontend
log "Building React Frontend..."
cd apps/react-frontend
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Build images for both registries
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest" .
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP" .

# Push based on authentication
if [[ "$PUSH_STRATEGY" == "both" ]]; then
    log "Pushing React Frontend to both registries..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "docker" ]]; then
    log "Pushing React Frontend to Docker Hub..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "ghcr" ]]; then
    log "Pushing React Frontend to GitHub Container Registry..."
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:$TIMESTAMP"
else
    log "Skipping push for React Frontend (not authenticated)"
fi
cd ../..

# Build and push Python API
log "Building Python API..."
cd apps/python-api
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Build images for both registries
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest" .
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP" .

# Push based on authentication
if [[ "$PUSH_STRATEGY" == "both" ]]; then
    log "Pushing Python API to both registries..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "docker" ]]; then
    log "Pushing Python API to Docker Hub..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "ghcr" ]]; then
    log "Pushing Python API to GitHub Container Registry..."
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:$TIMESTAMP"
else
    log "Skipping push for Python API (not authenticated)"
fi
cd ../..

# Build and push Node.js Service
log "Building Node.js Service..."
cd apps/nodejs-service
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Build images for both registries
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest" .
docker build -t "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest" .
docker build -t "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP" .

# Push based on authentication
if [[ "$PUSH_STRATEGY" == "both" ]]; then
    log "Pushing Node.js Service to both registries..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "docker" ]]; then
    log "Pushing Node.js Service to Docker Hub..."
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    docker push "$DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP"
elif [[ "$PUSH_STRATEGY" == "ghcr" ]]; then
    log "Pushing Node.js Service to GitHub Container Registry..."
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    docker push "$GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:$TIMESTAMP"
else
    log "Skipping push for Node.js Service (not authenticated)"
fi
cd ../..

if [[ "$PUSH_STRATEGY" == "both" ]]; then
    log "All images built and pushed successfully to both registries!"
    log ""
    log "Images pushed to Docker Hub:"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    log ""
    log "Images pushed to GitHub Container Registry:"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
elif [[ "$PUSH_STRATEGY" == "docker" ]]; then
    log "All images built and pushed successfully to Docker Hub!"
    log ""
    log "Images pushed to Docker Hub:"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
elif [[ "$PUSH_STRATEGY" == "ghcr" ]]; then
    log "All images built and pushed successfully to GitHub Container Registry!"
    log ""
    log "Images pushed to GitHub Container Registry:"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
else
    log "All images built successfully (but not pushed - authentication required)!"
    log ""
    log "Images built locally:"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $DOCKER_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-react-frontend:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-python-api:latest"
    log "- $GHCR_REGISTRY/$USERNAME/$PROJECT_NAME-nodejs-service:latest"
    log ""
    log "To push images, authenticate first:"
    log "docker login -u $USERNAME  # For Docker Hub"
    log "echo \$GITHUB_TOKEN | docker login $GHCR_REGISTRY -u $USERNAME --password-stdin  # For GitHub Container Registry"
    log "Then run this script again."
fi
log ""
log "You can now deploy these images using:"
log "kubectl apply -f manifests/applications/"
log ""
log "Or update your Kubernetes manifests to use these specific image tags."
