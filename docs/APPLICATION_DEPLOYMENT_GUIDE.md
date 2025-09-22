# Application Deployment Guide

This guide covers how to deploy, monitor, and manage applications in your Kubernetes homelab.

## Table of Contents

1. [Application Deployment Methods](#application-deployment-methods)
2. [Checking Application Status](#checking-application-status)
3. [ArgoCD Deployment (GitOps)](#argocd-deployment-gitops)
4. [Manual Deployment](#manual-deployment)
5. [GitHub Actions Setup](#github-actions-setup)
6. [Troubleshooting](#troubleshooting)
7. [Application Access](#application-access)

## Application Deployment Methods

### Available Applications

Your homelab includes three sample applications:

- **React Frontend** - Modern React app with nginx
- **Python API** - FastAPI backend with database integration
- **Node.js Service** - Express.js microservice with Redis

### Deployment Options

1. **ArgoCD (Recommended)** - GitOps approach with automatic sync
2. **Manual kubectl** - Direct deployment using manifests
3. **GitHub Actions** - Automated CI/CD pipeline

## Checking Application Status

### 1. Check All Pods
```bash
# View all pods across all namespaces
kubectl get pods -A

# Filter for application pods only
kubectl get pods -A | grep -E "(react|python|nodejs)"
```

### 2. Check Application Namespace
```bash
# Check if applications namespace exists
kubectl get namespaces | grep applications

# View all resources in applications namespace
kubectl get all -n applications
```

### 3. Check Services and LoadBalancers
```bash
# Check all services
kubectl get svc -A

# Check LoadBalancer services (external access)
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Check specific application services
kubectl get svc -n applications
```

### 4. Check ArgoCD Applications
```bash
# List ArgoCD applications
kubectl get applications -n argocd

# Check specific application status
kubectl describe application react-frontend -n argocd
kubectl describe application python-api -n argocd
kubectl describe application nodejs-service -n argocd
```

### 5. Health Check Endpoints
```bash
# Get external IPs first
kubectl get svc -n applications

# Test health endpoints (replace with actual IPs)
curl http://<REACT-IP>:80/health
curl http://<PYTHON-IP>:8000/health
curl http://<NODEJS-IP>:3000/health

# Test metrics endpoints
curl http://<PYTHON-IP>:8000/metrics
curl http://<NODEJS-IP>:3000/metrics
```

## ArgoCD Deployment (GitOps)

### Prerequisites
- ArgoCD must be deployed and running
- GitHub repository must be accessible
- Application manifests must be in the repository

### Method 1: Deploy via ArgoCD Application Manifests

```bash
# Deploy all applications using ArgoCD
kubectl apply -f manifests/applications/

# Check deployment status
kubectl get applications -n argocd
```

### Method 2: Deploy via ArgoCD Web UI

1. **Access ArgoCD UI**
   ```bash
   # Get ArgoCD URL
   kubectl get svc argocd-server -n argocd
   
   # Access via browser: https://192.168.68.245
   # Username: admin
   # Password: iVvsizy9dhqwkPF1
   ```

2. **Create New Application**
   - Click "New App"
   - Fill in application details:
     - **Application Name**: `react-frontend`
     - **Project**: `default`
     - **Sync Policy**: `Automatic`
     - **Repository URL**: `https://github.com/jconover/kubernetes-homelab-project`
     - **Path**: `manifests/apps/react-frontend`
     - **Cluster URL**: `https://kubernetes.default.svc`
     - **Namespace**: `applications`

3. **Repeat for other applications**
   - `python-api` → `manifests/apps/python-api`
   - `nodejs-service` → `manifests/apps/nodejs-service`

### Method 3: ArgoCD CLI

```bash
# Install ArgoCD CLI (if not already installed)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login 192.168.68.245 --username admin --password iVvsizy9dhqwkPF1

# Create applications
argocd app create react-frontend \
  --repo https://github.com/jconover/kubernetes-homelab-project \
  --path manifests/apps/react-frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace applications \
  --sync-policy automated

argocd app create python-api \
  --repo https://github.com/jconover/kubernetes-homelab-project \
  --path manifests/apps/python-api \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace applications \
  --sync-policy automated

argocd app create nodejs-service \
  --repo https://github.com/jconover/kubernetes-homelab-project \
  --path manifests/apps/nodejs-service \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace applications \
  --sync-policy automated
```

## Manual Deployment

### Prerequisites
- Application manifests must exist in `manifests/apps/`
- Container images must be available

### Deploy Applications Manually

```bash
# Create applications namespace
kubectl create namespace applications

# Deploy applications
kubectl apply -f manifests/apps/react-frontend/
kubectl apply -f manifests/apps/python-api/
kubectl apply -f manifests/apps/nodejs-service/

# Check deployment status
kubectl get pods -n applications
kubectl get svc -n applications
```

### Build and Push Images (if needed)

```bash
# Build and push all application images
./scripts/build-and-push.sh

# Or build individual applications
docker build -t ghcr.io/jconover/kubernetes-homelab-react-frontend:latest apps/react-frontend/
docker push ghcr.io/jconover/kubernetes-homelab-react-frontend:latest
```

## GitHub Actions Setup

### Prerequisites
- GitHub repository with your code
- GitHub Container Registry access
- Kubernetes cluster accessible from GitHub Actions

### 1. Enable GitHub Actions

1. Go to your GitHub repository
2. Click on "Actions" tab
3. Enable GitHub Actions if prompted

### 2. Configure Secrets

Add these secrets to your GitHub repository:

```bash
# Go to: Settings → Secrets and variables → Actions
# Add the following secrets:

KUBECONFIG_DATA          # Your kubeconfig file content
GITHUB_TOKEN            # GitHub token for registry access
REGISTRY_USERNAME       # Your GitHub username
REGISTRY_PASSWORD       # GitHub Personal Access Token
```

### 3. Workflow Files

The following workflow files are already created:

- `.github/workflows/react-frontend.yml`
- `.github/workflows/python-api.yml`
- `.github/workflows/nodejs-service.yml`

### 4. Workflow Features

Each workflow includes:

- **Build**: Docker image creation
- **Test**: Application testing
- **Push**: Image push to GitHub Container Registry
- **Deploy**: Kubernetes deployment
- **Health Check**: Post-deployment verification

### 5. Trigger Workflows

Workflows are triggered by:

- **Push to main branch**: Automatic deployment
- **Pull requests**: Build and test only
- **Manual trigger**: Via GitHub Actions UI

### 6. Monitor Workflows

```bash
# Check workflow status
# Go to: GitHub → Actions tab

# View workflow logs
# Click on specific workflow run → View logs
```

## Troubleshooting

### Common Issues

#### 1. Applications Not Starting

```bash
# Check pod status
kubectl get pods -n applications

# Check pod logs
kubectl logs -n applications -l app=react-frontend
kubectl logs -n applications -l app=python-api
kubectl logs -n applications -l app=nodejs-service

# Check pod events
kubectl describe pod <pod-name> -n applications
```

#### 2. Services Not Accessible

```bash
# Check service status
kubectl get svc -n applications

# Check LoadBalancer IP assignment
kubectl get svc -n applications -o wide

# Test service connectivity
kubectl port-forward svc/react-frontend -n applications 8080:80
# Then test: curl http://localhost:8080
```

#### 3. ArgoCD Sync Issues

```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Check sync status
kubectl describe application <app-name> -n argocd

# Force sync
argocd app sync <app-name>
```

#### 4. Database Connection Issues

```bash
# Check database pods
kubectl get pods -n databases

# Check database services
kubectl get svc -n databases

# Test database connectivity
kubectl exec -it <app-pod> -n applications -- curl http://postgresql.databases:5432
```

### Debug Commands

```bash
# Get all resources in applications namespace
kubectl get all -n applications

# Check resource quotas
kubectl describe quota -n applications

# Check network policies
kubectl get networkpolicies -n applications

# Check ingress
kubectl get ingress -n applications
```

## Application Access

### External Access

Once deployed, applications are accessible via LoadBalancer IPs:

```bash
# Get external IPs
kubectl get svc -n applications

# Access applications
# React Frontend: http://<EXTERNAL-IP>:80
# Python API: http://<EXTERNAL-IP>:8000
# Node.js Service: http://<EXTERNAL-IP>:3000
```

### Internal Access

Applications can communicate internally using service names:

```bash
# From within the cluster
curl http://react-frontend.applications:80
curl http://python-api.applications:8000
curl http://nodejs-service.applications:3000
```

### Health and Metrics

```bash
# Health checks
curl http://<EXTERNAL-IP>:80/health      # React
curl http://<EXTERNAL-IP>:8000/health    # Python API
curl http://<EXTERNAL-IP>:3000/health    # Node.js

# Metrics (Prometheus)
curl http://<EXTERNAL-IP>:8000/metrics   # Python API
curl http://<EXTERNAL-IP>:3000/metrics   # Node.js
```

## Monitoring and Observability

### Prometheus Metrics

Applications expose metrics at `/metrics` endpoint:

```bash
# Check if metrics are being scraped
kubectl get servicemonitor -n applications

# View metrics in Prometheus
# Access: http://<PROMETHEUS-IP>:9090
```

### Grafana Dashboards

Application dashboards are available in Grafana:

```bash
# Access Grafana
# URL: http://<GRAFANA-IP>:3000
# Username: admin
# Password: admin123
```

### Logs

```bash
# View application logs
kubectl logs -n applications -l app=react-frontend -f
kubectl logs -n applications -l app=python-api -f
kubectl logs -n applications -l app=nodejs-service -f
```

## Best Practices

### 1. GitOps Workflow

- Use ArgoCD for all deployments
- Keep manifests in Git repository
- Enable automatic sync for production
- Use manual sync for staging

### 2. Security

- Use secrets for sensitive data
- Enable network policies
- Regular security updates
- Monitor access logs

### 3. Monitoring

- Set up alerts for critical metrics
- Monitor resource usage
- Track application performance
- Regular health checks

### 4. Backup and Recovery

- Regular database backups
- Configuration backup
- Disaster recovery plan
- Test recovery procedures

## Quick Reference

### Essential Commands

```bash
# Check application status
kubectl get pods -n applications
kubectl get svc -n applications

# Deploy via ArgoCD
kubectl apply -f manifests/applications/

# Check ArgoCD status
kubectl get applications -n argocd

# View logs
kubectl logs -n applications -l app=<app-name>

# Port forward for testing
kubectl port-forward svc/<service-name> -n applications <local-port>:<service-port>
```

### Useful URLs

- **ArgoCD UI**: https://192.168.68.245
- **Grafana**: http://<GRAFANA-IP>:3000
- **Prometheus**: http://<PROMETHEUS-IP>:9090
- **GitHub Actions**: https://github.com/jconover/kubernetes-homelab-project/actions

---

For more detailed information, refer to the main [README.md](../README.md) file.
