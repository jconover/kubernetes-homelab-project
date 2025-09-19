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

4. **Deploy networking:**
   ```bash
   ./scripts/04-deploy-networking.sh
   ```

5. **Deploy monitoring:**
   ```bash
   ./scripts/05-deploy-monitoring.sh
   ```

6. **Deploy databases:**
   ```bash
   ./scripts/06-deploy-databases.sh
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

## Security Notes

- This setup is for homelab use only
- Default configurations may not be suitable for production
- Review and customize security settings as needed
# kubernetes-homelab-project
