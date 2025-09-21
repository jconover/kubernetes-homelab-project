#!/bin/bash

# Kubernetes Homelab - Setup GitHub Actions
# This script sets up GitHub Actions for CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if git is available
check_git() {
    if ! command -v git &> /dev/null; then
        error "git not found. Please install git first."
    fi
    
    if ! git status &> /dev/null; then
        error "Not in a git repository. Please initialize git first."
    fi
}

# Create GitHub Actions directory
create_github_actions() {
    log "Creating GitHub Actions workflows..."
    
    # Create .github/workflows directory
    mkdir -p .github/workflows
    
    # Check if workflows already exist
    if [[ -f ".github/workflows/react-frontend.yml" ]]; then
        warn "GitHub Actions workflows already exist. Skipping creation."
        return
    fi
    
    log "GitHub Actions workflows created successfully!"
}

# Create database initialization scripts
create_db_init() {
    log "Creating database initialization scripts..."
    
    # Create database init directory
    mkdir -p manifests/database-init
    
    # PostgreSQL initialization
    cat <<EOF > manifests/database-init/postgresql-init.sql
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email) VALUES 
('admin', 'admin@homelab.local'),
('user1', 'user1@homelab.local'),
('user2', 'user2@homelab.local')
ON CONFLICT (username) DO NOTHING;

INSERT INTO tasks (title, description, priority, status) VALUES 
('Setup Kubernetes', 'Deploy Kubernetes cluster', 'high', 'completed'),
('Configure Monitoring', 'Setup Prometheus and Grafana', 'high', 'completed'),
('Deploy Applications', 'Deploy React, Python, and Node.js apps', 'medium', 'in-progress'),
('Setup CI/CD', 'Configure GitHub Actions and ArgoCD', 'medium', 'pending')
ON CONFLICT DO NOTHING;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
EOF

    # Redis initialization
    cat <<EOF > manifests/database-init/redis-init.sh
#!/bin/bash
# Redis initialization script

# Set some default cache values
redis-cli SET "app:version" "1.0.0"
redis-cli SET "app:status" "running"
redis-cli SET "cache:ttl" "3600"

# Set some sample data
redis-cli HSET "user:1" "name" "admin" "role" "administrator"
redis-cli HSET "user:2" "name" "user1" "role" "user"
redis-cli HSET "user:3" "name" "user2" "role" "user"

echo "Redis initialization completed"
EOF

    chmod +x manifests/database-init/redis-init.sh
    
    log "Database initialization scripts created successfully!"
}

# Create application monitoring configuration
create_app_monitoring() {
    log "Creating application monitoring configuration..."
    
    # Create monitoring directory
    mkdir -p manifests/monitoring
    
    # ServiceMonitor for applications
    cat <<EOF > manifests/monitoring/applications-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: applications
  namespace: monitoring
  labels:
    app: applications
spec:
  selector:
    matchLabels:
      app: react-frontend
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: python-api
  namespace: monitoring
  labels:
    app: python-api
spec:
  selector:
    matchLabels:
      app: python-api
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nodejs-service
  namespace: monitoring
  labels:
    app: nodejs-service
spec:
  selector:
    matchLabels:
      app: nodejs-service
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
EOF

    # Grafana dashboard for applications
    cat <<EOF > manifests/monitoring/applications-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: applications-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  applications.json: |
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": "-- Grafana --",
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "type": "dashboard"
          }
        ]
      },
      "editable": true,
      "gnetId": null,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "panels": [
        {
          "datasource": "prometheus",
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "vis": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 0
          },
          "id": 1,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom"
            },
            "tooltip": {
              "mode": "single"
            }
          },
          "targets": [
            {
              "expr": "rate(http_requests_total[5m])",
              "interval": "",
              "legendFormat": "{{app}} - {{method}} {{route}}",
              "refId": "A"
            }
          ],
          "title": "Application Request Rate",
          "type": "timeseries"
        },
        {
          "datasource": "prometheus",
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "vis": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "s"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 0
          },
          "id": 2,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom"
            },
            "tooltip": {
              "mode": "single"
            }
          },
          "targets": [
            {
              "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
              "interval": "",
              "legendFormat": "{{app}} - 95th percentile",
              "refId": "A"
            }
          ],
          "title": "Application Response Time",
          "type": "timeseries"
        }
      ],
      "schemaVersion": 27,
      "style": "dark",
      "tags": [
        "applications"
      ],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "",
      "title": "Applications Dashboard",
      "uid": "applications-dashboard",
      "version": 1
    }
