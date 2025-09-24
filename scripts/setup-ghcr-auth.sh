#!/bin/bash

# Kubernetes Homelab - GitHub Container Registry Authentication Setup
# This script helps you set up authentication for GitHub Container Registry

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

USERNAME="jconover"
GHCR_REGISTRY="ghcr.io"

log "GitHub Container Registry Authentication Setup"
log "=============================================="
log ""
log "This script will help you authenticate with GitHub Container Registry (ghcr.io)"
log ""

# Check if GITHUB_TOKEN is already set
if [[ -n "$GITHUB_TOKEN" ]]; then
    log "GITHUB_TOKEN environment variable is already set"
    read -p "Do you want to use the existing token? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Using existing GITHUB_TOKEN..."
        echo "$GITHUB_TOKEN" | docker login $GHCR_REGISTRY -u $USERNAME --password-stdin
        if [[ $? -eq 0 ]]; then
            log "✅ Successfully authenticated with GitHub Container Registry!"
            log "You can now run ./scripts/build-and-push.sh to push to both registries"
        else
            error "Failed to authenticate with GitHub Container Registry"
        fi
        exit 0
    fi
fi

log "To authenticate with GitHub Container Registry, you need a Personal Access Token (PAT)"
log "with 'write:packages' permission."
log ""
log "Here's how to create one:"
log ""
log "1. Go to: https://github.com/settings/tokens"
log "2. Click 'Generate new token' → 'Generate new token (classic)'"
log "3. Give it a name like 'Kubernetes Homelab - Container Registry'"
log "4. Set expiration (recommend 1 year or no expiration for homelab)"
log "5. Select the 'write:packages' scope"
log "6. Click 'Generate token'"
log "7. Copy the token (you won't see it again!)"
log ""

read -p "Do you have a GitHub Personal Access Token ready? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Please create a GitHub Personal Access Token first, then run this script again."
    log ""
    log "Token requirements:"
    log "- Scope: write:packages"
    log "- Expiration: 1 year or no expiration (recommended for homelab)"
    exit 0
fi

log ""
log "Enter your GitHub Personal Access Token:"
read -s GITHUB_TOKEN

if [[ -z "$GITHUB_TOKEN" ]]; then
    error "No token provided"
fi

log ""
log "Testing authentication..."

# Test the token
echo "$GITHUB_TOKEN" | docker login $GHCR_REGISTRY -u $USERNAME --password-stdin

if [[ $? -eq 0 ]]; then
    log "✅ Successfully authenticated with GitHub Container Registry!"
    log ""
    log "To make this permanent, add the following to your ~/.bashrc or ~/.zshrc:"
    log "export GITHUB_TOKEN=\"$GITHUB_TOKEN\""
    log ""
    log "Or create a .env file in your project root with:"
    log "GITHUB_TOKEN=$GITHUB_TOKEN"
    log ""
    log "You can now run ./scripts/build-and-push.sh to push to both registries!"
    log ""
    log "Your images will be available at:"
    log "- Docker Hub: https://hub.docker.com/repositories/jconover"
    log "- GitHub Container Registry: https://github.com/jconover?tab=packages"
else
    error "Failed to authenticate with GitHub Container Registry. Please check your token."
fi
