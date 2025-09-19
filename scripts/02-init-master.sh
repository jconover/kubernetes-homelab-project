#!/bin/bash

# Kubernetes Homelab - Phase 1: Initialize Master Node
# This script initializes the Kubernetes master node

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="../configs/kubeadm-config.yaml"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
fi

log "Starting Kubernetes master node initialization..."

# Verify containerd is running
if ! systemctl is-active --quiet containerd; then
    error "containerd is not running. Please run 01-prepare-nodes.sh first."
fi

# Initialize the cluster
log "Initializing Kubernetes cluster..."
kubeadm init --config="$CONFIG_FILE" --upload-certs

# Configure kubectl for root user
log "Configuring kubectl..."
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Configure kubectl for regular user (if exists)
if id "ubuntu" &>/dev/null; then
    log "Configuring kubectl for ubuntu user..."
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
fi

# Save join command for worker nodes
log "Saving join command for worker nodes..."
kubeadm token create --print-join-command > /tmp/kubeadm-join-command.txt
chmod 644 /tmp/kubeadm-join-command.txt

log "Master node initialization completed successfully!"
log ""
log "IMPORTANT: Save the join command below for worker nodes:"
log "=========================================="
cat /tmp/kubeadm-join-command.txt
log "=========================================="
log ""
log "Next steps:"
log "1. Copy the join command above"
log "2. Run this command on each worker node:"
log "   sudo <join-command>"
log "3. Or use the automated script: ./03-join-workers.sh"
log ""
log "The join command has been saved to: /tmp/kubeadm-join-command.txt"
