#!/bin/bash

# Kubernetes Homelab - Phase 4: Deploy Database Services (PostgreSQL, Redis, RabbitMQ)
# This script deploys PostgreSQL, Redis, and RabbitMQ with persistent storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_VERSION="15.4"
REDIS_VERSION="7.2.0"
RABBITMQ_VERSION="3.12.0"
STORAGE_CLASS="local-path"  # Default for microk8s, adjust as needed

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

# Create database namespace
create_namespace() {
    log "Creating database namespace..."
    kubectl create namespace databases --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy PostgreSQL
deploy_postgresql() {
    log "Deploying PostgreSQL..."
    
    # Create PostgreSQL ConfigMap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-config
  namespace: databases
data:
  POSTGRES_DB: "homelab"
  POSTGRES_USER: "postgres"
  POSTGRES_PASSWORD: "postgres123"
  POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
EOF

    # Create PostgreSQL PersistentVolumeClaim
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-pvc
  namespace: databases
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: ${STORAGE_CLASS}
EOF

    # Create PostgreSQL Deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: databases
  labels:
    app: postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:${POSTGRES_VERSION}
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgresql-config
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        - name: postgresql-config-volume
          mountPath: /etc/postgresql
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgresql-storage
        persistentVolumeClaim:
          claimName: postgresql-pvc
      - name: postgresql-config-volume
        configMap:
          name: postgresql-config
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: databases
  labels:
    app: postgresql
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
  type: LoadBalancer
EOF

    log "PostgreSQL deployed successfully!"
}

# Deploy Redis
deploy_redis() {
    log "Deploying Redis..."
    
    # Create Redis ConfigMap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: databases
data:
  redis.conf: |
    # Redis configuration for homelab
    bind 0.0.0.0
    port 6379
    timeout 0
    tcp-keepalive 300
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    appendonly yes
    appendfsync everysec
    no-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb
    aof-load-truncated yes
    aof-use-rdb-preamble yes
    lua-time-limit 5000
    slowlog-log-slower-than 10000
    slowlog-max-len 128
    latency-monitor-threshold 0
    notify-keyspace-events ""
    hash-max-ziplist-entries 512
    hash-max-ziplist-value 64
    list-max-ziplist-size -2
    list-compress-depth 0
    set-max-intset-entries 512
    zset-max-ziplist-entries 128
    zset-max-ziplist-value 64
    hll-sparse-max-bytes 3000
    stream-node-max-bytes 4096
    stream-node-max-entries 100
    activerehashing yes
    client-output-buffer-limit normal 0 0 0
    client-output-buffer-limit replica 256mb 64mb 60
    client-output-buffer-limit pubsub 32mb 8mb 60
    hz 10
    dynamic-hz yes
    aof-rewrite-incremental-fsync yes
    rdb-save-incremental-fsync yes
EOF

    # Create Redis PersistentVolumeClaim
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
  namespace: databases
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ${STORAGE_CLASS}
EOF

    # Create Redis Deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:${REDIS_VERSION}
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - /etc/redis/redis.conf
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        - name: redis-config-volume
          mountPath: /etc/redis
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-storage
        persistentVolumeClaim:
          claimName: redis-pvc
      - name: redis-config-volume
        configMap:
          name: redis-config
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: databases
  labels:
    app: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: LoadBalancer
EOF

    log "Redis deployed successfully!"
}

# Deploy RabbitMQ
deploy_rabbitmq() {
    log "Deploying RabbitMQ..."
    
    # Create RabbitMQ ConfigMap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: rabbitmq-config
  namespace: databases
data:
  enabled_plugins: |
    [rabbitmq_management,rabbitmq_prometheus,rabbitmq_peer_discovery_k8s].
  rabbitmq.conf: |
    ## Cluster formation
    cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
    cluster_formation.k8s.host = kubernetes.default.svc.cluster.local
    cluster_formation.k8s.address_type = hostname
    cluster_formation.k8s.hostname_suffix = .rabbitmq.databases.svc.cluster.local
    cluster_formation.k8s.service_name = rabbitmq
    cluster_formation.k8s.port = 5672
    
    ## Networking
    listeners.tcp.default = 5672
    management.tcp.port = 15672
    management.tcp.ip = 0.0.0.0
    
    ## Memory and disk limits
    vm_memory_high_watermark.relative = 0.6
    disk_free_limit.relative = 2.0
    
    ## Logging
    log.console = true
    log.console.level = info
    log.file = false
    
    ## Management plugin
    management.load_definitions = /etc/rabbitmq/definitions.json
    
    ## Prometheus plugin
    prometheus.tcp.port = 15692
    prometheus.path = /metrics
    
    ## Default user
    default_user = admin
    default_pass = admin123
    default_vhost = /
    default_permissions.configure = .*
    default_permissions.read = .*
    default_permissions.write = .*
    
    ## Security
    ssl_options.verify = verify_peer
    ssl_options.fail_if_no_peer_cert = false
    
    ## Performance
    channel_max = 2047
    connection_max = 1000
    heartbeat = 60
    frame_max = 131072
    
    ## Cluster settings
    cluster_partition_handling = autoheal
    
    ## Resource limits
    vm_memory_high_watermark_paging_ratio = 0.5
    
    ## Queue index
    queue_index_embed_msgs_below = 4096
    
    ## Mnesia
    mnesia_table_loading_retry_timeout = 30000
    mnesia_table_loading_retry_limit = 10
  definitions.json: |
    {
      "users": [
        {
          "name": "admin",
          "password_hash": "admin123",
          "hashing_algorithm": "rabbit_password_hashing_sha256",
          "tags": "administrator"
        }
      ],
      "vhosts": [
        {
          "name": "/"
        }
      ],
      "permissions": [
        {
          "user": "admin",
          "vhost": "/",
          "configure": ".*",
          "write": ".*",
          "read": ".*"
        }
      ],
      "parameters": [],
      "policies": [],
      "queues": [],
      "exchanges": [],
      "bindings": []
    }
EOF

    # Create RabbitMQ PersistentVolumeClaim
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rabbitmq-pvc
  namespace: databases
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: ${STORAGE_CLASS}
EOF

    # Create RabbitMQ Deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: databases
  labels:
    app: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:${RABBITMQ_VERSION}-management
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        - containerPort: 15692
          name: prometheus
        env:
        - name: RABBITMQ_ERLANG_COOKIE
          value: "SWQOKODSQALRPCLNMEQG"
        - name: RABBITMQ_DEFAULT_USER
          value: "admin"
        - name: RABBITMQ_DEFAULT_PASS
          value: "admin123"
        - name: RABBITMQ_DEFAULT_VHOST
          value: "/"
        volumeMounts:
        - name: rabbitmq-storage
          mountPath: /var/lib/rabbitmq
        - name: rabbitmq-config-volume
          mountPath: /etc/rabbitmq
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - -q
            - ping
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 15
        readinessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - -q
            - ping
          initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 5
      volumes:
      - name: rabbitmq-storage
        persistentVolumeClaim:
          claimName: rabbitmq-pvc
      - name: rabbitmq-config-volume
        configMap:
          name: rabbitmq-config
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: databases
  labels:
    app: rabbitmq
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
    targetPort: 5672
    name: amqp
  - port: 15672
    targetPort: 15672
    name: management
  - port: 15692
    targetPort: 15692
    name: prometheus
  type: LoadBalancer
EOF

    log "RabbitMQ deployed successfully!"
}

# Wait for deployments
wait_for_deployments() {
    log "Waiting for database services to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n databases
    kubectl wait --for=condition=available --timeout=300s deployment/redis -n databases
    kubectl wait --for=condition=available --timeout=300s deployment/rabbitmq -n databases
}

# Get service URLs
get_service_urls() {
    log "Getting database service URLs..."
    
    # Get PostgreSQL URL
    local postgres_ip=$(kubectl get service postgresql -n databases -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$postgres_ip" ]]; then
        log "PostgreSQL URL: $postgres_ip:5432"
        log "PostgreSQL credentials: postgres / postgres123"
    else
        log "PostgreSQL service is not ready yet. Check with: kubectl get svc -n databases"
    fi
    
    # Get Redis URL
    local redis_ip=$(kubectl get service redis -n databases -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$redis_ip" ]]; then
        log "Redis URL: $redis_ip:6379"
    else
        log "Redis service is not ready yet. Check with: kubectl get svc -n databases"
    fi
    
    # Get RabbitMQ URL
    local rabbitmq_ip=$(kubectl get service rabbitmq -n databases -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$rabbitmq_ip" ]]; then
        log "RabbitMQ Management URL: http://$rabbitmq_ip:15672"
        log "RabbitMQ AMQP URL: $rabbitmq_ip:5672"
        log "RabbitMQ credentials: admin / admin123"
    else
        log "RabbitMQ service is not ready yet. Check with: kubectl get svc -n databases"
    fi
}

# Main execution
log "Starting database services deployment (PostgreSQL, Redis, RabbitMQ)..."

# Ensure KUBECONFIG is set
if [[ -z "$KUBECONFIG" ]]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    log "Set KUBECONFIG to /etc/kubernetes/admin.conf"
fi

# Check cluster status
check_cluster

# Create namespace
create_namespace

# Deploy database services
deploy_postgresql
deploy_redis
deploy_rabbitmq

# Wait for deployments
wait_for_deployments

# Get service URLs
get_service_urls

log "Database services deployment completed successfully!"
log ""
log "Next steps:"
log "1. Test database connections using the URLs above"
log "2. Create additional databases/users as needed"
log "3. Configure your applications to use these services"
log ""
log "Useful commands:"
log "- Check database pods: kubectl get pods -n databases"
log "- Check database services: kubectl get svc -n databases"
log "- View database logs: kubectl logs -f deployment/postgresql -n databases"
log "- Access PostgreSQL: kubectl exec -it deployment/postgresql -n databases -- psql -U postgres"
log "- Access Redis: kubectl exec -it deployment/redis -n databases -- redis-cli"
