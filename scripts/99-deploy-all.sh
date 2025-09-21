#!/bin/bash

# Kubernetes Homelab - Deploy All
# This script deploys the entire homelab stack in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/kubernetes-homelab-deploy.log"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

# Function to run a script with error handling
run_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        error "Script not found: $script_path"
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log "Making script executable: $script_name"
        chmod +x "$script_path"
    fi
    
    log "Running: $script_name"
    info "=========================================="
    
    if "$script_path"; then
        log "✅ $script_name completed successfully"
    else
        error "❌ $script_name failed"
    fi
    
    info "=========================================="
    log ""
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Check if we're on Ubuntu 24.04
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    local os_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [[ "$os_version" != "24.04" ]]; then
        warn "This script is designed for Ubuntu 24.04. Current version: $os_version"
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space (minimum 20GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=20971520  # 20GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. Required: 20GB, Available: $((available_space / 1024 / 1024))GB"
    fi
    
    # Check available memory (minimum 4GB)
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    local required_memory=4096  # 4GB in MB
    
    if [[ $available_memory -lt $required_memory ]]; then
        warn "Low available memory. Recommended: 4GB, Available: ${available_memory}MB"
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Prerequisites check completed"
}

# Function to display deployment summary
display_summary() {
    log "Deployment Summary"
    info "=========================================="
    
    # Get cluster info
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        info "Cluster Status:"
        kubectl get nodes
        echo ""
        
        info "Namespaces:"
        kubectl get namespaces
        echo ""
        
        info "Services with LoadBalancer:"
        kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
        echo ""
        
        info "Pods by namespace:"
        kubectl get pods --all-namespaces
        echo ""
    fi
    
    info "Deployment completed successfully!"
    info "Check the log file for details: $LOG_FILE"
    info "=========================================="
}

# Function to display next steps
display_next_steps() {
    log "Next Steps:"
    info "=========================================="
    info "1. Verify cluster status: kubectl get nodes"
    info "2. Check all pods: kubectl get pods --all-namespaces"
    info "3. Access services:"
    info "   - Grafana: Check LoadBalancer IP for grafana service in monitoring namespace"
    info "   - Prometheus: Check LoadBalancer IP for prometheus service in monitoring namespace"
    info "   - Databases: Check LoadBalancer IPs for postgresql, redis, rabbitmq in databases namespace"
    info "4. Configure your applications to use the deployed services"
    info "5. Set up monitoring dashboards in Grafana"
    info "6. Configure alerting rules in Prometheus"
    info "=========================================="
}

# Main execution
main() {
    log "Starting Kubernetes Homelab deployment..."
    log "Log file: $LOG_FILE"
    
    # Initialize log file
    echo "Kubernetes Homelab Deployment Log" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    # Check prerequisites
    check_prerequisites
    
    # Ask user for confirmation
    info "This will deploy a complete Kubernetes homelab stack including:"
    info "- Kubernetes cluster with kubeadm"
    info "- Cilium CNI and MetalLB LoadBalancer"
    info "- Prometheus and Grafana monitoring"
    info "- PostgreSQL, Redis, and RabbitMQ databases"
    info ""
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    # Deploy in phases
    log "Starting deployment phases..."
    
    # Phase 1: Prepare nodes
    info "Phase 1: Preparing nodes..."
    run_script "01-prepare-nodes.sh"
    
    # Phase 2: Initialize master
    info "Phase 2: Initializing master node..."
    run_script "02-init-master.sh"
    
    # Phase 3: Join workers
    info "Phase 3: Joining worker nodes..."
    run_script "03-join-workers.sh"
    
    # Phase 4: Deploy networking
    info "Phase 4: Deploying networking (Cilium + MetalLB)..."
    run_script "04-deploy-networking.sh"
    
    # Phase 5: Setup Helm (after cluster is ready)
    info "Phase 5: Setting up Helm..."
    run_script "05-setup-helm.sh"
    
    # Phase 6: Deploy monitoring
    info "Phase 6: Deploying monitoring stack..."
    run_script "06-deploy-monitoring.sh"
    
    # Phase 7: Deploy databases
    info "Phase 7: Deploying database services..."
    run_script "07-deploy-databases.sh"
    
    # Display summary
    display_summary
    
    # Display next steps
    display_next_steps
    
    log "Kubernetes Homelab deployment completed successfully!"
    log "Total deployment time: $(date)"
}

# Run main function
main "$@"
