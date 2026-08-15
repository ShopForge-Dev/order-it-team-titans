# Orderit - $0 Cost Infrastructure Guide

**Goal:** Deploy & run Orderit food delivery app completely free using free tiers, open-source tools, and minimal resource usage.

**Status:** All services free tier eligible ✓

---

## 📊 $0 Cost Architecture

```
┌──────────────────────────────────────────────────────┐
│ Developer Laptop / Free VM                            │
├──────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────┐ │
│ │ K3s (lightweight K8s)                            │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ Frontend Pod   │ Backend Pod   │ Nginx Ingress  │ │
│ └──────────────────────────────────────────────────┘ │
│                       │                               │
│        ┌──────────────┴──────────────┐               │
│        ▼                             ▼               │
│   MongoDB Atlas          External Services            │
│   (Free Tier: 512MB)    • Cloudinary (free tier)    │
│                         • Stripe (test mode)         │
│                         • Mailtrap (free tier)       │
└──────────────────────────────────────────────────────┘
```

---

## 🎯 Free Tier Services

### Database: MongoDB Atlas (FREE)
- **Tier:** M0 (Shared cluster)
- **Storage:** 512 MB
- **Cost:** $0 (free forever)
- **Sign up:** https://www.mongodb.com/cloud/atlas
- **Setup:**
  ```bash
  # 1. Create free cluster in Atlas console
  # 2. Create user credentials
  # 3. Add IP to whitelist (or 0.0.0.0/0 for development)
  # 4. Get connection string: mongodb+srv://user:pass@cluster.mongodb.net/dbname
  ```
- **Limit:** 512 MB data (enough for testing & demo)
- **Note:** Auto-backup every 6 hours, 7-day retention

### Image Storage: Cloudinary (FREE)
- **Tier:** Free (10 GB storage, 20 GB bandwidth/month)
- **Cost:** $0 (unless you exceed limits)
- **Sign up:** https://cloudinary.com/users/register
- **API Keys:** In dashboard
- **Suitable for:** User avatars, restaurant images, food photos

### Payments: Stripe (FREE for testing)
- **Mode:** Test mode (100% free, never charged)
- **Test Keys:** Use `sk_test_...` and `pk_test_...`
- **Cost:** $0 in test mode (2.9% + $0.30 per transaction in live)
- **Sign up:** https://stripe.com
- **Note:** No real charges, cards don't get charged

### Email: Mailtrap (FREE)
- **Tier:** Free (50 emails/month, 1 mailbox)
- **Cost:** $0
- **Sign up:** https://mailtrap.io
- **Use:** Password reset emails, order notifications
- **Note:** Emails captured in dashboard, not actually sent

### Container Registry: GitHub Container Registry (FREE)
- **Limit:** 500 MB free storage, unlimited free public images
- **Cost:** $0 (private images also free for personal accounts)
- **Push:** `ghcr.io/your-username/orderit-backend:1.0.0`
- **Auth:** GitHub token (Settings → Developer settings → Personal access tokens)

### CI/CD: GitHub Actions (FREE)
- **Limit:** 2,000 minutes/month free (enough for this project)
- **Cost:** $0
- **Use:** Auto-build & push to GHCR on git push
- **Trigger:** On push to main branch

### Kubernetes: K3s (FREE)
- **What:** Lightweight, minimal-resource Kubernetes
- **Requirements:** 512 MB RAM minimum (runs on old laptops, Raspberry Pi, free VMs)
- **Cost:** $0 (open-source)
- **Deploy:** Single command: `curl -sfL https://get.k3s.io | sh -`
- **Benefit:** Same K8s API as production (EKS) but runs anywhere

### Compute: Free VM Options

#### Option A: Oracle Cloud Free Tier (RECOMMENDED)
- **2 ARM VMs** always free (up to 4 GB RAM each)
- **50 GB storage** per VM
- **Cost:** $0 (truly free, not trial)
- **Sign up:** https://www.oracle.com/cloud/free/
- **Specs:** 2 × 2.4 GHz 4-core ARM CPUs, 12 GB RAM total, 100 GB storage
- **Use for:** Run K3s + all pods

#### Option B: Google Cloud (Free Tier)
- **1 f1-micro VM** always free (0.6 GB RAM, shared CPU)
- **30 GB storage** (persistent disk)
- **Cost:** $0 (if under limits)
- **Caveat:** 30 GB outbound traffic/month, then $0.12/GB
- **Sign up:** https://cloud.google.com/free
- **Limitation:** f1-micro is very slow, suitable for dev/demo only

