# Kubernetes Homelab Project

A comprehensive Kubernetes homelab setup for 3 Beelink SER5 mini PCs running Ubuntu 24.04.

## Hardware Setup
- 3x Beelink SER5 mini PCs
- Ubuntu 24.04 LTS
- Kubernetes 1.34

## Architecture Overview

### Phase 1: Base Kubernetes Cluster
- kubeadm, kubectl, kubelet installation
- containerd container runtime
- Master node initialization
- Worker node joining

### Phase 2: Networking & Load Balancing
- Cilium CNI for advanced networking
- MetalLB for LoadBalancer services
- Network policies and security

### Phase 3: Monitoring Stack
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for notifications

### Phase 4: Database & Message Queue Services
- PostgreSQL database
- Redis cache/session store
- RabbitMQ message broker

## Quick Start

### Automated Deployment
```bash
# Deploy everything automatically (recommended)
sudo ./scripts/99-deploy-all.sh
```

### Manual Deployment (Step by Step)

1. **Prepare all nodes:**
   ```bash
   ./scripts/01-prepare-nodes.sh
   ```

2. **Initialize master node:**
   ```bash
   ./scripts/02-init-master.sh
   ```

3. **Join worker nodes:**
   ```bash
   ./scripts/03-join-workers.sh
   ```

4. **Deploy networking (CRITICAL):**
   ```bash
   ./scripts/04-deploy-networking.sh
   ```

5. **Setup Helm (optional):**
   ```bash
   ./scripts/05-setup-helm.sh
   ```

6. **Deploy monitoring:**
   ```bash
   ./scripts/06-deploy-monitoring.sh
   ```

7. **Deploy databases:**
   ```bash
   ./scripts/07-deploy-databases.sh
   ```

## ⚠️ Important: Deployment Order & Troubleshooting

### Why the Order Matters
The scripts must be run in the exact order shown above because:

1. **Nodes will be "NotReady" until CNI is deployed** - This is normal and expected
2. **Cilium CNI must be deployed before other services** - Other services need networking to function
3. **Helm requires a running cluster** - Helm needs kubectl and a cluster to add repositories and deploy charts
4. **KUBECONFIG must be properly set** - All scripts now automatically set this

### Common Issues & Solutions

**Issue:** `kubectl get nodes` shows nodes as "NotReady"
- **Solution:** This is expected before running `04-deploy-networking.sh`. Run the networking script and nodes will become Ready.

**Issue:** Helm setup fails with "kubectl not found"
- **Solution:** Helm is now installed after the cluster is ready. Run `05-setup-helm.sh` after the networking script.

**Issue:** `kubectl` commands fail with certificate errors
- **Solution:** The scripts now automatically set `KUBECONFIG=/etc/kubernetes/admin.conf`

**Issue:** LoadBalancer services don't get external IPs
- **Solution:** Ensure MetalLB is deployed and the IP pool is configured correctly

### Testing the Deployment
```bash
# Test the deployment order and cluster status
./scripts/test-deployment-order.sh
```

## Directory Structure

```
├── README.md
├── scripts/           # Deployment scripts
├── manifests/         # Kubernetes manifests
├── configs/          # Configuration files
├── helm/             # Helm charts
└── docs/             # Additional documentation
```

## Prerequisites

- 3x Beelink SER5 with Ubuntu 24.04
- At least 4GB RAM per node
- At least 20GB storage per node
- Network connectivity between nodes
- SSH access to all nodes

## Network Configuration

Default network ranges:
- Pod CIDR: 10.244.0.0/16
- Service CIDR: 10.96.0.0/12
- MetalLB IP Pool: 192.168.1.240-192.168.1.250

## Documentation

- **[Application Deployment Guide](docs/APPLICATION_DEPLOYMENT_GUIDE.md)** - Complete guide for deploying and managing applications
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Essential commands and access information
- **[Deployment Order & Troubleshooting](docs/DEPLOYMENT_ORDER_FIXES.md)** - Common issues and solutions

## Security Notes

- This setup is for homelab use only
- Default configurations may not be suitable for production
- Review and customize security settings as needed

