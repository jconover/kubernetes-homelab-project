#!/bin/bash

# Kubernetes Homelab - Cleanup Script
# This script removes all deployed components and cleans up the cluster

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    warn "kubectl not found. Some cleanup operations will be skipped."
    KUBECTL_AVAILABLE=false
else
    KUBECTL_AVAILABLE=true
fi

# Function to remove namespace and all resources
remove_namespace() {
    local namespace="$1"
    
    if [[ "$KUBECTL_AVAILABLE" == "true" ]]; then
        if kubectl get namespace "$namespace" &> /dev/null; then
            log "Removing namespace: $namespace"
            kubectl delete namespace "$namespace" || warn "Failed to delete namespace $namespace"
        else
            info "Namespace $namespace does not exist"
        fi
    else
        info "Skipping namespace removal - kubectl not available"
    fi
}

# Function to remove Helm releases
remove_helm_releases() {
    log "Removing Helm releases..."
    
    if command -v helm &> /dev/null; then
        # List all Helm releases
        local releases=$(helm list --all-namespaces -q 2>/dev/null || echo "")
        
        if [[ -n "$releases" ]]; then
            for release in $releases; do
                log "Removing Helm release: $release"
                helm uninstall "$release" || warn "Failed to uninstall Helm release $release"
            done
        else
            info "No Helm releases found"
        fi
    else
        info "Helm not found, skipping Helm cleanup"
    fi
}

# Function to remove Cilium
remove_cilium() {
    log "Removing Cilium CNI..."
    
    if [[ "$KUBECTL_AVAILABLE" == "true" ]]; then
        if command -v cilium &> /dev/null; then
            cilium uninstall || warn "Failed to uninstall Cilium via CLI"
        else
            info "Cilium CLI not found, removing manually..."
            kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/v1.15.0/install/kubernetes/quick-install.yaml || warn "Failed to remove Cilium manifests"
        fi
    else
        info "Skipping Cilium removal - kubectl not available"
    fi
}

# Function to remove MetalLB
remove_metallb() {
    log "Removing MetalLB..."
    
    if [[ "$KUBECTL_AVAILABLE" == "true" ]]; then
        kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.0/config/manifests/metallb-native.yaml || warn "Failed to remove MetalLB manifests"
    else
        info "Skipping MetalLB removal - kubectl not available"
    fi
}

# Function to reset kubeadm
reset_kubeadm() {
    log "Resetting kubeadm..."
    
    if [[ "$KUBECTL_AVAILABLE" == "true" ]]; then
        if kubectl cluster-info &> /dev/null; then
            kubeadm reset --force
        else
            info "Cluster is not accessible, skipping kubeadm reset"
        fi
    else
        info "Skipping kubeadm reset - kubectl not available"
    fi
}

# Function to clean up system packages
cleanup_packages() {
    log "Cleaning up system packages..."
    
    # Remove Kubernetes packages
    apt-mark unhold kubelet kubeadm kubectl
    apt remove -y kubelet kubeadm kubectl
    
    # Remove containerd
    apt remove -y containerd.io
    
    # Remove Docker repository
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    
    # Remove Kubernetes repository
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Clean up
    apt autoremove -y
    apt autoclean
}

# Function to stop services
stop_services() {
    log "Stopping Kubernetes services..."
    
    # Stop kubelet service
    if systemctl is-active --quiet kubelet; then
        log "Stopping kubelet service..."
        systemctl stop kubelet || warn "Failed to stop kubelet service"
    fi
    
    # Stop containerd service
    if systemctl is-active --quiet containerd; then
        log "Stopping containerd service..."
        systemctl stop containerd || warn "Failed to stop containerd service"
    fi
    
    # Disable services
    systemctl disable kubelet || warn "Failed to disable kubelet service"
    systemctl disable containerd || warn "Failed to disable containerd service"
    
    # Wait for services to stop and volumes to unmount
    log "Waiting for services to stop and volumes to unmount..."
    sleep 5
    
    # Force unmount any remaining kubelet volumes
    log "Unmounting any remaining kubelet volumes..."
    if [[ -d /var/lib/kubelet/pods ]]; then
        find /var/lib/kubelet/pods -name "volumes" -type d | while read vol_dir; do
            find "$vol_dir" -type d -exec umount -l {} \; 2>/dev/null || true
        done
    fi
}

