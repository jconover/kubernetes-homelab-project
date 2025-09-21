#!/bin/bash

# Kubernetes Homelab - ETCD Cleanup Helper
# This script cleans up existing etcd data to allow fresh cluster initialization

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "ETCD cleanup helper - removing existing cluster data"

# Check if etcd data exists
if [[ ! -d /var/lib/etcd ]]; then
    log "No etcd data found - nothing to clean up"
    exit 0
fi

if [[ ! "$(ls -A /var/lib/etcd 2>/dev/null)" ]]; then
    log "ETCD directory is empty - nothing to clean up"
    exit 0
fi

warn "Found existing etcd data in /var/lib/etcd"
warn "This will completely remove all existing cluster data!"

# Ask for confirmation
read -p "Are you sure you want to remove all existing cluster data? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Cleanup cancelled"
    exit 0
fi

log "Stopping Kubernetes services..."
systemctl stop kubelet 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true

log "Removing existing cluster data..."
rm -rf /var/lib/etcd
rm -rf /etc/kubernetes
rm -rf /var/lib/kubelet

log "Resetting kubeadm..."
kubeadm reset --force 2>/dev/null || true

log "Restarting containerd..."
systemctl start containerd
sleep 3

log "✅ ETCD cleanup completed successfully!"
log "You can now run ./02-init-master.sh to initialize a fresh cluster"
