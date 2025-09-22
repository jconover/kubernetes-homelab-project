# Kubernetes Homelab Deployment Guide

This guide provides step-by-step instructions for deploying the Kubernetes homelab on your 3 Beelink SER5 mini PCs.

## Prerequisites

### Hardware Requirements
- 3x Beelink SER5 mini PCs
- Minimum 4GB RAM per node
- Minimum 20GB storage per node
- Network connectivity between nodes
- SSH access to all nodes

### Software Requirements
- Ubuntu 24.04 LTS installed on all nodes
- Root or sudo access on all nodes
- Network configuration completed

## Network Configuration

### 1. Configure Static IPs
Update the IP addresses in the configuration files to match your network:

```bash
# Edit hosts configuration
vim configs/hosts.txt

# Edit kubeadm configuration
vim configs/kubeadm-config.yaml
```

### 2. Update Network Ranges
Modify the following files to match your network:

- `configs/kubeadm-config.yaml` - Update master node IP
- `manifests/metallb-config.yaml` - Update MetalLB IP pool
- `scripts/04-deploy-networking.sh` - Update MetalLB IP pool

## Deployment Options

### Option 1: Automated Deployment (Recommended)
Run the complete deployment script:

```bash
sudo ./scripts/99-deploy-all.sh
```

This script will:
1. Check prerequisites
2. Install Helm
3. Prepare all nodes
4. Initialize the master node
5. Join worker nodes
6. Deploy networking (Cilium + MetalLB)
7. Deploy monitoring (Prometheus + Grafana)
8. Deploy databases (PostgreSQL + Redis + RabbitMQ)

### Option 2: Manual Step-by-Step Deployment

#### Step 1: Prepare All Nodes
Run on all nodes (master and workers):

```bash
sudo ./scripts/01-prepare-nodes.sh
```

#### Step 2: Initialize Master Node
Run only on the master node:

```bash
sudo ./scripts/02-init-master.sh
```

#### Step 3: Join Worker Nodes
Run on each worker node:

```bash
sudo ./scripts/03-join-workers.sh
```

#### Step 4: Deploy Networking
Run on the master node:

```bash
sudo ./scripts/04-deploy-networking.sh
```

#### Step 5: Deploy Monitoring
Run on the master node:

```bash
sudo ./scripts/05-deploy-monitoring.sh
```

#### Step 6: Deploy Databases
Run on the master node:

```bash
sudo ./scripts/06-deploy-databases.sh
```

## Verification

### 1. Check Cluster Status
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### 2. Check Services
```bash
kubectl get services --all-namespaces
```

### 3. Test LoadBalancer Services
```bash
# Get LoadBalancer IPs
kubectl get svc -n monitoring
kubectl get svc -n databases
```

## Accessing Services

### Grafana
- URL: `http://<LoadBalancer-IP>:3000`
- Username: `admin`
- Password: `admin123`

### Prometheus
- URL: `http://<LoadBalancer-IP>:9090`

### PostgreSQL
- Host: `<LoadBalancer-IP>`
- Port: `5432`
- Username: `postgres`
- Password: `postgres123`
- Database: `homelab`

### Redis
- Host: `<LoadBalancer-IP>`
- Port: `6379`

### RabbitMQ
- Management URL: `http://<LoadBalancer-IP>:15672`
- AMQP URL: `<LoadBalancer-IP>:5672`
- Username: `admin`
- Password: `admin123`

## Troubleshooting

### Common Issues

#### 1. Nodes Not Ready
```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
journalctl -u kubelet -f
```

#### 2. Pods Stuck in Pending
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource availability
kubectl top nodes
kubectl top pods --all-namespaces
```

#### 3. LoadBalancer IP Not Assigned
```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Check IP pool configuration
kubectl get ipaddresspool -n metallb-system
```

#### 4. Storage Issues
```bash
# Check storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv
kubectl get pvc --all-namespaces
```

### Logs and Debugging

#### View Pod Logs
```bash
kubectl logs -f deployment/<deployment-name> -n <namespace>
```

#### Check System Logs
```bash
# Kubernetes logs
journalctl -u kubelet -f
journalctl -u containerd -f

# System logs
dmesg | tail -f
```

#### Network Debugging
```bash
# Check CNI status
cilium status

# Check network policies
kubectl get networkpolicies --all-namespaces
```

## Maintenance

### Updating Components
```bash
# Update Helm repositories
helm repo update

# Upgrade specific charts
helm upgrade <release-name> <chart-name>
```

### Backup and Restore
```bash
# Backup etcd
kubectl get all --all-namespaces -o yaml > backup.yaml

# Backup persistent volumes
# (Manual backup of /var/lib/containerd and PVC data)
```

### Scaling
```bash
# Scale deployments
kubectl scale deployment <deployment-name> --replicas=<count> -n <namespace>

# Add more worker nodes
# Run 01-prepare-nodes.sh on new node
# Run join command from master
```

## Security Considerations

### Network Policies
Network policies are deployed by default. Review and customize as needed:

```bash
kubectl get networkpolicies --all-namespaces
```

### RBAC
Review and customize RBAC policies:

```bash
kubectl get clusterroles
kubectl get clusterrolebindings
```

### Secrets Management
Consider using external secret management for production use:

```bash
kubectl get secrets --all-namespaces
```

## Cleanup

To completely remove the homelab installation:

```bash
sudo ./scripts/cleanup.sh
```

This will:
- Remove all Kubernetes resources
- Uninstall all components
- Clean up configuration files
- Remove system packages
- Reset network configuration

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the logs and error messages
3. Check the GitHub repository for updates
4. Create an issue with detailed information

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Cilium Documentation](https://docs.cilium.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
