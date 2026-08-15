# Kubernetes Deployment Guide - Orderit

Complete Kubernetes cluster setup for Orderit with HPA, RBAC, Nginx Ingress, health checks.

---

## 📋 Prerequisites

- K3s cluster running (see ZERO_COST_INFRA.md)
- `kubectl` configured to access cluster
- Container images pushed to registry (see DOCKER_SETUP.md)
- `kustomize` installed (optional, for easier deployment)
- Metrics Server installed (for HPA) — K3s includes this by default

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Nginx Ingress Controller                │
│  (orderit.duckdns.org → HTTP/HTTPS routing)    │
└─────────────────────┬───────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
    ┌───▼────┐  ┌────▼───┐  ┌──────▼────────┐
    │Frontend │  │API Docs│  │Backend API    │
    │(Nginx)  │  │/metrics│  │(Node.js)      │
    │Pods x2  │  │/ready  │  │Pods x2-3      │
    └───┬────┘  └────┬───┘  └──────┬────────┘
        │             │             │
        │             └─────────────┤
        │                           │
        │            ┌──────────────▼─────────┐
        │            │   MongoDB Cluster      │
        │            │   Pods (Stateful)      │
        │            └───────────────────────┘
        │
        └────┐  ┐──────────────────────────┐
             │  │  Metrics Server          │
             └──│  (for HPA scaling)       │
                └──────────────────────────┘

RBAC:
  ├─ ServiceAccount: orderit
  ├─ Role: read pods, services, configmaps, secrets
  └─ RoleBinding: orderit → orderit

Network Policies:
  ├─ Backend: accepts from Nginx + Frontend
  ├─ Frontend: accepts from Nginx only
  └─ MongoDB: accepts from Backend only
```

---

## 📁 File Structure

```
k8s/
├── base/                          # Base manifests (shared configs)
│   ├── namespace.yaml
│   ├── rbac.yaml                  # ServiceAccount, Role, RoleBinding
│   ├── configmap.yaml             # Non-sensitive config
│   ├── secret.yaml                # Secrets (API keys, JWT, DB creds)
│   ├── backend-deployment.yaml    # Backend pods + health checks
│   ├── backend-service.yaml       # Backend service
│   ├── frontend-deployment.yaml   # Frontend pods + health checks
│   ├── frontend-service.yaml      # Frontend service
│   ├── mongo-deployment.yaml      # MongoDB pods
│   ├── ingress.yaml               # Nginx Ingress + cert-manager
│   ├── hpa.yaml                   # HorizontalPodAutoscaler (both apps)
│   ├── network-policy.yaml        # Network segmentation
│   └── kustomization.yaml         # Kustomize base config
├── overlays/
│   ├── dev/                       # Development overrides
│   │   └── kustomization.yaml    # 1 replica, reduced resources
│   └── prod/                      # Production overrides
│       └── kustomization.yaml    # 3+ replicas, full resources
└── K8S_DEPLOYMENT.md             # This file
```

---

## 🚀 Quick Deploy

### 1. Update Configuration

Edit `k8s/base/secret.yaml` with real credentials:

```bash
cat k8s/base/secret.yaml
# Update all placeholder values:
# - CLOUDINARY_NAME
# - STRIPE_KEY / STRIPE_SECRET_KEY
# - SMTP credentials
# - JWT_SECRET (generate with: openssl rand -base64 32)
```

Edit `k8s/base/ingress.yaml`:

```yaml
spec:
  tls:
    - hosts:
        - orderit.duckdns.org  # Change to your domain
```

### 2. Deploy to Development

```bash
kubectl apply -k k8s/overlays/dev
```

Verify:

```bash
kubectl -n orderit get all
kubectl -n orderit logs -f deployment/backend
```

### 3. Deploy to Production

```bash
kubectl apply -k k8s/overlays/prod
```

Monitor:

```bash
kubectl -n orderit top nodes
kubectl -n orderit top pods
kubectl -n orderit get hpa -w
```

---

## 🔍 Key Components

### Health Checks (Critical for K8s)

Each deployment has 3 probes:

| Probe | Path | Purpose | Delay |
|-------|------|---------|-------|
| **Liveness** | `/health` | Pod alive? Restart if not | 15s |
| **Readiness** | `/ready` | Ready to receive traffic? | 10s |
| **Startup** | `/health` | App fully initialized? | 0s, 30 retries |

**Backend must expose:**

```javascript
// server.js
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