# Function to clean up configuration files
cleanup_configs() {
    log "Cleaning up configuration files..."
    
    # Remove Kubernetes configuration
    rm -rf /etc/kubernetes
    rm -rf /var/lib/etcd
    rm -rf /var/lib/cni
    rm -rf /var/lib/calico
    rm -rf /var/lib/cilium
    rm -rf /var/lib/weave
    
    # Remove kubelet data (with force to handle busy resources)
    log "Removing kubelet data..."
    if [[ -d /var/lib/kubelet ]]; then
        # Try normal removal first
        if rm -rf /var/lib/kubelet 2>/dev/null; then
            log "Kubelet data removed successfully"
        else
            warn "Some kubelet files are busy, using force removal..."
            
            # Try to remove files that aren't busy
            find /var/lib/kubelet -type f -not -path "*/volumes/*" -delete 2>/dev/null || true
            
            # Try to remove empty directories
            find /var/lib/kubelet -type d -empty -delete 2>/dev/null || true
            
            # Try to remove non-volume directories
            find /var/lib/kubelet -type d -not -path "*/volumes/*" -exec rmdir {} \; 2>/dev/null || true
            
            # Final attempt at full removal
            if rm -rf /var/lib/kubelet 2>/dev/null; then
                log "Kubelet data removed after force cleanup"
            else
                warn "Some kubelet files could not be removed (may require reboot)"
                warn "Remaining files will be cleaned up on next boot"
            fi
        fi
    fi
    
    # Remove containerd configuration
    rm -rf /etc/containerd
    rm -rf /var/lib/containerd
    
    # Remove Docker configuration
    rm -rf /var/lib/docker
    
    # Remove Helm configuration
    rm -rf /root/.helm
    rm -rf /home/*/.helm
    
    # Remove kubectl configuration
    rm -rf /root/.kube
    rm -rf /home/*/.kube
    
    # Remove systemd configuration
    rm -f /etc/systemd/system/kubelet.service.d
    rm -f /etc/systemd/system/containerd.service.d
    
    # Remove sysctl configuration
    rm -f /etc/sysctl.d/k8s.conf
    
    # Remove modules configuration
    rm -f /etc/modules-load.d/k8s.conf
    
    # Remove swap configuration
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
}

# Function to clean up network interfaces
cleanup_network() {
    log "Cleaning up network interfaces..."
    
    # Remove CNI interfaces
    ip link delete cni0 2>/dev/null || true
    ip link delete flannel.1 2>/dev/null || true
    ip link delete docker0 2>/dev/null || true
    
    # Flush iptables rules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
    
    # Reset network configuration
    systemctl restart networking
}

# Function to clean up logs
cleanup_logs() {
    log "Cleaning up logs..."
    
    # Remove Kubernetes logs
    rm -rf /var/log/pods
    rm -rf /var/log/containers
    
    # Clear system logs
    journalctl --vacuum-time=1d
}

# Main cleanup function
main() {
    log "Starting Kubernetes Homelab cleanup..."
    
    # Ask for confirmation
    warn "This will completely remove the Kubernetes homelab installation!"
    warn "This includes:"
    warn "- All Kubernetes resources and namespaces"
    warn "- All Helm releases"
    warn "- Cilium CNI and MetalLB"
    warn "- All configuration files"
    warn "- All system packages"
    warn ""
    read -p "Are you sure you want to continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
    
    # Remove namespaces
    remove_namespace "monitoring"
    remove_namespace "databases"
    remove_namespace "metallb-system"
    remove_namespace "kube-system"
    
    # Remove Helm releases
    remove_helm_releases
    
    # Remove CNI and LoadBalancer
    remove_cilium
    remove_metallb
    
    # Reset kubeadm
    reset_kubeadm
    
    # Stop services before cleaning up
    stop_services
    
    # Clean up system packages
    cleanup_packages
    
    # Clean up configuration files
    cleanup_configs
    
    # Clean up network interfaces
    cleanup_network
    
    # Clean up logs
    cleanup_logs
    
    # Reload systemd
    systemctl daemon-reload
    
    log "Cleanup completed successfully!"
    log ""
    log "The system has been restored to its pre-Kubernetes state."
    log ""
    warn "IMPORTANT: A reboot is recommended to:"
    warn "- Unmount any remaining busy kubelet volumes"
    warn "- Clear any remaining network interfaces"
    warn "- Ensure all changes take effect"
    log ""
    read -p "Do you want to reboot the system now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        reboot
    else
        log "Please reboot the system manually when convenient."
        log "Some files may remain until after reboot."
    fi
}

# Run main function
main "$@"
