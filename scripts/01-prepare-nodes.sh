#!/bin/bash

# Kubernetes Homelab - Phase 1: Prepare Nodes
# This script prepares all nodes for Kubernetes installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBERNETES_VERSION="1.34.0"
CONTAINERD_VERSION="1.7.0"

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

log "Starting Kubernetes node preparation..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
log "Installing required packages..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    git \
    vim \
    htop \
    net-tools \
    bridge-utils \
    iptables \
    ipset

# Disable swap
log "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules
log "Configuring kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
log "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
log "Installing containerd..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y containerd.io

# Configure containerd
log "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd

# Install Kubernetes packages
log "Installing Kubernetes packages..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl

# Hold packages to prevent automatic updates
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# Configure hostname (optional - uncomment and modify as needed)
# hostnamectl set-hostname k8s-master-1  # or k8s-worker-1, k8s-worker-2

# Configure /etc/hosts (optional - uncomment and modify as needed)
# echo "192.168.1.10 k8s-master-1" >> /etc/hosts
# echo "192.168.1.11 k8s-worker-1" >> /etc/hosts
# echo "192.168.1.12 k8s-worker-2" >> /etc/hosts

log "Node preparation completed successfully!"
log "Next steps:"
log "1. Run this script on all nodes (master and workers)"
log "2. Initialize the master node with: ./02-init-master.sh"
log "3. Join worker nodes with: ./03-join-workers.sh"