app.get('/ready', (req, res) => {
  if (mongoose.connection.readyState === 1) {
    return res.json({ ready: true });
  }
  res.status(503).json({ ready: false });
});
```

### RBAC (ServiceAccount + Role)

```yaml
serviceAccountName: orderit  # All pods use this
```

Allows pods to:

- Read own logs, events
- Query Kubernetes API (if needed)
- Limited to orderit namespace

### HPA (Horizontal Pod Autoscaler)

**Backend scales on:**

- CPU > 70% → scale up (max 10 replicas)
- Memory > 80% → scale up
- Idle for 5m → scale down (min 2 replicas)

**Frontend scales on:**

- CPU > 75% → scale up (max 5 replicas)
- Memory > 85% → scale up
- Idle for 5m → scale down (min 2 replicas)

View HPA status:

```bash
kubectl -n orderit get hpa
kubectl -n orderit get hpa backend-hpa -w  # Watch scaling
```

### Nginx Ingress Routes

```
orderit.duckdns.org
├── /api/*          → backend:4000  (API calls)
├── /health         → backend:4000  (Health check)
├── /ready          → backend:4000  (Readiness check)
├── /metrics        → backend:9090  (Prometheus metrics)
└── /*              → frontend:80   (SPA + static files)
```

### Network Policies

Restricts traffic between pods:

- **Frontend → Backend only** (no direct DB access)
- **Backend → MongoDB only** (no cross-pod chatter)
- **MongoDB → Backend only** (strict DB access)
- **Ingress → All services** (entry point only)

Check policies:

```bash
kubectl -n orderit get networkpolicies
```

---

## 🔧 Operations

### View Deployments

```bash
# All resources in namespace
kubectl -n orderit get all

# Specific deployment
kubectl -n orderit get deployment backend
kubectl -n orderit describe deployment backend

# Pods
kubectl -n orderit get pods -o wide
kubectl -n orderit get pods -L app,tier
```

### Logs

```bash
# Real-time logs
kubectl -n orderit logs -f deployment/backend
kubectl -n orderit logs -f deployment/frontend -c frontend

# Last 100 lines
kubectl -n orderit logs --tail=100 deployment/backend

# Specific pod
kubectl -n orderit logs -f pod/backend-abc123xyz-def45
```

### Shell Access

```bash
# Backend shell
kubectl -n orderit exec -it deployment/backend -- sh

# Frontend shell
kubectl -n orderit exec -it deployment/frontend -- sh
```

### Check Health

```bash
# Pod status (Running, Pending, CrashLoopBackOff)
kubectl -n orderit get pods

# Describe pod (see events, health check results)
kubectl -n orderit describe pod backend-0

# Test health endpoints
kubectl -n orderit exec deployment/backend -- wget -O- http://localhost:4000/health
kubectl -n orderit exec deployment/frontend -- wget -O- http://localhost/health
```

### Scale Manually

```bash
# Scale backend to 5 replicas (temporarily disables HPA)
kubectl -n orderit scale deployment backend --replicas=5

# Get back to HPA control
kubectl -n orderit scale deployment backend --replicas=3
```

### Update Images

```bash
# Update backend image to new version
kubectl -n orderit set image deployment/backend \
  backend=ghcr.io/GITHUB_USER/orderit-backend:v1.0.0

# Watch rollout
kubectl -n orderit rollout status deployment/backend

# Check history
kubectl -n orderit rollout history deployment/backend

# Rollback if needed
kubectl -n orderit rollout undo deployment/backend
```

### View Events

```bash
# Cluster events
kubectl -n orderit get events --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl -n orderit get events -w
```

### Monitor Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl -n orderit top pods
kubectl -n orderit top pods --containers

# Watch HPA scaling
kubectl -n orderit get hpa -w
```

---

## 🔐 Security

### Secrets Management

Secrets are stored in k8s as base64 encoded (not encrypted by default):

```bash
# View secret (base64 encoded)
kubectl -n orderit get secret orderit-secrets -o yaml

# Decode specific secret
kubectl -n orderit get secret orderit-secrets -o jsonpath='{.data.JWT_SECRET}' | base64 -d

# Update secret
kubectl -n orderit create secret generic orderit-secrets --from-literal=JWT_SECRET=new-value --dry-run=client -o yaml | kubectl apply -f -
```

**⚠️ Enable Encryption at Rest:**

```bash
# On K3s, enable etcd encryption
# See: https://docs.k3s.io/security/secrets-encryption
```

### Network Policies

Isolate pods from each other:

```bash
kubectl -n orderit get networkpolicies
kubectl -n orderit describe networkpolicy backend-network-policy
```

### Pod Security Policies

Frontend runs as non-root:

```yaml
runAsNonRoot: true
runAsUser: 101  # nginx user
readOnlyRootFilesystem: true
```

---

## 🐛 Troubleshooting

### Pods Won't Start

```bash
# Check pod status
kubectl -n orderit describe pod backend-xyz

# Check logs
kubectl -n orderit logs backend-xyz

# Common issues:
# - "ImagePullBackOff" → Image not found in registry
# - "CrashLoopBackOff" → App crashed, check logs
# - "Pending" → No resources available, check nodes
```

### Health Checks Failing

```bash
# Test health endpoint
kubectl -n orderit exec deployment/backend -- \
  wget -O- http://localhost:4000/health

# Check probes in pod description
kubectl -n orderit describe pod backend-xyz
# Look for "Last Probe" results
```

### Backend Can't Connect to MongoDB

```bash
# Check MongoDB pod
kubectl -n orderit get pod -l app=mongo
kubectl -n orderit logs deployment/mongo

# Test connectivity from backend
kubectl -n orderit exec deployment/backend -- \
  wget -O- http://mongo:27017

# Check service
kubectl -n orderit get service mongo
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl -n orderit get hpa backend-hpa
kubectl -n orderit describe hpa backend-hpa

# Check metrics-server
kubectl -n kube-system get deployment metrics-server
kubectl -n kube-system logs deployment/metrics-server

# If metrics not available, wait 1-2 minutes
# K3s includes metrics-server by default
```

### High Memory/CPU

```bash
# Check resource limits
kubectl -n orderit top pods

# Update limits in kustomization
# Edit k8s/base/backend-deployment.yaml or overlays/
resources:
  limits:
    memory: "512Mi"  # Increase if needed
    cpu: "500m"
```

### Ingress Not Working

```bash
# Check ingress
kubectl -n orderit get ingress
kubectl -n orderit describe ingress orderit

# Check ingress controller
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx logs deployment/nginx-ingress-controller

# Check cert-manager
kubectl -n cert-manager get pods
kubectl -n cert-manager logs deployment/cert-manager

# Check TLS certificate
kubectl -n orderit get certificate
kubectl -n orderit describe certificate orderit-tls
```

---

## 📊 Monitoring

### Basic Metrics

```bash
# Continuous resource monitoring
watch -n 2 'kubectl -n orderit top pods'

# HPA scaling decisions
watch -n 5 'kubectl -n orderit get hpa'
```

### Prometheus (Optional)

Install Prometheus for detailed metrics:

```bash
# Using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

Scrape config (ingress.yaml):

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "4000"
  prometheus.io/path: "/metrics"
```

---

## 🚀 CI/CD Integration

### GitHub Actions Deployment

```yaml
# .github/workflows/deploy.yml
name: Deploy to K3s

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy with kubectl
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.KUBECONFIG }}" > $HOME/.kube/config
          kubectl apply -k k8s/overlays/prod
          kubectl -n orderit rollout status deployment/backend
```

---

## 📝 Pre-Production Checklist

- [ ] All secrets updated in `k8s/base/secret.yaml`
- [ ] Container images built and pushed to registry
- [ ] Ingress domain set correctly (orderit.duckdns.org)
- [ ] cert-manager installed for HTTPS
- [ ] Backend `/health` and `/ready` endpoints working
- [ ] Health checks responding correctly
- [ ] HPA metrics-server running
- [ ] Network policies tested
- [ ] Resource limits reviewed
- [ ] PodDisruptionBudgets considered for production
- [ ] Backups planned for MongoDB
- [ ] Monitoring setup (Prometheus/Grafana)

---

## 🆘 Support

For issues:

1. Check pod logs: `kubectl -n orderit logs`
2. Describe pod: `kubectl -n orderit describe pod`
3. Check events: `kubectl -n orderit get events`
4. Review CLAUDE.md for project-specific guidance

---

**Last Updated:** 2026-08-15  
**K3s Version:** 1.27+  
**Kubernetes Version:** 1.27+
