#!/bin/bash

# Kubernetes Homelab - Quick Start Script
# This script provides a quick way to get started with the homelab

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

# Display banner
display_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    Kubernetes Homelab Quick Start"
    echo "=========================================="
    echo -e "${NC}"
    echo "This script will help you deploy a complete Kubernetes homelab"
    echo "on your 3 Beelink SER5 mini PCs running Ubuntu 24.04."
    echo ""
}

# Display prerequisites
display_prerequisites() {
    info "Prerequisites:"
    echo "1. 3x Beelink SER5 mini PCs with Ubuntu 24.04"
    echo "2. Minimum 4GB RAM per node"
    echo "3. Minimum 20GB storage per node"
    echo "4. Network connectivity between nodes"
    echo "5. SSH access to all nodes"
    echo "6. Root or sudo access on all nodes"
    echo ""
}

# Display network configuration
display_network_config() {
    info "Network Configuration Required:"
    echo "Before running the deployment, you need to:"
    echo "1. Configure static IPs for all nodes"
    echo "2. Update the configuration files with your network details"
    echo ""
    echo "Files to update:"
    echo "- configs/hosts.txt"
    echo "- configs/kubeadm-config.yaml"
    echo "- manifests/metallb-config.yaml"
    echo "- scripts/04-deploy-networking.sh"
    echo ""
}

# Display deployment options
display_deployment_options() {
    info "Deployment Options:"
    echo "1. Automated deployment (recommended for beginners)"
    echo "2. Manual step-by-step deployment"
    echo "3. View configuration files"
    echo "4. Check prerequisites"
    echo "5. Exit"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Check OS version
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    local os_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [[ "$os_version" != "24.04" ]]; then
        warn "This script is designed for Ubuntu 24.04. Current version: $os_version"
    fi
    
    # Check available disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=20971520  # 20GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. Required: 20GB, Available: $((available_space / 1024 / 1024))GB"
    fi
    
    # Check available memory
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    local required_memory=4096  # 4GB in MB
    
    if [[ $available_memory -lt $required_memory ]]; then
        warn "Low available memory. Recommended: 4GB, Available: ${available_memory}MB"
    fi
    
    log "Prerequisites check completed"
}

# View configuration files
view_config_files() {
    info "Configuration Files:"
    echo "1. Hosts configuration: configs/hosts.txt"
    echo "2. Kubeadm configuration: configs/kubeadm-config.yaml"
    echo "3. MetalLB configuration: manifests/metallb-config.yaml"
    echo "4. Cilium configuration: manifests/cilium-config.yaml"
    echo "5. Network policies: manifests/network-policies.yaml"
    echo ""
    
    read -p "Enter the number of the file you want to view (1-5): " choice
    case $choice in
        1) cat configs/hosts.txt ;;
        2) cat configs/kubeadm-config.yaml ;;
        3) cat manifests/metallb-config.yaml ;;
        4) cat manifests/cilium-config.yaml ;;
        5) cat manifests/network-policies.yaml ;;
        *) echo "Invalid choice" ;;
    esac
}

# Main menu
main_menu() {
    while true; do
        display_banner
        display_prerequisites
        display_network_config
        display_deployment_options
        
        read -p "Enter your choice (1-5): " choice
        case $choice in
            1)
                log "Starting automated deployment..."
                ./scripts/99-deploy-all.sh
                break
                ;;
            2)
                log "Starting manual deployment..."
                echo "Please run the scripts in the following order:"
                echo "1. sudo ./scripts/01-prepare-nodes.sh (on all nodes)"
                echo "2. sudo ./scripts/02-init-master.sh (on master node)"
                echo "3. sudo ./scripts/03-join-workers.sh (on worker nodes)"
                echo "4. sudo ./scripts/04-deploy-networking.sh (on master node)"
                echo "5. sudo ./scripts/05-deploy-monitoring.sh (on master node)"
                echo "6. sudo ./scripts/06-deploy-databases.sh (on master node)"
                break
                ;;
            3)
                view_config_files
                ;;
            4)
                check_prerequisites
                ;;
            5)
                log "Exiting..."
                exit 0
                ;;
            *)
                error "Invalid choice. Please enter 1-5."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Main execution
main() {
    # Check if script is in the correct directory
    if [[ ! -f "scripts/99-deploy-all.sh" ]]; then
        error "Please run this script from the project root directory"
    fi
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    # Run main menu
    main_menu
}

# Run main function
main "$@"
