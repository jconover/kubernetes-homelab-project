# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Kubernetes homelab deployment.

## Table of Contents

1. [Cluster Issues](#cluster-issues)
2. [Networking Issues](#networking-issues)
3. [Storage Issues](#storage-issues)
4. [Monitoring Issues](#monitoring-issues)
5. [Database Issues](#database-issues)
6. [Performance Issues](#performance-issues)
7. [Security Issues](#security-issues)

## Cluster Issues

### Nodes Not Ready

#### Symptoms
- Nodes show as `NotReady` in `kubectl get nodes`
- Pods cannot be scheduled

#### Diagnosis
```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet status
systemctl status kubelet

# Check kubelet logs
journalctl -u kubelet -f
```

#### Solutions
1. **Check containerd status:**
   ```bash
   systemctl status containerd
   systemctl restart containerd
   ```

2. **Check swap:**
   ```bash
   swapoff -a
   sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   ```

3. **Check kernel modules:**
   ```bash
   modprobe overlay
   modprobe br_netfilter
   ```

4. **Check sysctl parameters:**
   ```bash
   sysctl net.bridge.bridge-nf-call-iptables=1
   sysctl net.bridge.bridge-nf-call-ip6tables=1
   sysctl net.ipv4.ip_forward=1
   ```

### Pods Stuck in Pending

#### Symptoms
- Pods remain in `Pending` state
- No events or error messages

#### Diagnosis
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource availability
kubectl top nodes
kubectl describe nodes
```

#### Solutions
1. **Check resource constraints:**
   ```bash
   # Check available resources
   kubectl describe nodes
   
   # Check resource requests/limits
   kubectl get pods -o wide --all-namespaces
   ```

2. **Check node selectors and affinity:**
   ```bash
   kubectl get pods -o yaml | grep -A 10 nodeSelector
   ```

3. **Check taints and tolerations:**
   ```bash
   kubectl describe nodes | grep -A 5 Taints
   ```

### Master Node Issues

#### Symptoms
- Cannot connect to cluster
- API server not responding

#### Diagnosis
```bash
# Check API server status
kubectl cluster-info

# Check etcd status
systemctl status etcd

# Check API server logs
journalctl -u kube-apiserver -f
```

#### Solutions
1. **Restart API server:**
   ```bash
   systemctl restart kube-apiserver
   systemctl restart kube-controller-manager
   systemctl restart kube-scheduler
   ```

2. **Check etcd:**
   ```bash
   systemctl restart etcd
   ```

3. **Verify certificates:**
   ```bash
   ls -la /etc/kubernetes/pki/
   ```

## Networking Issues

### Cilium Issues

#### Symptoms
- Pods cannot communicate
- Network policies not working
- Cilium pods not ready

#### Diagnosis
```bash
# Check Cilium status
cilium status

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium
```

#### Solutions
1. **Restart Cilium:**
   ```bash
   kubectl delete pods -n kube-system -l k8s-app=cilium
   ```

2. **Check Cilium configuration:**
   ```bash
   kubectl get configmap cilium-config -n kube-system -o yaml
   ```

3. **Verify network policies:**
   ```bash
   kubectl get networkpolicies --all-namespaces
   ```

### MetalLB Issues

#### Symptoms
- LoadBalancer services not getting external IPs
- Services stuck in `pending` state

#### Diagnosis
```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Check IP address pools
kubectl get ipaddresspool -n metallb-system
```

#### Solutions
1. **Check IP pool configuration:**
   ```bash
   kubectl get ipaddresspool -n metallb-system -o yaml
   ```

2. **Verify network range:**
   ```bash
   # Ensure IP pool doesn't conflict with existing network
   ip route show
   ```

3. **Check speaker logs:**
   ```bash
   kubectl logs -n metallb-system -l app=metallb,component=speaker
   ```

### DNS Issues

#### Symptoms
- Pods cannot resolve DNS names
- Services not accessible by name

#### Diagnosis
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

#### Solutions
1. **Restart CoreDNS:**
   ```bash
   kubectl delete pods -n kube-system -l k8s-app=kube-dns
   ```

2. **Check CoreDNS configuration:**
   ```bash
   kubectl get configmap coredns -n kube-system -o yaml
   ```

## Storage Issues

### Persistent Volume Issues

#### Symptoms
- PVCs stuck in `Pending` state
- Pods cannot mount volumes

#### Diagnosis
```bash
# Check PVC status
kubectl get pvc --all-namespaces

# Check PV status
kubectl get pv

# Check storage classes
kubectl get storageclass
```

#### Solutions
1. **Check storage class:**
   ```bash
   kubectl describe storageclass local-path
   ```

2. **Check node storage:**
   ```bash
   df -h
   ls -la /opt/local-path-provisioner
   ```

3. **Check provisioner logs:**
   ```bash
   kubectl logs -n local-path-storage -l app=local-path-provisioner
   ```

### Volume Mount Issues

#### Symptoms
- Pods fail to start
- Volume mount errors

#### Diagnosis
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check volume mounts
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 volumeMounts
```

#### Solutions
1. **Check volume permissions:**
   ```bash
   # Check host path permissions
   ls -la /opt/local-path-provisioner
   ```

2. **Verify volume configuration:**
   ```bash
   kubectl get pvc <pvc-name> -n <namespace> -o yaml
   ```

## Monitoring Issues

### Prometheus Issues

#### Symptoms
- Prometheus not scraping metrics
- Targets showing as down

#### Diagnosis
```bash
# Check Prometheus pods
kubectl get pods -n monitoring -l app=prometheus

# Check Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Check targets
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Then visit http://localhost:9090/targets
```

#### Solutions
1. **Check service account permissions:**
   ```bash
   kubectl get clusterrolebinding prometheus
   kubectl describe clusterrolebinding prometheus
   ```

2. **Verify scrape configuration:**
   ```bash
   kubectl get configmap prometheus-config -n monitoring -o yaml
   ```

3. **Check network connectivity:**
   ```bash
   kubectl exec -it deployment/prometheus -n monitoring -- wget -qO- http://kubernetes.default.svc:443/api/v1/nodes
   ```

### Grafana Issues

#### Symptoms
- Grafana not accessible
- Dashboards not loading

#### Diagnosis
```bash
# Check Grafana pods
kubectl get pods -n monitoring -l app=grafana

# Check Grafana logs
kubectl logs -n monitoring -l app=grafana

# Check service
kubectl get svc grafana -n monitoring
```

#### Solutions
1. **Check Grafana configuration:**
   ```bash
   kubectl get configmap grafana-datasources -n monitoring -o yaml
   ```

2. **Verify database connection:**
   ```bash
   kubectl exec -it deployment/grafana -n monitoring -- curl -s http://prometheus:9090/api/v1/query?query=up
   ```

3. **Check resource limits:**
   ```bash
   kubectl describe pod -n monitoring -l app=grafana
   ```

## Database Issues

### PostgreSQL Issues

#### Symptoms
- PostgreSQL not starting
- Connection refused errors

#### Diagnosis
```bash
# Check PostgreSQL pods
kubectl get pods -n databases -l app=postgresql

# Check PostgreSQL logs
kubectl logs -n databases -l app=postgresql

# Check persistent volume
kubectl get pvc postgresql-pvc -n databases
```

#### Solutions
1. **Check database initialization:**
   ```bash
   kubectl exec -it deployment/postgresql -n databases -- psql -U postgres -c "SELECT version();"
   ```

2. **Verify storage:**
   ```bash
   kubectl describe pvc postgresql-pvc -n databases
   ```

3. **Check resource limits:**
   ```bash
   kubectl describe pod -n databases -l app=postgresql
   ```

### Redis Issues

#### Symptoms
- Redis not responding
- Memory issues

#### Diagnosis
```bash
# Check Redis pods
kubectl get pods -n databases -l app=redis

# Check Redis logs
kubectl logs -n databases -l app=redis

# Test Redis connection
kubectl exec -it deployment/redis -n databases -- redis-cli ping
```

#### Solutions
1. **Check Redis configuration:**
   ```bash
   kubectl get configmap redis-config -n databases -o yaml
   ```

2. **Monitor memory usage:**
   ```bash
   kubectl exec -it deployment/redis -n databases -- redis-cli info memory
   ```

3. **Check persistent volume:**
   ```bash
   kubectl describe pvc redis-pvc -n databases
   ```

### RabbitMQ Issues

#### Symptoms
- RabbitMQ not starting
- Management interface not accessible

#### Diagnosis
```bash
# Check RabbitMQ pods
kubectl get pods -n databases -l app=rabbitmq

# Check RabbitMQ logs
kubectl logs -n databases -l app=rabbitmq

# Check management interface
kubectl port-forward svc/rabbitmq 15672:15672 -n databases
# Then visit http://localhost:15672
```

#### Solutions
1. **Check RabbitMQ configuration:**
   ```bash
   kubectl get configmap rabbitmq-config -n databases -o yaml
   ```

2. **Verify Erlang cookie:**
   ```bash
   kubectl exec -it deployment/rabbitmq -n databases -- cat /var/lib/rabbitmq/.erlang.cookie
   ```

3. **Check persistent volume:**
   ```bash
   kubectl describe pvc rabbitmq-pvc -n databases
   ```

## Performance Issues

### High CPU Usage

#### Symptoms
- Nodes showing high CPU usage
- Pods being throttled

#### Diagnosis
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces

# Check system load
kubectl debug node/<node-name> -it --image=busybox -- df -h
```

#### Solutions
1. **Check resource requests/limits:**
   ```bash
   kubectl describe pods --all-namespaces | grep -A 5 "Requests\|Limits"
   ```

2. **Optimize resource allocation:**
   ```bash
   # Update resource requests/limits in deployments
   kubectl edit deployment <deployment-name> -n <namespace>
   ```

3. **Check for resource leaks:**
   ```bash
   kubectl get pods --all-namespaces | grep -E "CrashLoopBackOff|Error|OOMKilled"
   ```

### High Memory Usage

#### Symptoms
- Nodes running out of memory
- Pods being evicted

#### Diagnosis
```bash
# Check memory usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check for memory leaks
kubectl get events --sort-by='.lastTimestamp' | grep -i "memory\|oom"
```

#### Solutions
1. **Check memory limits:**
   ```bash
   kubectl describe pods --all-namespaces | grep -A 5 "Limits"
   ```

2. **Optimize memory usage:**
   ```bash
   # Update memory limits in deployments
   kubectl edit deployment <deployment-name> -n <namespace>
   ```

3. **Check for memory leaks:**
   ```bash
   kubectl logs --all-namespaces | grep -i "memory\|leak"
   ```

## Security Issues

### Network Policy Issues

#### Symptoms
- Pods cannot communicate
- Network policies blocking traffic

#### Diagnosis
```bash
# Check network policies
kubectl get networkpolicies --all-namespaces

# Check policy details
kubectl describe networkpolicy <policy-name> -n <namespace>
```

#### Solutions
1. **Review network policies:**
   ```bash
   kubectl get networkpolicies --all-namespaces -o yaml
   ```

2. **Test connectivity:**
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- wget -qO- http://<service-name>
   ```

3. **Update policies:**
   ```bash
   kubectl edit networkpolicy <policy-name> -n <namespace>
   ```

### RBAC Issues

#### Symptoms
- Permission denied errors
- Services cannot access resources

#### Diagnosis
```bash
# Check service accounts
kubectl get serviceaccounts --all-namespaces

# Check cluster roles
kubectl get clusterroles

# Check role bindings
kubectl get clusterrolebindings
```

#### Solutions
1. **Check permissions:**
   ```bash
   kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<service-account>
   ```

2. **Update RBAC:**
   ```bash
   kubectl edit clusterrole <role-name>
   kubectl edit clusterrolebinding <binding-name>
   ```

## Getting Help

### Collecting Information

When seeking help, collect the following information:

1. **Cluster status:**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   kubectl get services --all-namespaces
   ```

2. **System information:**
   ```bash
   kubectl version
   kubectl cluster-info
   ```

3. **Logs:**
   ```bash
   journalctl -u kubelet -n 100
   journalctl -u containerd -n 100
   ```

4. **Network information:**
   ```bash
   ip route show
   ip addr show
   ```

### Useful Commands

```bash
# Check cluster health
kubectl get componentstatuses

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check storage
kubectl get pv
kubectl get pvc --all-namespaces

# Check network
kubectl get networkpolicies --all-namespaces
kubectl get services --all-namespaces
```

### Emergency Recovery

If the cluster is completely broken:

1. **Reset kubeadm:**
   ```bash
   kubeadm reset --force
   ```

2. **Clean up:**
   ```bash
   ./scripts/cleanup.sh
   ```

3. **Redeploy:**
   ```bash
   ./scripts/99-deploy-all.sh
   ```