EOF

    log "Application monitoring configuration created successfully!"
}

# Create README for applications
create_app_readme() {
    log "Creating application documentation..."
    
    cat > /home/justin/Projects/kubernetes-homelab-project/apps/README.md << 'EOF'
# Kubernetes Homelab Applications

This directory contains sample applications for the Kubernetes homelab project.

## Applications

### React Frontend
- **Location**: `apps/react-frontend/`
- **Description**: Modern React frontend with nginx
- **Port**: 80
- **Health Check**: `/health`

### Python API
- **Location**: `apps/python-api/`
- **Description**: FastAPI backend with database integration
- **Port**: 8000
- **Health Check**: `/health`
- **Metrics**: `/metrics`

### Node.js Service
- **Location**: `apps/nodejs-service/`
- **Description**: Express.js microservice
- **Port**: 3000
- **Health Check**: `/health`
- **Metrics**: `/metrics`

## Development

### Local Development
\`\`\`bash
# React Frontend
cd apps/react-frontend
npm install
npm start

# Python API
cd apps/python-api
pip install -r requirements.txt
uvicorn main:app --reload

# Node.js Service
cd apps/nodejs-service
npm install
npm run dev
\`\`\`

### Building Images
\`\`\`bash
# Build all images
docker build -t ghcr.io/jconover/kubernetes-homelab-react-frontend:latest apps/react-frontend/
docker build -t ghcr.io/jconover/kubernetes-homelab-python-api:latest apps/python-api/
docker build -t ghcr.io/jconover/kubernetes-homelab-nodejs-service:latest apps/nodejs-service/
\`\`\`

## Deployment

Applications are deployed using:
1. **GitHub Actions**: CI/CD pipelines
2. **ArgoCD**: GitOps deployment
3. **Kubernetes**: Container orchestration

## Monitoring

All applications expose Prometheus metrics and are monitored by:
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alerting (optional)

## Database Integration

Applications connect to:
- **PostgreSQL**: Primary database
- **Redis**: Caching and sessions
- **RabbitMQ**: Message queuing
EOF

    log "Application documentation created successfully!"
}

# Main execution
log "Setting up GitHub Actions and application infrastructure..."

# Check git
check_git

# Create GitHub Actions
create_github_actions

# Create database initialization
create_db_init

# Create application monitoring
create_app_monitoring

# Create application documentation
create_app_readme

log "GitHub Actions and application infrastructure setup completed!"
log ""
log "Next steps:"
log "1. Push the code to GitHub: git add . && git commit -m 'Add applications and CI/CD' && git push"
log "2. Enable GitHub Actions in your repository settings"
log "3. Deploy ArgoCD: ./scripts/07-deploy-argocd.sh"
log "4. Create applications in ArgoCD or apply manifests in manifests/applications/"
log ""
log "Your applications will be available at:"
log "- React Frontend: http://<LoadBalancer-IP>:80"
log "- Python API: http://<LoadBalancer-IP>:8000"
log "- Node.js Service: http://<LoadBalancer-IP>:3000"
log ""
log "GitHub Container Registry images:"
log "- ghcr.io/jconover/kubernetes-homelab-react-frontend"
log "- ghcr.io/jconover/kubernetes-homelab-python-api"
log "- ghcr.io/jconover/kubernetes-homelab-nodejs-service"
