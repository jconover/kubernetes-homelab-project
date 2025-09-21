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

# Check for existing cluster data and clean up if necessary
log "Checking for existing cluster data..."
if [[ -d /var/lib/etcd && "$(ls -A /var/lib/etcd 2>/dev/null)" ]]; then
    warn "Found existing etcd data in /var/lib/etcd"
    warn "This indicates a previous cluster installation that wasn't properly cleaned up"
    log "Cleaning up existing cluster data..."
    
    # Stop any running services
    systemctl stop kubelet 2>/dev/null || true
    systemctl stop containerd 2>/dev/null || true
    
    # Remove existing cluster data
    rm -rf /var/lib/etcd
    rm -rf /etc/kubernetes
    rm -rf /var/lib/kubelet
    
    # Reset kubeadm
    kubeadm reset --force 2>/dev/null || true
    
    # Restart containerd
    systemctl start containerd
    sleep 3
    
    log "Existing cluster data cleaned up"
fi

# Check if config file needs migration
log "Checking kubeadm configuration..."
if grep -q "kubeadm.k8s.io/v1beta3" "$CONFIG_FILE"; then
    warn "Configuration file uses deprecated API version v1beta3"
    warn "This is expected and will work fine - the warnings can be ignored"
    log "Using v1beta3 configuration (deprecated but functional)"
fi

# Initialize the cluster
log "Initializing Kubernetes cluster..."
log "Note: You may see deprecation warnings about v1beta3 API - these can be safely ignored"
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

# Configure kubectl for current user (if not root)
if [[ "$SUDO_USER" != "" && "$SUDO_USER" != "root" ]]; then
    log "Configuring kubectl for $SUDO_USER user..."
    mkdir -p "/home/$SUDO_USER/.kube"
    cp -i /etc/kubernetes/admin.conf "/home/$SUDO_USER/.kube/config"
    chown "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.kube/config"
    
    # Add KUBECONFIG to user's bashrc
    USER_BASHRC="/home/$SUDO_USER/.bashrc"
    if [[ -f "$USER_BASHRC" ]]; then
        if ! grep -q "KUBECONFIG" "$USER_BASHRC"; then
            echo 'export KUBECONFIG="$HOME/.kube/config"' >> "$USER_BASHRC"
            log "Added KUBECONFIG to $USER_BASHRC"
        fi
    fi
fi

# Save join command for worker nodes
log "Saving join command for worker nodes..."
kubeadm token create --print-join-command > /tmp/kubeadm-join-command.txt
chmod 644 /tmp/kubeadm-join-command.txt

# Set up environment for subsequent scripts
log "Setting up environment for subsequent scripts..."
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc

# Verify kubectl works
log "Verifying kubectl configuration..."
if kubectl cluster-info &> /dev/null; then
    log "kubectl is working correctly"
else
    warn "kubectl configuration may need manual setup"
fi

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
