#!/bin/bash

# Kubernetes Homelab - Phase 1: Join Worker Nodes
# This script joins worker nodes to the Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MASTER_IP="192.168.68.86"  # Your master node IP
WORKER_NODES=("192.168.68.88" "192.168.68.83")  # Your worker node IPs

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

# Function to get join command from master
get_join_command() {
    log "Getting join command from master node..."
    
    # Try to get join command from master
    if command -v ssh &> /dev/null; then
        # If SSH is available, try to get the command from master
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$MASTER_IP "test -f /tmp/kubeadm-join-command.txt" 2>/dev/null; then
            JOIN_COMMAND=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$MASTER_IP "cat /tmp/kubeadm-join-command.txt" 2>/dev/null)
        else
            warn "Could not retrieve join command from master. Please run this script on the master node first."
            return 1
        fi
    else
        warn "SSH not available. Please manually get the join command from the master node."
        return 1
    fi
}

# Function to join a single worker node
join_worker() {
    local worker_ip=$1
    log "Joining worker node: $worker_ip"
    
    if [[ -z "$JOIN_COMMAND" ]]; then
        error "No join command available"
    fi
    
    # Execute join command on worker node
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$worker_ip "$JOIN_COMMAND" 2>/dev/null; then
        log "Successfully joined worker node: $worker_ip"
    else
        error "Failed to join worker node: $worker_ip"
    fi
}

# Main execution
log "Starting worker node joining process..."

# Check if this is being run on master node
if [[ -f "/etc/kubernetes/admin.conf" ]]; then
    log "Detected master node. Getting join command..."
    
    # Generate new join command
    kubeadm token create --print-join-command > /tmp/kubeadm-join-command.txt
    JOIN_COMMAND=$(cat /tmp/kubeadm-join-command.txt)
    
    log "Join command generated:"
    echo "$JOIN_COMMAND"
    log ""
    
    # Ask user if they want to automatically join worker nodes
    read -p "Do you want to automatically join worker nodes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for worker_ip in "${WORKER_NODES[@]}"; do
            log "Attempting to join worker node: $worker_ip"
            if ping -c 1 -W 3 "$worker_ip" &> /dev/null; then
                join_worker "$worker_ip"
            else
                warn "Cannot reach worker node: $worker_ip"
            fi
        done
    else
        log "Manual join required. Use this command on each worker node:"
        log "sudo $JOIN_COMMAND"
    fi
else
    # This is a worker node, try to get join command and join
    log "Detected worker node. Attempting to join cluster..."
    
    if get_join_command; then
        log "Executing join command..."
        eval "$JOIN_COMMAND"
        log "Worker node joined successfully!"
    else
        error "Could not get join command. Please run this script on the master node first."
    fi
fi

log "Worker node joining process completed!"
log ""
log "To verify the cluster status, run on the master node:"
log "kubectl get nodes"
