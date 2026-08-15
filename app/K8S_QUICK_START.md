# Kubernetes Quick Start - Orderit

Complete K8s cluster setup with HPA, RBAC, Nginx Ingress, health checks, network policies.

---

## 📦 What Was Created

### Core K8s Manifests (Base)

- **namespace.yaml** — Isolated orderit namespace
- **rbac.yaml** — ServiceAccount, Role, RoleBinding for pod access control
- **configmap.yaml** — Non-sensitive app configuration
- **secret.yaml** — Sensitive data (API keys, DB creds, JWT)
- **backend-deployment.yaml** — Backend pods with 3 health checks, resource limits
- **backend-service.yaml** — Expose backend on :4000 internally
- **frontend-deployment.yaml** — Frontend nginx pods
- **frontend-service.yaml** — Expose frontend on :80 internally
- **mongo-deployment.yaml** — MongoDB database pods
- **ingress.yaml** — Nginx Ingress + cert-manager for HTTPS/Let's Encrypt
- **hpa.yaml** — Auto-scale backend (2-10 replicas), frontend (2-5 replicas)
- **network-policy.yaml** — Restrict pod-to-pod traffic (security)
- **kustomization.yaml** — Package base manifests

### Environment Overlays

- **overlays/dev/kustomization.yaml** — Dev: 1 replica, reduced resources
- **overlays/prod/kustomization.yaml** — Prod: 3+ replicas, full resources

### Automation & Documentation

- **deploy.sh** — Easy deployment script (apply/delete/logs/exec/restart/scale)
- **K8S_DEPLOYMENT.md** — Complete K8s operations guide
- **HEALTH_ENDPOINTS.md** — Health API setup & testing guide
- **K8S_QUICK_START.md** — This file

---

## 🚀 Quick Deploy (5 Minutes)

### 1. Update Secrets (REQUIRED)

Edit `k8s/base/secret.yaml` with real values:

```bash
nano app/k8s/base/secret.yaml
```

Update these placeholders:

```yaml
data:
  # Generate with: openssl rand -base64 32
  JWT_SECRET: "generate-new-random-string"
  
  # From Cloudinary
  CLOUDINARY_NAME: "your-cloudinary-cloud-name"
  CLOUDINARY_API_KEY: "..."
  CLOUDINARY_API_SECRET: "..."
  
  # From Stripe
  STRIPE_KEY: "pk_test_..."
  STRIPE_SECRET_KEY: "sk_test_..."
  
  # From Mailtrap
  SMTP_PASSWORD: "..."
  SMTP_FROM_EMAIL: "noreply@orderit.local"
```

### 2. Update Image Registry

Edit `k8s/base/kustomization.yaml` and both overlays:

```yaml
images:
  - name: ghcr.io/GITHUB_USER/orderit-backend    # Replace GITHUB_USER
    newTag: latest
  - name: ghcr.io/GITHUB_USER/orderit-frontend   # Replace GITHUB_USER
    newTag: latest
```

### 3. Update Ingress Domain

Edit `k8s/base/ingress.yaml`:

```yaml
spec:
  tls:
    - hosts:
        - orderit.duckdns.org   # Your DuckDNS domain
```

### 4. Deploy to Dev

```bash
cd app
./k8s/deploy.sh dev apply
```

Verify:

```bash
./k8s/deploy.sh dev status
```

### 5. Deploy to Production

```bash
./k8s/deploy.sh prod apply
./k8s/deploy.sh prod status
```

---

## 🔌 Backend Health API (CRITICAL)

Backend must expose 3 health endpoints. Add to `app/backend/server.js`:

```javascript
// Liveness: Pod alive?
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Readiness: Ready for traffic?
app.get('/ready', (req, res) => {
  if (mongoose.connection.readyState === 1) {
    return res.json({ ready: true });
  }
  res.status(503).json({ ready: false });
});

// Metrics: Prometheus format
app.get('/metrics', (req, res) => {
  res.type('text/plain');
  res.send(`
process_uptime_seconds ${process.uptime()}
nodejs_memory_usage_bytes{type="heapUsed"} ${process.memoryUsage().heapUsed}
  `);
});
```

**See:** `k8s/HEALTH_ENDPOINTS.md` for full implementation.

---

## 📊 Architecture

