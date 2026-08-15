# Orderit - Complete Documentation & DevOps Guide

**Project:** Food Delivery Application (MERN Stack)  
**Documentation Date:** 2026-08-15  
**Status:** Application tested locally & running ✓, Documentation complete ✓

---

## 📋 Documentation Files

### 1. **ARCHITECTURE.md** — Application Design & Components
Complete breakdown of the MERN stack architecture:
- **Backend:** Express.js routes, controllers, models, middlewares, external services (Cloudinary, Stripe, Mailtrap)
- **Frontend:** React + Redux state management, pages, components, routing
- **Database:** MongoDB Atlas schemas (User, Restaurant, FoodItem, Order, Review, Coupon)
- **Running Locally:** Step-by-step setup guide (backend on :4000, frontend on :3000, proxied to backend)
- **Deployment Checklist:** Pre-prod readiness items (de-obfuscation, health checks, logging, rate limiting, etc.)

**Key Issues Flagged:**
- ⚠️ **Code Obfuscation:** `app.js`, `server.js`, `database.js` are obfuscated (javascript-obfuscator) — unreadable & hostile to AI/static analysis. **Must de-obfuscate before production.**
- No health check endpoints (`/health`, `/ready`) — needed for K8s readiness/liveness probes.
- Weak authentication security (localStorage JWT, vulnerable to XSS).

**Use when:** Understanding the app structure, onboarding new engineers, local development.

---

### 2. **INFRA_DESIGN.md** — Kubernetes & Cloud Architecture
Complete infrastructure blueprint for production deployment:

#### Part 1: Generic Kubernetes (Cloud-Agnostic)
- Namespace, RBAC, ServiceAccount
- ConfigMap & Secret management
- Backend Deployment (Node.js) with 2-6 replicas, health probes, resource limits
- Frontend Deployment (Nginx serving static React build)
- Services (ClusterIP for internal routing)
- Ingress (nginx-ingress, path-based routing `/api/*` → backend, `/` → frontend)
- HPA (Horizontal Pod Autoscaler: CPU-based 70%, 2-6 replicas)
- Network Policies (restrict inter-pod traffic)

#### Part 2: AWS EKS (AWS-Specific)
- **VPC:** 10.0.0.0/16 across 2 AZs, public/private subnets, NAT gateways
- **EKS Cluster:** Kubernetes 1.27+, managed node groups (t3.medium)
- **ECR:** Private image repos for backend & frontend
- **AWS Secrets Manager + External Secrets Operator:** Sync Stripe keys, DB credentials securely
- **ALB Ingress Controller:** AWS Load Balancer Controller for public traffic (HTTPS via ACM)
- **Route53 + ACM:** Domain + TLS certificates
- **CloudWatch Container Insights:** Logs & metrics (API server, audit, etcd, etc.)

#### Part 3: Terraform Modules
Recommended modules for IaC:
- `terraform-aws-modules/vpc/aws` — VPC, subnets, NAT
- `terraform-aws-modules/eks/aws` — EKS cluster + node groups
- `terraform-aws-modules/iam/aws` — IRSA for service accounts
- `aws-ia/eks-blueprints-addons/aws` — ALB controller, metrics-server, autoscaler
- `terraform-aws-modules/ecr/aws` — ECR repos
- `terraform-aws-modules/acm/aws` — TLS certs

**Use when:** Planning K8s infrastructure, understanding networking (EKS vs. generic K8s differences), deployment workflow.

---

### 3. **TERRAFORM_MODULES.md** — Detailed IaC Reference
Complete Terraform implementation guide with copy-paste configs:
- Module selection table (all AWS modules with versions)
- Detailed HCL for each module (VPC, EKS, IRSA, ECR, ACM, security groups, addons)
- Directory structure & file organization
- Deployment commands (init, plan, apply, destroy)
- Cost estimate (~$150-180/month baseline)
- Cost optimization tips (Spot instances, Reserved Instances, single NAT)
- Post-deployment validation steps

**Use when:** Implementing Terraform for AWS, writing IaC, managing infrastructure as code.

---

## 🏃 Quick Start Guide

### Local Development (Already Tested ✓)

