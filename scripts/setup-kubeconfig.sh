#!/bin/bash

# Kubernetes Homelab - Kubeconfig Setup Helper
# This script sets up kubectl configuration for the current user

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Get current user
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)

log "Setting up kubectl configuration for user: $CURRENT_USER"

# Check if admin.conf exists
if [[ ! -f /etc/kubernetes/admin.conf ]]; then
    error "Kubernetes admin configuration not found at /etc/kubernetes/admin.conf"
    error "Please run 02-init-master.sh first to initialize the cluster"
fi

# Create .kube directory
log "Creating .kube directory..."
mkdir -p "$USER_HOME/.kube"

# Copy admin config to user's home
log "Copying admin configuration to user's home directory..."
sudo cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
sudo chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.kube/config"

# Set proper permissions
chmod 600 "$USER_HOME/.kube/config"

# Set KUBECONFIG environment variable
log "Setting KUBECONFIG environment variable..."
export KUBECONFIG="$USER_HOME/.kube/config"

# Add to shell profile
SHELL_PROFILE="$USER_HOME/.bashrc"
if [[ -f "$SHELL_PROFILE" ]]; then
    if ! grep -q "KUBECONFIG" "$SHELL_PROFILE"; then
        echo 'export KUBECONFIG="$HOME/.kube/config"' >> "$SHELL_PROFILE"
        log "Added KUBECONFIG to $SHELL_PROFILE"
    else
        log "KUBECONFIG already exists in $SHELL_PROFILE"
    fi
fi

# Test kubectl
log "Testing kubectl configuration..."
if kubectl cluster-info &> /dev/null; then
    log "✅ kubectl is working correctly"
    log ""
    log "Cluster information:"
    kubectl cluster-info
    log ""
    log "Node status:"
    kubectl get nodes
else
    error "❌ kubectl configuration failed"
fi

log "Kubeconfig setup completed successfully!"
log ""
log "You can now use kubectl commands. The configuration will persist across shell sessions."
log ""
log "To test: kubectl get nodes"