```
Internet (HTTPS)
    ↓
DuckDNS Domain (orderit.duckdns.org)
    ↓
Nginx Ingress Controller
├─ /api → Backend:4000 (API)
├─ /health → Backend:4000 (Health check)
├─ /ready → Backend:4000 (Readiness check)
├─ /metrics → Backend:9090 (Prometheus)
└─ / → Frontend:80 (SPA)
    ↓
    ├─ Frontend (nginx)
    │  ├─ Pod 1 (10.0.0.1:80)
    │  └─ Pod 2 (10.0.0.2:80)
    │
    ├─ Backend (Node.js)
    │  ├─ Pod 1 (10.0.0.3:4000) — HPA scales 2-10
    │  ├─ Pod 2 (10.0.0.4:4000)
    │  └─ ...
    │
    └─ MongoDB
       └─ Pod 1 (10.0.0.5:27017)

Network Policies:
  Frontend → Backend only (no direct DB)
  Backend → MongoDB only (no cross-pod chatter)
  MongoDB → Backend only (strict)

RBAC:
  ServiceAccount: orderit
  Role: read pods, services, configmaps, secrets
  Binding: serviceAccount → role
```

---

## 🎯 Key Features

### HPA (Horizontal Pod Autoscaler)

**Backend:**
- Min 2 replicas, max 10
- Scales up: CPU > 70%, Memory > 80%
- Scales down: Idle for 5 minutes

**Frontend:**
- Min 2 replicas, max 5
- Scales up: CPU > 75%, Memory > 85%
- Scales down: Idle for 5 minutes

Watch scaling:

```bash
kubectl -n orderit get hpa -w
```

### Health Checks

All pods have 3 probes:

| Probe | What | Delay | Failure Action |
|-------|------|-------|----------------|
| **Liveness** | Pod alive? | 15s | Restart |
| **Readiness** | Ready for traffic? | 10s | Remove from LB |
| **Startup** | Initializing? | 0s | Wait 5 min |

### RBAC (Role-Based Access Control)

Pods run as `orderit` ServiceAccount with limited permissions:

```bash
kubectl -n orderit auth can-i get pods --as=system:serviceaccount:orderit:orderit
# yes

kubectl -n orderit auth can-i delete pods --as=system:serviceaccount:orderit:orderit
# no
```

### Network Policies

Restrict traffic between pods (security):

```bash
kubectl -n orderit get networkpolicies
```

- Frontend can't access MongoDB directly
- Backend can't access other pods
- Only allowed routes: Ingress → Services → Pods

### Nginx Ingress

Routes traffic to correct pods:

```bash
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx logs -f deployment/nginx-ingress-controller
```

Routes:

```
orderit.duckdns.org/api/*  → backend:4000
orderit.duckdns.org/health → backend:4000
orderit.duckdns.org/ready  → backend:4000
orderit.duckdns.org/metrics→ backend:9090
orderit.duckdns.org/*      → frontend:80
```

---

## 🔧 Operations

### Deploy

```bash
# Development
./k8s/deploy.sh dev apply

# Production
./k8s/deploy.sh prod apply
```

### View Status

```bash
./k8s/deploy.sh dev status
```

Shows:
- Pods running
- Services
- Ingress rules
- HPA scaling status
- Resource usage

### View Logs

```bash
# Backend logs (follow)
./k8s/deploy.sh dev logs backend

# Frontend logs
./k8s/deploy.sh dev logs frontend

# MongoDB logs
./k8s/deploy.sh dev logs mongo
```

### Shell into Pod

```bash
# Backend shell
./k8s/deploy.sh dev exec backend

# Frontend shell
./k8s/deploy.sh dev exec frontend
```

### Restart Deployment

```bash
# Zero-downtime rolling restart
./k8s/deploy.sh dev restart backend
```

### Scale Manually

```bash
# Scale backend to 5 replicas (temporarily disables HPA)
./k8s/deploy.sh dev scale backend 5

# Scale frontend to 3 replicas
./k8s/deploy.sh dev scale frontend 3
```

### Rollback

```bash
# Undo last deployment
./k8s/deploy.sh dev rollback backend
```

### Delete Everything

```bash
./k8s/deploy.sh dev delete
```

---

## 🧪 Testing

### Test Health Endpoints

```bash
# From cluster
kubectl -n orderit exec deployment/backend -- \
  wget -O- http://localhost:4000/health

kubectl -n orderit exec deployment/backend -- \
  wget -O- http://localhost:4000/ready

# From ingress (external)
curl https://orderit.duckdns.org/health
curl https://orderit.duckdns.org/ready
```

### Test API

