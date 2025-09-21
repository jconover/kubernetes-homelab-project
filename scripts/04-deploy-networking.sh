#!/bin/bash

# Kubernetes Homelab - Phase 2: Deploy Networking (Cilium + MetalLB)
# This script deploys Cilium CNI and MetalLB LoadBalancer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CILIUM_VERSION="1.15.0"
METALLB_VERSION="0.14.0"
METALLB_IP_POOL="192.168.68.240-192.168.68.250"  # Your network range

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

# Check if kubectl is available and cluster is ready
check_cluster() {
    log "Checking cluster status..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please ensure Kubernetes is properly installed."
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Please ensure the cluster is running."
    fi
    
    # Check if nodes exist (they may not be Ready yet without CNI)
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    if [[ $total_nodes -eq 0 ]]; then
        error "No nodes found in the cluster."
    fi
    
    # Check if nodes are ready
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    if [[ $ready_nodes -eq 0 ]]; then
        warn "No ready nodes found. This is expected before CNI deployment."
        warn "Nodes will become Ready after Cilium is deployed."
    else
        log "Cluster has $ready_nodes ready node(s) out of $total_nodes total"
    fi
    
    log "Cluster is accessible with $total_nodes node(s)"
}

# Install Cilium CNI
install_cilium() {
    log "Installing Cilium CNI..."
    
    # Install Cilium CLI
    if ! command -v cilium &> /dev/null; then
        log "Installing Cilium CLI..."
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        CLI_ARCH=amd64
        if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    fi
    
    # Install Cilium
    log "Deploying Cilium to the cluster..."
    cilium install --version $CILIUM_VERSION
    
    # Wait for Cilium to be ready
    log "Waiting for Cilium to be ready..."
    cilium status --wait
    
    # Verify nodes are now Ready
    log "Verifying nodes are Ready after CNI deployment..."
    local attempts=0
    local max_attempts=30
    while [[ $attempts -lt $max_attempts ]]; do
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
        local total_nodes=$(kubectl get nodes --no-headers | wc -l)
        
        if [[ $ready_nodes -eq $total_nodes && $ready_nodes -gt 0 ]]; then
            log "All $total_nodes nodes are now Ready!"
            break
        fi
        
        log "Waiting for nodes to become Ready... ($ready_nodes/$total_nodes ready)"
        sleep 10
        ((attempts++))
    done
    
    if [[ $attempts -eq $max_attempts ]]; then
        warn "Timeout waiting for all nodes to become Ready"
        kubectl get nodes
    fi
    
    log "Cilium CNI installed successfully!"
}

# Install MetalLB
install_metallb() {
    log "Installing MetalLB LoadBalancer..."
    
    # Apply MetalLB manifest
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    log "Waiting for MetalLB to be ready..."
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=300s
    
    # Create IP address pool
    log "Creating MetalLB IP address pool..."
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_POOL
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
EOF
    
    log "MetalLB LoadBalancer installed successfully!"
}

# Test networking
test_networking() {
    log "Testing networking setup..."
    
    # Create a test deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  labels:
    app: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test-service
spec:
  selector:
    app: nginx-test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
EOF
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/nginx-test
    
    # Get LoadBalancer IP
    log "Waiting for LoadBalancer IP assignment..."
    local lb_ip=""
    local attempts=0
    while [[ -z "$lb_ip" && $attempts -lt 30 ]]; do
        lb_ip=$(kubectl get service nginx-test-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [[ -z "$lb_ip" ]]; then
            sleep 10
            ((attempts++))
        fi
    done
    
    if [[ -n "$lb_ip" ]]; then
        log "LoadBalancer IP assigned: $lb_ip"
        log "Testing connectivity..."
        if curl -s --connect-timeout 5 "http://$lb_ip" > /dev/null; then
            log "Networking test successful!"
        else
            warn "LoadBalancer IP assigned but connectivity test failed"
        fi
    else
        warn "LoadBalancer IP not assigned within timeout"
    fi
    
    # Clean up test resources
    log "Cleaning up test resources..."
    kubectl delete deployment nginx-test
    kubectl delete service nginx-test-service
}

# Main execution
log "Starting networking deployment (Cilium + MetalLB)..."

# Ensure KUBECONFIG is set
if [[ -z "$KUBECONFIG" ]]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    log "Set KUBECONFIG to /etc/kubernetes/admin.conf"
fi

# Check cluster status
check_cluster

# Install Cilium
install_cilium

# Install MetalLB
install_metallb

# Test networking
test_networking

log "Networking deployment completed successfully!"
log ""
log "Next steps:"
log "1. Verify Cilium status: cilium status"
log "2. Check MetalLB status: kubectl get pods -n metallb-system"
log "3. Deploy monitoring stack: ./05-deploy-monitoring.sh"
log "4. Deploy database services: ./06-deploy-databases.sh"
