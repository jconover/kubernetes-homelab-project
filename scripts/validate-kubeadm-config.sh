#!/bin/bash

# Kubernetes Homelab - Kubeadm Config Validator
# This script validates the kubeadm configuration file

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

# Configuration
CONFIG_FILE="../configs/kubeadm-config.yaml"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
fi

log "Validating kubeadm configuration file..."

# Check if kubeadm is installed
if ! command -v kubeadm &> /dev/null; then
    error "kubeadm is not installed. Please run 01-prepare-nodes.sh first."
fi

# Validate the configuration
log "Running kubeadm config validation..."
if kubeadm config validate --config="$CONFIG_FILE" 2>&1; then
    log "✅ Configuration file is valid"
else
    error "❌ Configuration file validation failed"
fi

# Check for deprecated API versions
log "Checking for deprecated API versions..."
if grep -q "kubeadm.k8s.io/v1beta3" "$CONFIG_FILE"; then
    warn "Configuration uses deprecated API version v1beta3"
    warn "This will work but may show deprecation warnings"
    warn "Consider migrating to v1beta4 when possible"
else
    log "✅ Configuration uses current API version"
fi

# Check for common configuration issues
log "Checking for common configuration issues..."

# Check if advertise address is set
if ! grep -q "advertiseAddress:" "$CONFIG_FILE"; then
    warn "No advertiseAddress found in InitConfiguration"
fi

# Check if control plane endpoint is set
if ! grep -q "controlPlaneEndpoint:" "$CONFIG_FILE"; then
    warn "No controlPlaneEndpoint found in ClusterConfiguration"
fi

# Check if pod subnet is set
if ! grep -q "podSubnet:" "$CONFIG_FILE"; then
    warn "No podSubnet found in ClusterConfiguration"
fi

# Check if service subnet is set
if ! grep -q "serviceSubnet:" "$CONFIG_FILE"; then
    warn "No serviceSubnet found in ClusterConfiguration"
fi

log "Configuration validation completed!"
log ""
log "If you see any warnings above, they may need attention before cluster initialization."
