#!/bin/bash

# Kubernetes Homelab - Application Status Checker
# This script provides a quick overview of application status

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
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "=========================================="
echo "Kubernetes Homelab - Application Status"
echo "=========================================="
echo

# Check cluster nodes
log "Cluster Nodes:"
kubectl get nodes --no-headers | while read line; do
    node_name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $2}')
    if [[ "$status" == "Ready" ]]; then
        echo -e "  ✅ $node_name: $status"
    else
        echo -e "  ❌ $node_name: $status"
    fi
done
echo

# Check namespaces
log "Namespaces:"
kubectl get namespaces --no-headers | while read line; do
    ns_name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $2}')
    if [[ "$status" == "Active" ]]; then
        echo -e "  ✅ $ns_name: $status"
    else
        echo -e "  ❌ $ns_name: $status"
    fi
done
echo

# Check applications namespace
if kubectl get namespace applications &> /dev/null; then
    log "Applications Status:"
    kubectl get pods -n applications --no-headers 2>/dev/null | while read line; do
        pod_name=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        status=$(echo $line | awk '{print $3}')
        if [[ "$status" == "Running" && "$ready" =~ ^[1-9]/[1-9]$ ]]; then
            echo -e "  ✅ $pod_name: $ready $status"
        else
            echo -e "  ❌ $pod_name: $ready $status"
        fi
    done
    
    # Check services
    log "Application Services:"
    kubectl get svc -n applications --no-headers 2>/dev/null | while read line; do
        svc_name=$(echo $line | awk '{print $1}')
        svc_type=$(echo $line | awk '{print $2}')
        external_ip=$(echo $line | awk '{print $4}')
        if [[ "$external_ip" != "<none>" && "$external_ip" != "" ]]; then
            echo -e "  ✅ $svc_name ($svc_type): $external_ip"
        else
            echo -e "  ⚠️  $svc_name ($svc_type): No external IP"
        fi
    done
else
    warn "Applications namespace not found. Applications may not be deployed yet."
    info "To deploy applications: kubectl apply -f manifests/applications/"
fi
echo

# Check ArgoCD
if kubectl get namespace argocd &> /dev/null; then
    log "ArgoCD Status:"
    kubectl get applications -n argocd --no-headers 2>/dev/null | while read line; do
        app_name=$(echo $line | awk '{print $1}')
        sync_status=$(echo $line | awk '{print $2}')
        health_status=$(echo $line | awk '{print $3}')
        if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
            echo -e "  ✅ $app_name: $sync_status, $health_status"
        else
            echo -e "  ❌ $app_name: $sync_status, $health_status"
        fi
    done
    
    # Get ArgoCD server info
    argocd_svc=$(kubectl get svc argocd-server -n argocd --no-headers 2>/dev/null)
    if [[ -n "$argocd_svc" ]]; then
        external_ip=$(echo $argocd_svc | awk '{print $4}')
        if [[ "$external_ip" != "<none>" && "$external_ip" != "" ]]; then
            echo -e "  🌐 ArgoCD UI: https://$external_ip"
        fi
    fi
else
    warn "ArgoCD namespace not found. ArgoCD may not be deployed yet."
fi
echo

# Check databases
if kubectl get namespace databases &> /dev/null; then
    log "Database Status:"
    kubectl get pods -n databases --no-headers 2>/dev/null | while read line; do
        pod_name=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        status=$(echo $line | awk '{print $3}')
        if [[ "$status" == "Running" && "$ready" =~ ^[1-9]/[1-9]$ ]]; then
            echo -e "  ✅ $pod_name: $ready $status"
        else
            echo -e "  ❌ $pod_name: $ready $status"
        fi
    done
    
    # Get database external IPs
    log "Database Access:"
    kubectl get svc -n databases --no-headers 2>/dev/null | while read line; do
        svc_name=$(echo $line | awk '{print $1}')
        external_ip=$(echo $line | awk '{print $4}')
        port=$(echo $line | awk '{print $5}' | cut -d: -f1)
        if [[ "$external_ip" != "<none>" && "$external_ip" != "" ]]; then
            echo -e "  🌐 $svc_name: $external_ip:$port"
        fi
    done
else
    warn "Databases namespace not found. Databases may not be deployed yet."
fi
echo

# Check monitoring
if kubectl get namespace monitoring &> /dev/null; then
    log "Monitoring Status:"
    kubectl get pods -n monitoring --no-headers 2>/dev/null | while read line; do
        pod_name=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        status=$(echo $line | awk '{print $3}')
        if [[ "$status" == "Running" && "$ready" =~ ^[1-9]/[1-9]$ ]]; then
            echo -e "  ✅ $pod_name: $ready $status"
        else
            echo -e "  ❌ $pod_name: $ready $status"
        fi
    done
    
    # Get monitoring external IPs
    log "Monitoring Access:"
    kubectl get svc -n monitoring --no-headers 2>/dev/null | while read line; do
        svc_name=$(echo $line | awk '{print $1}')
        svc_type=$(echo $line | awk '{print $2}')
        external_ip=$(echo $line | awk '{print $4}')
        if [[ "$svc_type" == "LoadBalancer" && "$external_ip" != "<none>" && "$external_ip" != "" ]]; then
            port=$(echo $line | awk '{print $5}' | cut -d: -f1)
            if [[ "$svc_name" == "grafana" ]]; then
                echo -e "  📊 Grafana: http://$external_ip:$port (admin/admin123)"
            elif [[ "$svc_name" == "prometheus" ]]; then
                echo -e "  📈 Prometheus: http://$external_ip:$port"
            fi
        fi
    done
else
    warn "Monitoring namespace not found. Monitoring may not be deployed yet."
fi
echo

# Summary
echo "=========================================="
echo "Quick Commands:"
echo "=========================================="
echo "Deploy applications: kubectl apply -f manifests/applications/"
echo "Check pods: kubectl get pods -A"
echo "Check services: kubectl get svc -A"
echo "View logs: kubectl logs -n applications -l app=<app-name>"
echo "Port forward: kubectl port-forward svc/<service> -n applications 8080:80"
echo
echo "Documentation:"
echo "- Application Guide: docs/APPLICATION_DEPLOYMENT_GUIDE.md"
echo "- Quick Reference: docs/QUICK_REFERENCE.md"
echo "=========================================="
