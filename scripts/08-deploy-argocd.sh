#!/bin/bash

# Kubernetes Homelab - Deploy ArgoCD
# This script deploys ArgoCD for GitOps deployment automation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_VERSION="2.8.4"
ARGOCD_NAMESPACE="argocd"

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
    
    # Check if nodes are ready
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    if [[ $ready_nodes -eq 0 ]]; then
        error "No ready nodes found in the cluster."
    fi
    
    log "Cluster is ready with $ready_nodes node(s)"
}

# Install ArgoCD
install_argocd() {
    log "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n $ARGOCD_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n $ARGOCD_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n $ARGOCD_NAMESPACE
    
    log "ArgoCD installed successfully!"
}

# Configure ArgoCD
configure_argocd() {
    log "Configuring ArgoCD..."
    
    # Patch ArgoCD server to use LoadBalancer
    kubectl patch svc argocd-server -n $ARGOCD_NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}'
    
    # Wait for LoadBalancer IP
    log "Waiting for LoadBalancer IP assignment..."
    local lb_ip=""
    local attempts=0
    while [[ -z "$lb_ip" && $attempts -lt 30 ]]; do
        lb_ip=$(kubectl get service argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [[ -z "$lb_ip" ]]; then
            sleep 10
            ((attempts++))
        fi
    done
    
    if [[ -n "$lb_ip" ]]; then
        log "ArgoCD LoadBalancer IP assigned: $lb_ip"
    else
        warn "LoadBalancer IP not assigned within timeout"
    fi
    
    # Get initial admin password
    local admin_password=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log "ArgoCD configuration completed!"
    log ""
    log "ArgoCD Access Information:"
    log "=========================="
    if [[ -n "$lb_ip" ]]; then
        log "URL: https://$lb_ip"
    else
        log "URL: Check with 'kubectl get svc argocd-server -n $ARGOCD_NAMESPACE'"
    fi
    log "Username: admin"
    log "Password: $admin_password"
    log ""
    log "To access ArgoCD CLI:"
    log "kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
    log "Then visit: https://localhost:8080"
}

# Create application manifests
create_app_manifests() {
    log "Creating application manifests..."
    
    # Create applications directory
    mkdir -p ../manifests/applications
    
    # Create React frontend application
    cat <<EOF > ../manifests/applications/react-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: react-frontend
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: https://github.com/jconover/kubernetes-homelab-project
    targetRevision: HEAD
    path: manifests/apps/react-frontend
  destination:
    server: https://kubernetes.default.svc
    namespace: applications
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create Python API application
    cat <<EOF > ../manifests/applications/python-api.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: python-api
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: https://github.com/jconover/kubernetes-homelab-project
    targetRevision: HEAD
    path: manifests/apps/python-api
  destination:
    server: https://kubernetes.default.svc
    namespace: applications
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create Node.js service application
    cat <<EOF > ../manifests/applications/nodejs-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nodejs-service
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: https://github.com/jconover/kubernetes-homelab-project
    targetRevision: HEAD
    path: manifests/apps/nodejs-service
  destination:
    server: https://kubernetes.default.svc
    namespace: applications
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    log "Application manifests created successfully!"
}

# Install ArgoCD CLI
install_argocd_cli() {
    log "Installing ArgoCD CLI..."
    
    if ! command -v argocd &> /dev/null; then
        # Download ArgoCD CLI
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        
        log "ArgoCD CLI installed successfully!"
    else
        log "ArgoCD CLI already installed"
    fi
}

# Main execution
log "Starting ArgoCD deployment..."

# Check cluster status
check_cluster

# Install ArgoCD
install_argocd

# Configure ArgoCD
configure_argocd

# Create application manifests
create_app_manifests

# Install ArgoCD CLI
install_argocd_cli

log "ArgoCD deployment completed successfully!"
log ""
log "Next steps:"
log "1. Access ArgoCD web UI using the credentials above"
log "2. Create applications in ArgoCD or apply the manifests in manifests/applications/"
log "3. Set up GitHub Actions for CI/CD: ./08-setup-github-actions.sh"
log ""
log "Useful commands:"
log "- Check ArgoCD status: kubectl get pods -n $ARGOCD_NAMESPACE"
log "- Port forward ArgoCD: kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
log "- ArgoCD CLI login: argocd login localhost:8080"
