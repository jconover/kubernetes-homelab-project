# Kubernetes Homelab - Quick Reference

## 🚀 Quick Start Commands

### Check Application Status
```bash
# All pods
kubectl get pods -A

# Application pods only
kubectl get pods -n applications

# Services with external IPs
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

### Deploy Applications

#### Option 1: ArgoCD (Recommended)
```bash
kubectl apply -f manifests/applications/
```

#### Option 2: Manual
```bash
kubectl create namespace applications
kubectl apply -f manifests/apps/
```

### Access Applications
```bash
# Get external IPs
kubectl get svc -n applications

# Test health
curl http://<IP>:80/health      # React
curl http://<IP>:8000/health    # Python API
curl http://<IP>:3000/health    # Node.js
```

## 🔐 Access Credentials

### ArgoCD
- **URL**: https://192.168.68.245
- **Username**: admin
- **Password**: `iVvsizy9dhqwkPF1`

### Grafana
- **URL**: http://<GRAFANA-IP>:3000
- **Username**: admin
- **Password**: admin123

### Databases
- **PostgreSQL**: 192.168.68.242:5432 (postgres/postgres123)
- **Redis**: 192.168.68.243:6379 (redis123)
- **RabbitMQ**: 192.168.68.244:15672 (admin/admin123)

## 📊 Monitoring

### Check System Health
```bash
# All namespaces
kubectl get pods -A

# Specific components
kubectl get pods -n argocd
kubectl get pods -n databases
kubectl get pods -n monitoring
```

### View Logs
```bash
# Application logs
kubectl logs -n applications -l app=react-frontend
kubectl logs -n applications -l app=python-api
kubectl logs -n applications -l app=nodejs-service

# System logs
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

## 🛠️ Troubleshooting

### Common Issues
```bash
# Pod not starting
kubectl describe pod <pod-name> -n applications

# Service not accessible
kubectl get svc -n applications
kubectl port-forward svc/<service> -n applications 8080:80

# ArgoCD sync issues
kubectl get applications -n argocd
argocd app sync <app-name>
```

### Reset Everything
```bash
# Clean up applications
kubectl delete namespace applications

# Clean up ArgoCD apps
kubectl delete applications -n argocd --all

# Full cluster reset
sudo ./scripts/cleanup.sh
```

## 🔄 GitHub Actions

### Setup
1. Push code to GitHub
2. Enable Actions in repository settings
3. Add secrets: `KUBECONFIG_DATA`, `GITHUB_TOKEN`
4. Workflows auto-trigger on push

### Manual Trigger
```bash
# Push to trigger
git add .
git commit -m "Deploy applications"
git push
```

## 📁 Key Directories

```
├── apps/                    # Application source code
├── manifests/
│   ├── applications/        # ArgoCD app definitions
│   ├── apps/               # Kubernetes manifests
│   └── monitoring/         # Monitoring configs
├── scripts/                # Deployment scripts
└── docs/                   # Documentation
```

## 🎯 Next Steps

1. **Deploy apps**: `kubectl apply -f manifests/applications/`
2. **Check status**: `kubectl get pods -n applications`
3. **Access ArgoCD**: https://192.168.68.245
4. **Monitor**: Check Grafana dashboards
5. **Develop**: Push changes to trigger CI/CD

---

For detailed information, see [APPLICATION_DEPLOYMENT_GUIDE.md](APPLICATION_DEPLOYMENT_GUIDE.md)
