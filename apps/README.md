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
