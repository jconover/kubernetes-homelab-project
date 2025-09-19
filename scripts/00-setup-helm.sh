#!/bin/bash

# Kubernetes Homelab - Setup Helm
# This script installs Helm package manager for Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
HELM_VERSION="3.13.0"

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl not found. Please install Kubernetes first."
fi

log "Starting Helm installation..."

# Check if Helm is already installed
if command -v helm &> /dev/null; then
    local current_version=$(helm version --template '{{.Version}}' | sed 's/v//')
    log "Helm is already installed (version: $current_version)"
    
    # Check if version matches
    if [[ "$current_version" == "$HELM_VERSION" ]]; then
        log "Helm version matches required version ($HELM_VERSION)"
    else
        warn "Helm version mismatch. Current: $current_version, Required: $HELM_VERSION"
        read -p "Do you want to upgrade Helm? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Upgrading Helm to version $HELM_VERSION..."
        else
            log "Skipping Helm upgrade"
            exit 0
        fi
    fi
fi

# Download and install Helm
log "Downloading Helm version $HELM_VERSION..."
cd /tmp

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        HELM_ARCH="amd64"
        ;;
    aarch64)
        HELM_ARCH="arm64"
        ;;
    armv7l)
        HELM_ARCH="arm"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        ;;
esac

# Download Helm
HELM_URL="https://get.helm.sh/helm-v${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz"
log "Downloading from: $HELM_URL"

if ! wget -q "$HELM_URL" -O helm.tar.gz; then
    error "Failed to download Helm"
fi

# Verify download
if ! tar -tzf helm.tar.gz > /dev/null 2>&1; then
    error "Downloaded file is not a valid tar.gz archive"
fi

# Extract and install
log "Extracting and installing Helm..."
tar -xzf helm.tar.gz
sudo mv linux-${HELM_ARCH}/helm /usr/local/bin/
rm -rf linux-${HELM_ARCH} helm.tar.gz

# Verify installation
if ! helm version --client &> /dev/null; then
    error "Helm installation failed"
fi

log "Helm installed successfully!"
helm version --client

# Add common Helm repositories
log "Adding common Helm repositories..."

# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Add Prometheus Community repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana repository
helm repo add grafana https://grafana.github.io/helm-charts

# Add Cilium repository
helm repo add cilium https://helm.cilium.io/

# Add MetalLB repository
helm repo add metallb https://metallb.github.io/metallb

# Add RabbitMQ repository
helm repo add rabbitmq https://charts.bitnami.com/bitnami

# Add PostgreSQL repository
helm repo add postgresql https://charts.bitnami.com/bitnami

# Add Redis repository
helm repo add redis https://charts.bitnami.com/bitnami

# Update repositories
log "Updating Helm repositories..."
helm repo update

log "Helm setup completed successfully!"
log ""
log "Available repositories:"
helm repo list
log ""
log "Next steps:"
log "1. Run the cluster setup scripts in order"
log "2. Use Helm to install additional charts as needed"
log ""
log "Example Helm commands:"
log "- List available charts: helm search repo <chart-name>"
log "- Install a chart: helm install <release-name> <chart-name>"
log "- List installed releases: helm list"
log "- Uninstall a release: helm uninstall <release-name>"