```bash
# From within cluster
kubectl -n orderit exec deployment/frontend -- \
  wget -O- http://backend:4000/api/v1/restaurants

# From external
curl https://orderit.duckdns.org/api/v1/restaurants
```

### Test Database Connection

```bash
# From backend pod
kubectl -n orderit exec deployment/backend -- \
  mongosh mongodb://mongo:27017/orderit

# Check data
db.restaurants.find()
```

---

## 📋 File Locations

| File | Purpose |
|------|---------|
| `k8s/base/*.yaml` | Base manifests (shared configs) |
| `k8s/overlays/dev/` | Dev-specific overrides |
| `k8s/overlays/prod/` | Prod-specific overrides |
| `k8s/deploy.sh` | Deployment script |
| `k8s/K8S_DEPLOYMENT.md` | Full operations guide |
| `k8s/HEALTH_ENDPOINTS.md` | Health API setup guide |

---

## 🚀 Deployment Flow

```
1. Update k8s/base/secret.yaml (API keys, credentials)
2. Update k8s/base/kustomization.yaml (images)
3. Update k8s/base/ingress.yaml (domain)
4. Run: ./k8s/deploy.sh dev apply
5. Wait for pods: kubectl -n orderit get pods
6. Test health: curl https://orderit.duckdns.org/health
7. Done! 🎉
```

---

## 🔒 Security Checklist

- [ ] Secrets updated in `k8s/base/secret.yaml`
- [ ] Images pushed to GitHub Container Registry
- [ ] Network policies enforce pod isolation
- [ ] RBAC limits pod permissions
- [ ] HTTPS enabled via Let's Encrypt (ingress.yaml)
- [ ] Health checks prevent bad pods from serving traffic
- [ ] Resource limits prevent pod from crashing cluster
- [ ] Pod security context (non-root, read-only FS)

---

## 🐛 Troubleshooting

### Pods won't start

```bash
./k8s/deploy.sh dev status
kubectl -n orderit describe pod <pod-name>
./k8s/deploy.sh dev logs <service>
```

### Health checks failing

```bash
# Test endpoint manually
kubectl -n orderit exec deployment/backend -- \
  wget -vO- http://localhost:4000/health

# Check probe results
kubectl -n orderit describe pod <pod-name>
```

### HPA not scaling

```bash
# Check metrics-server
kubectl -n kube-system get deployment metrics-server

# Check HPA status
kubectl -n orderit describe hpa backend-hpa
```

### Ingress not working

```bash
# Check ingress controller
kubectl -n ingress-nginx get pods

# Check certificate
kubectl -n orderit get certificate
kubectl -n orderit describe certificate orderit-tls
```

See `K8S_DEPLOYMENT.md` for full troubleshooting guide.

---

## 📚 Documentation

| File | Content |
|------|---------|
| **K8S_QUICK_START.md** | This file — quick overview |
| **K8S_DEPLOYMENT.md** | Full operations guide, troubleshooting |
| **HEALTH_ENDPOINTS.md** | Health API implementation, testing |

---

## 🎯 What's Included

✅ **Deployments** — Backend, Frontend, MongoDB  
✅ **Services** — Expose pods internally  
✅ **Ingress** — Route external traffic + HTTPS/Let's Encrypt  
✅ **HPA** — Auto-scale based on CPU/memory  
✅ **RBAC** — ServiceAccount + Role + RoleBinding  
✅ **Network Policies** — Pod-to-pod security  
✅ **Health Checks** — Liveness, readiness, startup probes  
✅ **ConfigMap** — Non-sensitive app config  
✅ **Secrets** — Sensitive data (encrypted at rest)  
✅ **Kustomize** — Manage dev/prod configs  
✅ **Deploy Script** — Easy apply/delete/logs/exec commands  

---

## ⏱️ Timeline

```
0-5 min:   Update secrets, images, domain
5-10 min:  kubectl apply -k k8s/overlays/dev
10-15 min: Pods start, probes pass
15-20 min: Ingress routes traffic, HTTPS ready
20-25 min: Test health endpoints
25-30 min: Deploy to prod if ready
```

---

## 🆘 Support

1. Check pod status: `./k8s/deploy.sh dev status`
2. View logs: `./k8s/deploy.sh dev logs backend`
3. Describe pod: `kubectl -n orderit describe pod <name>`
4. Read: `K8S_DEPLOYMENT.md` or `HEALTH_ENDPOINTS.md`

---

**Ready to deploy? Run:** `./k8s/deploy.sh dev apply`

**Last Updated:** 2026-08-15
