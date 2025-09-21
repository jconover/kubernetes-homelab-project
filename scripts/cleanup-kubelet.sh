#!/bin/bash

# Kubernetes Homelab - Kubelet Cleanup Helper
# This script helps clean up busy kubelet volumes

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

log "Kubelet cleanup helper - fixing busy volume issues"

# Stop kubelet service
if systemctl is-active --quiet kubelet; then
    log "Stopping kubelet service..."
    systemctl stop kubelet
    sleep 3
else
    log "Kubelet service is not running"
fi

# Check for busy kubelet volumes
if [[ -d /var/lib/kubelet/pods ]]; then
    log "Checking for busy kubelet volumes..."
    
    # Find and unmount busy volumes
    find /var/lib/kubelet/pods -name "volumes" -type d | while read vol_dir; do
        if [[ -d "$vol_dir" ]]; then
            log "Processing volume directory: $vol_dir"
            find "$vol_dir" -type d -exec umount -l {} \; 2>/dev/null || true
        fi
    done
    
    # Wait for unmounting to complete
    sleep 2
    
    # Try to remove kubelet data
    log "Attempting to remove kubelet data..."
    if rm -rf /var/lib/kubelet 2>/dev/null; then
        log "✅ Kubelet data removed successfully"
    else
        warn "Some files are still busy. Trying force removal..."
        
        # Force remove non-volume files
        find /var/lib/kubelet -type f -not -path "*/volumes/*" -delete 2>/dev/null || true
        find /var/lib/kubelet -type d -empty -delete 2>/dev/null || true
        
        # Try again
        if rm -rf /var/lib/kubelet 2>/dev/null; then
            log "✅ Kubelet data removed after force cleanup"
        else
            warn "⚠️  Some files are still busy and cannot be removed"
            warn "These files will be cleaned up on next reboot"
            
            # Show what's still busy
            log "Remaining busy files:"
            find /var/lib/kubelet -type f 2>/dev/null | head -10 || true
        fi
    fi
else
    log "No kubelet pod data found"
fi

log "Kubelet cleanup completed!"
log ""
log "If files are still busy, a reboot will clean them up completely."