#### Option C: AWS Free Tier
- **1 t2.micro EC2** free for 12 months (1 GB RAM, 1 vCPU, shared)
- **30 GB EBS** storage
- **Cost:** $0 for 12 months, then ~$10/month
- **Sign up:** https://aws.amazon.com/free/
- **After Trial:** Switch to Oracle Cloud (always free)

#### Option D: Local Development (BEST FOR COST)
- **Run on your laptop** with K3s (docker-desktop or K3s native)
- **Cost:** $0 (electricity only)
- **Best for:** Development, learning, small team

### DNS: DuckDNS (FREE)
- **Domain:** yourapp.duckdns.org (free subdomain)
- **Cost:** $0
- **Sign up:** https://www.duckdns.org/
- **Update script:** Runs on your server every 5 min to sync IP

### HTTPS: Let's Encrypt (FREE)
- **Certificates:** Free SSL/TLS certs, auto-renewal
- **Cost:** $0
- **Tool:** Certbot on K3s via cert-manager
- **Setup:** Automatic via cert-manager Helm chart

---

## 🚀 $0 Deployment Setup

### Step 1: Get Free VM (Oracle Cloud)

```bash
# Sign up for Oracle Cloud free tier
# https://www.oracle.com/cloud/free/

# Create compute instance:
# - Image: Ubuntu 22.04 LTS (free)
# - Shape: Ampere A1 Compute (4 cores, 6 GB RAM, always free)
# - Storage: 50 GB (free)

# SSH into VM
ssh ubuntu@your-vm-ip
```

### Step 2: Install K3s (Lightweight Kubernetes)

```bash
# Install K3s (single command, ~1 min)
curl -sfL https://get.k3s.io | sh -

# Verify
sudo k3s kubectl get nodes

# Copy kubeconfig to local machine (optional)
# scp ubuntu@vm-ip:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

**Resource Usage:**
- K3s uses ~200 MB RAM (vs EKS 1+ GB)
- ~5 GB disk space
- Leaves plenty for app pods

### Step 3: Install Ingress & Cert-Manager

```bash
# Add Helm repos
sudo k3s kubectl repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
sudo k3s kubectl repo add jetstack https://charts.jetstack.io
sudo k3s kubectl repo update