**Backend:**
```bash
cd app/backend
npm install --legacy-peer-deps
# Update config/config.env with MongoDB Atlas URI
NODE_ENV=DEVELOPMENT node server.js
# Server runs on http://localhost:4000
```

**Frontend:**
```bash
cd app/frontend
npm install --legacy-peer-deps
npm start
# App runs on http://localhost:3000 (auto-proxies /api to :4000)
```

**Test:**
```bash
curl http://localhost:4000/api/v1/eats/menus
# Backend logs should show MongoDB connection + query execution
```

**✓ Status:** Backend running on port 4000 (confirmed), connected to MongoDB Atlas, API responding.

---

## 🚀 Production Deployment Paths

### Option A: Generic Kubernetes (minikube, kind, or any managed K8s)
1. Use manifests from **INFRA_DESIGN.md** (Part 1)
2. No cloud-specific setup needed
3. Suitable for multi-cloud or on-premise deployments

### Option B: AWS EKS (Recommended if using AWS)
1. Run Terraform configs from **TERRAFORM_MODULES.md**
2. Builds VPC, EKS cluster, ECR, IAM, ALB, security groups
3. Deploy K8s manifests from **INFRA_DESIGN.md** (Part 1)
4. Point domain (Route53) to ALB
5. Verify via CloudWatch dashboards

### Deployment Steps (EKS):
```bash
# 1. Apply Terraform
cd infra/terraform
terraform apply

# 2. Get cluster credentials
aws eks update-kubeconfig --name orderit-eks-prod --region us-east-1

# 3. Build & push images to ECR
docker build -t orderit-backend:1.0.0 app/backend/
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_URI>
docker tag orderit-backend:1.0.0 <ECR_URI>/orderit-backend:1.0.0
docker push <ECR_URI>/orderit-backend:1.0.0
# (repeat for frontend)

# 4. Create namespace & secrets
kubectl create namespace orderit-prod
kubectl create secret generic orderit-backend-secrets -n orderit-prod \
  --from-literal=DB_LOCAL_URI="..." \
  --from-literal=JWT_SECRET="..." \
  # ... (all env vars from config.env)

# 5. Deploy manifests
kubectl apply -f k8s/

# 6. Verify
kubectl get pods -n orderit-prod -w
kubectl get svc -n orderit-prod
kubectl get ingress -n orderit-prod
```

---

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ User Browser                                                 │
└────────────────┬──────────────────────────────────────────────┘
                 │ HTTPS (443)
                 ▼
        ┌─────────────────┐
        │ AWS ALB / Ingress │ (TLS cert from ACM)
        └────────┬────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    Frontend        Backend API
    (Nginx)         (Node.js)
    :80             :4000
    └────┬─────────►│
    SPA routing    Controllers
    index.html     │
                   ├──► MongoDB Atlas (DB)
                   ├──► Cloudinary (Images)
                   ├──► Stripe (Payments)
                   └──► Mailtrap (Email)
