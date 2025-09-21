#!/bin/bash

# Kubernetes Homelab - Test Deployment Order
# This script tests the deployment order to ensure Cilium is deployed correctly

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

# Test function to simulate the deployment order
test_deployment_order() {
    log "Testing deployment order..."
    
    # Ensure KUBECONFIG is set
    if [[ -z "$KUBECONFIG" ]]; then
        export KUBECONFIG=/etc/kubernetes/admin.conf
        log "Set KUBECONFIG to /etc/kubernetes/admin.conf"
    fi
    
    # Test 1: Check if cluster is accessible
    log "Test 1: Checking cluster accessibility..."
    if kubectl cluster-info &> /dev/null; then
        log "✅ Cluster is accessible"
    else
        error "❌ Cannot access cluster"
    fi
    
    # Test 2: Check node status before CNI
    log "Test 2: Checking node status..."
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    
    info "Total nodes: $total_nodes"
    info "Ready nodes: $ready_nodes"
    
    if [[ $total_nodes -eq 0 ]]; then
        error "❌ No nodes found in cluster"
    fi
    
    if [[ $ready_nodes -eq 0 ]]; then
        warn "⚠️  No ready nodes found (expected before CNI deployment)"
    else
        log "✅ $ready_nodes nodes are ready"
    fi
    
    # Test 3: Check if Cilium is already deployed
    log "Test 3: Checking Cilium status..."
    if kubectl get pods -n kube-system | grep -q cilium; then
        log "✅ Cilium is already deployed"
        
        # Check if all nodes are ready
        local final_ready=$(kubectl get nodes --no-headers | grep -c "Ready")
        if [[ $final_ready -eq $total_nodes ]]; then
            log "✅ All nodes are ready after Cilium deployment"
        else
            warn "⚠️  Not all nodes are ready: $final_ready/$total_nodes"
        fi
    else
        warn "⚠️  Cilium is not deployed yet"
        log "This is expected if you haven't run the networking script yet"
    fi
    
    # Test 4: Check MetalLB status
    log "Test 4: Checking MetalLB status..."
    if kubectl get pods -n metallb-system &> /dev/null; then
        local metallb_pods=$(kubectl get pods -n metallb-system --no-headers | wc -l)
        if [[ $metallb_pods -gt 0 ]]; then
            log "✅ MetalLB is deployed with $metallb_pods pods"
        else
            warn "⚠️  MetalLB namespace exists but no pods found"
        fi
    else
        warn "⚠️  MetalLB is not deployed yet"
    fi
    
    # Test 5: Check LoadBalancer services
    log "Test 5: Checking LoadBalancer services..."
    local lb_services=$(kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer --no-headers | wc -l)
    if [[ $lb_services -gt 0 ]]; then
        log "✅ Found $lb_services LoadBalancer services"
        kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
    else
        warn "⚠️  No LoadBalancer services found"
    fi
    
    log "Deployment order test completed!"
}

# Display current cluster status
display_cluster_status() {
    log "Current cluster status:"
    info "=========================================="
    
    echo "Nodes:"
    kubectl get nodes
    echo ""
    
    echo "Namespaces:"
    kubectl get namespaces
    echo ""
    
    echo "Pods by namespace:"
    kubectl get pods --all-namespaces
    echo ""
    
    echo "Services with LoadBalancer:"
    kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
    echo ""
    
    info "=========================================="
}

# Main execution
main() {
    log "Starting deployment order test..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please ensure Kubernetes is properly installed."
    fi
    
    # Run tests
    test_deployment_order
    
    # Display status
    display_cluster_status
    
    log "Test completed successfully!"
}

# Run main function
main "$@"