# Install nginx-ingress (already in K3s, but ensure it's configured)
sudo k3s kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager (for Let's Encrypt certs)
sudo k3s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | sudo k3s kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Step 4: Create Namespace & Secrets

```bash
# Create namespace
sudo k3s kubectl create namespace orderit-prod

# Create secrets for external services
sudo k3s kubectl create secret generic orderit-backend-secrets -n orderit-prod \
  --from-literal=DB_LOCAL_URI="mongodb+srv://user:pass@cluster.mongodb.net/Internship" \
  --from-literal=JWT_SECRET="your-64-char-random-key" \
  --from-literal=CLOUDINARY_CLOUD_NAME="your-cloud-name" \
  --from-literal=CLOUDINARY_API_KEY="your-api-key" \
  --from-literal=CLOUDINARY_API_SECRET="your-api-secret" \
  --from-literal=EMAIL_USERNAME="your-mailtrap-user" \
  --from-literal=EMAIL_PASSWORD="your-mailtrap-pass" \
  --from-literal=STRIPE_SECRET_KEY="sk_test_..." \
  --from-literal=STRIPE_API_KEY="pk_test_..."
```

### Step 5: Create Manifests (app/k8s/)

**backend-deployment.yaml** (adapted for free tier):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orderit-backend
  namespace: orderit-prod
spec:
  replicas: 1  # Single replica (free tier)
  selector:
    matchLabels:
      app: orderit
      component: backend
  template:
    metadata:
      labels:
        app: orderit
        component: backend
    spec:
      containers:
      - name: backend
        image: ghcr.io/your-github-username/orderit-backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 4000
        env:
        - name: PORT
          value: "4000"
        - name: NODE_ENV
          value: "PRODUCTION"
        - name: DB_LOCAL_URI
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: DB_LOCAL_URI
        # ... (other env vars from secret)
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi  # Low limits for free tier

---
apiVersion: v1
kind: Service
metadata:
  name: orderit-backend
  namespace: orderit-prod
spec:
  type: ClusterIP
  ports:
  - port: 4000
    targetPort: 4000
  selector:
    app: orderit
    component: backend
```

**frontend-deployment.yaml** (static nginx):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orderit-frontend
  namespace: orderit-prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orderit
      component: frontend
  template:
    metadata:
      labels:
        app: orderit
        component: frontend
    spec:
      containers:
      - name: frontend
        image: ghcr.io/your-github-username/orderit-frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 100m
            memory: 256Mi

---
apiVersion: v1
kind: Service
metadata:
  name: orderit-frontend
  namespace: orderit-prod
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: orderit
    component: frontend
```

**ingress.yaml** (with Let's Encrypt):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orderit-ingress
  namespace: orderit-prod
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - orderit.duckdns.org  # Your free DuckDNS domain
    secretName: orderit-tls
  rules:
  - host: orderit.duckdns.org
    http:
      paths:
      - path: /api/v1
        pathType: Prefix
        backend:
          service:
            name: orderit-backend
            port:
              number: 4000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: orderit-frontend
            port:
              number: 80
```

### Step 6: Build & Push Images to GHCR

**GitHub Actions Workflow** (`.github/workflows/build.yml`):
```yaml
name: Build & Push to GHCR

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Log in to GHCR
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    # Build backend
    - name: Build & push backend
      uses: docker/build-push-action@v4
      with:
        context: ./app/backend
        push: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/orderit-backend:latest

    # Build frontend
    - name: Build & push frontend
      uses: docker/build-push-action@v4
      with:
        context: ./app/frontend
        file: ./app/frontend/Dockerfile
        push: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/orderit-frontend:latest
```

### Step 7: Deploy to K3s

```bash
# From your laptop (or SSH'd into VM)
sudo k3s kubectl apply -f app/k8s/configmap.yaml
sudo k3s kubectl apply -f app/k8s/backend-deployment.yaml
sudo k3s kubectl apply -f app/k8s/frontend-deployment.yaml
sudo k3s kubectl apply -f app/k8s/ingress.yaml

# Verify
sudo k3s kubectl get pods -n orderit-prod -w
sudo k3s kubectl get ingress -n orderit-prod -w
```

### Step 8: Setup DuckDNS for Free Domain

```bash
# On your VM
curl -s -X GET "https://www.duckdns.org/update?domains=your-domain&token=your-token&ip=" > /tmp/duckdns_update.log

# Schedule cron job (runs every 5 min to keep IP synced)
# crontab -e
# */5 * * * * curl -s -X GET "https://www.duckdns.org/update?domains=your-domain&token=your-token&ip=" > /tmp/duckdns_update.log
```

---

## 🔧 Local Development (Even Cheaper)

Run everything on your laptop:

```bash
# Install Docker Desktop (includes K3s/Kubernetes)
# https://www.docker.com/products/docker-desktop

# Or: K3s on native Linux/Mac
curl -sfL https://get.k3s.io | sh -

# Run backend locally
cd app/backend
npm install --legacy-peer-deps
NODE_ENV=DEVELOPMENT node server.js

# In another terminal: run frontend
cd app/frontend
npm install --legacy-peer-deps
npm start

# Or: build & run in K3s locally
docker build -t orderit-backend:local app/backend/
docker build -t orderit-frontend:local app/frontend/

# Push to local K3s
k3s ctr images import orderit-backend.tar
k3s ctr images import orderit-frontend.tar

# Deploy to local K3s
k3s kubectl apply -f app/k8s/
```

---

## 💰 Monthly Cost Breakdown ($0)

| Service | Cost | Notes |
|---------|------|-------|
| **Compute** | $0 | Oracle Cloud free VM (always free) |
| **Kubernetes** | $0 | K3s (open-source) |
| **Database** | $0 | MongoDB Atlas M0 (512 MB, free forever) |
| **Images** | $0 | Cloudinary free tier (10 GB) |
| **Email** | $0 | Mailtrap free (50/month) |
| **Payments** | $0 | Stripe test mode |
| **Container Registry** | $0 | GitHub Container Registry |
| **CI/CD** | $0 | GitHub Actions (2,000 min/month) |
| **DNS** | $0 | DuckDNS (free subdomain) |
| **HTTPS** | $0 | Let's Encrypt (free cert) |
| **Total** | **$0** | All free tier / open-source |

---

## ⚠️ Free Tier Limitations & Workarounds

| Limit | Impact | Workaround |
|-------|--------|-----------|
| MongoDB Atlas 512 MB | ~1,000 food items, 100 orders | Enough for MVP. Archive old data if needed. |
| Cloudinary 10 GB/month bandwidth | High traffic could hit limit | Lazy-load images, optimize sizes, add CDN cache headers |
| Mailtrap 50 emails/month | Limited email testing | Suitable for dev. Use real email provider (SendGrid, Mailgun) for prod if needed. |
| GitHub Actions 2,000 min/month | Limited CI/CD | Enough for this project (10-20 builds/month × 10 min each) |
| Oracle VM CPU throttling | Slow response times | Runs fine for low traffic (<100 users). Cache aggressively. |
| DuckDNS (free subdomain) | Fixed domain name | Cannot use custom domain without paid DNS. Use orderit.duckdns.org. |

---

## 🚀 Scaling Beyond Free Tier (When Needed)

If traffic grows:

| Component | Free → Paid |
|-----------|-------------|
| MongoDB | Atlas M0 (512 MB) → M2 ($57/month, 10 GB) |
| Cloudinary | Free (10 GB/month) → Paid ($99+/month) |
| Compute | Oracle free VM → Oracle Compute ($10-50/month) |
| Domain | duckdns.org → Route53 ($0.50/month) |
| Email | Mailtrap (50/month) → SendGrid ($20/month, 100k/month) |

**Still under $150/month** for small production workload.

---

## 📋 $0 Deployment Checklist

- [ ] Oracle Cloud free account created & VM provisioned
- [ ] K3s installed on VM
- [ ] GitHub account with Container Registry enabled
- [ ] MongoDB Atlas M0 cluster created & connection URI obtained
- [ ] Cloudinary free account created & API keys obtained
- [ ] Stripe test keys obtained
- [ ] Mailtrap free account created & SMTP credentials obtained
- [ ] DuckDNS account created & domain registered
- [ ] GitHub Actions workflow created for auto-build/push
- [ ] K8s manifests created (backend, frontend, ingress, cert-manager)
- [ ] Certificates auto-provisioned by Let's Encrypt
- [ ] App deployed to K3s & accessible via https://orderit.duckdns.org
- [ ] Health checks verified
- [ ] Monitoring: Free tier CloudWatch alternative (e.g., Grafana Cloud)

---

## 🔐 $0 Security (Best Practices)

- [ ] All secrets in K8s Secrets (not env files)
- [ ] HTTPS enforced (Let's Encrypt certs)
- [ ] Firewall rules: Only expose HTTP(S) ports
- [ ] No public SSH access (use bastion or VPN)
- [ ] Regular MongoDB backups (Atlas auto-backups)
- [ ] Image scanning: GitHub Container Registry scans free
- [ ] Log aggregation: Free tier ELK or use K3s logs

---

## 📞 Free Monitoring & Logging

- **K3s Logs:** `sudo k3s kubectl logs -n orderit-prod <pod>`
- **Metrics:** Install free Prometheus stack (10 min setup)
- **Uptime Monitoring:** Uptime Robot (free, 50 monitors)
- **Error Tracking:** Sentry free tier (5k events/month)
- **Application Insights:** GCP Cloud Trace (free tier)

---

## 🎯 COST POLICY FOR THIS PROJECT

**ALL infrastructure decisions MUST follow:**

1. ✅ Use free tier of existing services (Atlas, Cloudinary, Stripe test, Mailtrap)
2. ✅ Use open-source tools (K3s, Prometheus, cert-manager)
3. ✅ Use always-free VMs (Oracle Cloud free tier preferred)
4. ✅ Reuse existing resources (GitHub, Docker Hub/GHCR)
5. ❌ NO paid AWS services (EKS costs $73/month)
6. ❌ NO paid domains (.com costs $10/year; use duckdns.org)
7. ❌ NO paid monitoring (use open-source Prometheus/Grafana)
8. ❌ Never suggest paid upgrades without explicit cost analysis

**When adding features:**
- Check free tier capacity first
- Optimize for minimal resource usage
- Archive/clean old data to stay under limits
- Suggest open-source alternatives before paid SaaS

**When hitting limits:**
- Discuss with team BEFORE upgrading
- Provide cost breakdown + ROI analysis
- Explore free alternatives first

---

## 📚 References

- **K3s Docs:** https://docs.k3s.io/
- **MongoDB Atlas Free Tier:** https://www.mongodb.com/cloud/atlas
- **Let's Encrypt:** https://letsencrypt.org/
- **cert-manager:** https://cert-manager.io/
- **DuckDNS:** https://www.duckdns.org/
- **GitHub Container Registry:** https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- **Kubernetes Docs:** https://kubernetes.io/docs/

---

**This is the production deployment setup for Orderit, completely free. Scale it when revenue justifies the cost.**