```

---

## 📝 Critical Tasks Before Production

| Task | Status | Priority | Notes |
|------|--------|----------|-------|
| De-obfuscate `app.js`, `server.js` | ❌ TODO | **CRITICAL** | Required for maintenance, security audits, AI tooling |
| Add health endpoints (`/health`, `/ready`) | ❌ TODO | **HIGH** | K8s probes won't work without these |
| Implement JWT in httpOnly cookies | ❌ TODO | **HIGH** | Prevent XSS token theft |
| Add input validation & sanitization | ❌ TODO | **HIGH** | Currently missing (SQL injection, XSS risks) |
| Set up structured logging (not console.log) | ❌ TODO | HIGH | CloudWatch integration |
| Configure CORS properly (restrict to domain) | ❌ TODO | HIGH | Don't use `*` in production |
| Implement rate limiting on auth routes | ❌ TODO | MEDIUM | Brute-force protection |
| Add Sentry or similar error tracking | ❌ TODO | MEDIUM | Production debugging |
| Create Dockerfiles for both backend & frontend | ❌ TODO | MEDIUM | Required for K8s deployment |
| Set up CI/CD pipeline (GitHub Actions, Jenkins) | ❌ TODO | MEDIUM | Auto-build & push to ECR |
| Test disaster recovery (DB backup restore) | ❌ TODO | MEDIUM | MongoDB Atlas has automated backups |

---

## 📚 Environment Variables Reference

### Backend (config/config.env)
```
PORT=4000
NODE_ENV=DEVELOPMENT|PRODUCTION
DB_LOCAL_URI=mongodb+srv://user:pass@cluster.mongodb.net/Internship
FRONTEND_URL=http://localhost:3000
JWT_SECRET=<64-char-random>
JWT_EXPIRES_TIME=90
CLOUDINARY_CLOUD_NAME=<name>
CLOUDINARY_API_KEY=<key>
CLOUDINARY_API_SECRET=<secret>
EMAIL_HOST=sandbox.smtp.mailtrap.io
EMAIL_PORT=25
EMAIL_USERNAME=<user>
EMAIL_PASSWORD=<pass>
EMAIL_FROM=noreply@orderit.com
STRIPE_SECRET_KEY=sk_test_...
STRIPE_API_KEY=pk_test_...
```

### Frontend (CRA, set at build time)
```
REACT_APP_STRIPE_PUBLIC_KEY=pk_test_...
REACT_APP_API_BASE_URL=http://localhost:4000/api/v1  (dev)
REACT_APP_API_BASE_URL=https://api.orderit.com/api/v1  (prod)
```

---

## 🔐 Security Checklist

- [ ] All secrets in AWS Secrets Manager (not K8s Secrets in Git)
- [ ] TLS enabled on ALB (ACM cert)
- [ ] Network policies restrict pod-to-pod traffic
- [ ] Security groups restrict inbound to ALB only
- [ ] Service accounts have minimal IAM permissions (IRSA)
- [ ] Pod security policy enforces read-only filesystem, non-root user
- [ ] Secrets not logged or exposed in error messages
- [ ] Regular security scanning (ECR image scanning, SAST)
- [ ] Rate limiting on public endpoints
- [ ] Input validation on all user-facing APIs

---

## 📞 Support & Troubleshooting

### Backend won't connect to MongoDB
- Check Atlas network access list (add your IP)
- Verify DB URI in config.env (percent-encode special chars: `!` → `%21`)
- Check firewall rules (NAT gateway must be able to reach Atlas)

### Kubernetes pod stuck in pending/crashloop
- Check logs: `kubectl logs -n orderit-prod <pod-name>`
- Check events: `kubectl describe pod -n orderit-prod <pod-name>`
- Check resource requests/limits: `kubectl top pods -n orderit-prod`
- Check image pull: `kubectl get events -n orderit-prod`

### HPA not scaling
- Verify metrics-server is installed: `kubectl get deployment -n kube-system metrics-server`
- Check HPA status: `kubectl describe hpa -n orderit-prod`
- Monitor: `kubectl get hpa -n orderit-prod -w`

### Image push to ECR fails
- Verify AWS credentials: `aws sts get-caller-identity`
- Check ECR repo exists: `aws ecr describe-repositories`
- Login: `aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_URI>`

---

## 📖 Related Documentation

- **Kubernetes Docs:** https://kubernetes.io/docs/
- **EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/
- **Terraform Registry:** https://registry.terraform.io/
- **MongoDB Atlas:** https://docs.atlas.mongodb.com/
- **Stripe API:** https://stripe.com/docs/api
- **Express.js:** https://expressjs.com/
- **React:** https://react.dev/

---

## 🎯 Next Steps

1. **De-obfuscate backend code** (CRITICAL)
2. **Add health check endpoints** (required for K8s)
3. **Create Dockerfiles** for backend & frontend
4. **Set up CI/CD** (GitHub Actions or Jenkins)
5. **Deploy to EKS** using Terraform + K8s manifests
6. **Configure monitoring** (CloudWatch + alarms)
7. **Load test** & optimize (scale testing, DB indexing)
8. **Go live** & monitor in production

---

**Documentation Version:** 1.0  
**Last Updated:** 2026-08-15  
**Maintainer:** DevOps/Infrastructure Team
