# Orderit - Infrastructure Design & Kubernetes Deployment

**Document:** Cloud-native infrastructure plan for Orderit food delivery app  
**Target Platforms:** Generic Kubernetes (cloud-agnostic) + AWS EKS (AWS-specific)  
**Scope:** Deployments, networking, storage, secrets, monitoring, autoscaling

---

## Architecture Overview

```mermaid
graph TB
    Internet["Internet"]
    ALB["AWS ALB / Ingress<br/>(TLS + Load Balance)"]
    IngressCtrl["Ingress Controller<br/>(Nginx)"]
    FrontendSvc["Frontend Service<br/>(ClusterIP)"]
    BackendSvc["Backend Service<br/>(ClusterIP)"]
    FrontendDeploy["Frontend Deployment<br/>(Nginx)<br/>Replicas: 2"]
    BackendDeploy["Backend Deployment<br/>(Node)<br/>Replicas: 2-6"]
    ConfigMap["ConfigMap<br/>(Env vars)"]
    Secret["Secret<br/>(API keys)"]
    HPA["HPA<br/>(CPU-based)"]
    MongoDB["MongoDB Atlas<br/>(External)"]
    Cloudinary["Cloudinary<br/>(External)"]
    Stripe["Stripe<br/>(External)"]
    ECR["ECR Repos<br/>(backend, frontend)"]
    
    Internet -->|HTTPS:443| ALB
    ALB -->|HTTP:80| IngressCtrl
    IngressCtrl -->|/api/v1/*| BackendSvc
    IngressCtrl -->|/| FrontendSvc
    FrontendSvc --> FrontendDeploy
    BackendSvc --> BackendDeploy
    BackendDeploy -->|reads| ConfigMap
    BackendDeploy -->|reads| Secret
    BackendDeploy -->|HPA triggers| HPA
    BackendDeploy -->|MongoDB| MongoDB
    BackendDeploy -->|Images| Cloudinary
    BackendDeploy -->|Payments| Stripe
    FrontendDeploy -->|pulls image| ECR
    BackendDeploy -->|pulls image| ECR
    
    style ALB fill:#ff9900
    style IngressCtrl fill:#4b8bbf
    style FrontendDeploy fill:#61dafb
    style BackendDeploy fill:#90c53f
    style MongoDB fill:#13aa52
    style HPA fill:#ffd700
```

---

## Part 1: Generic Kubernetes (Cloud-Agnostic)

### 1.1 Namespace & RBAC

Create dedicated namespace for the app:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: orderit-prod
  labels:
    app: orderit
```

ServiceAccount for the app (optional, for fine-grained RBAC):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: orderit-app
  namespace: orderit-prod
```

---

### 1.2 ConfigMap (Non-Secret Environment Variables)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: orderit-backend-config
  namespace: orderit-prod
data:
  PORT: "4000"
  NODE_ENV: "PRODUCTION"
  FRONTEND_URL: "https://orderit.example.com"
  JWT_EXPIRES_TIME: "90"
  EMAIL_HOST: "sandbox.smtp.mailtrap.io"
  EMAIL_PORT: "25"
  EMAIL_FROM: "noreply@orderit.com"
```

---

### 1.3 Secret (Sensitive Data)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: orderit-backend-secrets
  namespace: orderit-prod
type: Opaque
stringData:
  DB_LOCAL_URI: "mongodb+srv://user:pass@cluster.mongodb.net/Internship"
  JWT_SECRET: "<64-char-random-key>"
  CLOUDINARY_CLOUD_NAME: "<cloud-name>"
  CLOUDINARY_API_KEY: "<api-key>"
  CLOUDINARY_API_SECRET: "<api-secret>"
  EMAIL_USERNAME: "<mailtrap-user>"
  EMAIL_PASSWORD: "<mailtrap-pass>"
  STRIPE_SECRET_KEY: "sk_live_..."
  STRIPE_API_KEY: "pk_live_..."
```

**Note:** In production, use AWS Secrets Manager + External Secrets Operator (see AWS EKS section) instead of hardcoding Secrets in manifests.

---

### 1.4 Backend Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orderit-backend
  namespace: orderit-prod
  labels:
    app: orderit
    component: backend
spec:
  replicas: 2  # Start with 2, scale with HPA
  selector:
    matchLabels:
      app: orderit
      component: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: orderit
        component: backend
    spec:
      serviceAccountName: orderit-app
      containers:
      - name: backend
        image: <REGISTRY>/orderit-backend:1.0.0  # ECR URI or Docker Hub
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 4000
          name: http
          protocol: TCP
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: orderit-backend-config
              key: PORT
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: orderit-backend-config
              key: NODE_ENV
        - name: FRONTEND_URL
          valueFrom:
            configMapKeyRef:
              name: orderit-backend-config
              key: FRONTEND_URL
        - name: DB_LOCAL_URI
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: DB_LOCAL_URI
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: JWT_SECRET
        - name: CLOUDINARY_CLOUD_NAME
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: CLOUDINARY_CLOUD_NAME
        - name: CLOUDINARY_API_KEY
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: CLOUDINARY_API_KEY
        - name: CLOUDINARY_API_SECRET
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: CLOUDINARY_API_SECRET
        - name: EMAIL_USERNAME
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: EMAIL_USERNAME
        - name: EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: EMAIL_PASSWORD
        - name: STRIPE_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: STRIPE_SECRET_KEY
        - name: STRIPE_API_KEY
          valueFrom:
            secretKeyRef:
              name: orderit-backend-secrets
              key: STRIPE_API_KEY
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 4000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        # Resource limits
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
              - ALL
      # Pod-level security
      securityContext:
        fsGroup: 1000
```

**⚠️ TODO:** Backend currently has no `/health` or `/ready` endpoints. Add these before deploying:

```javascript
// In server.js or app.js
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/ready', (req, res) => {
  // Check DB connectivity
  if (mongoose.connection.readyState === 1) {
    return res.json({ ready: true });
  }
  res.status(503).json({ ready: false });
});
```

---

### 1.5 Backend Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: orderit-backend
  namespace: orderit-prod
  labels:
    app: orderit
    component: backend
spec:
  type: ClusterIP
  ports:
  - port: 4000
    targetPort: 4000
    name: http
  selector:
    app: orderit
    component: backend
```

---

### 1.6 Frontend Deployment (Static + Nginx)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orderit-frontend
  namespace: orderit-prod
  labels:
    app: orderit
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orderit
      component: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: orderit
        component: frontend
    spec:
      containers:
      - name: frontend
        image: <REGISTRY>/orderit-frontend:1.0.0  # Nginx serving static build
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 101  # Nginx user
      securityContext:
        fsGroup: 101
```

**Frontend Dockerfile** (for building the image):

```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --legacy-peer-deps
COPY . .
RUN npm run build

# Serve stage
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**nginx.conf** (for SPA routing & backend proxy):

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  sendfile on;
  keepalive_timeout 65;

  server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;

    # SPA routing: all non-asset requests → index.html
    location / {
      try_files $uri $uri/ /index.html;
    }

    # Backend proxy
    location /api/v1/ {
      proxy_pass http://orderit-backend:4000;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection 'upgrade';
      proxy_set_header Host $host;
      proxy_cache_bypass $http_upgrade;
    }
  }
}
```

---

### 1.7 Frontend Service

```yaml
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
    name: http
  selector:
    app: orderit
    component: frontend
```

---

### 1.8 Ingress (Public Access)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orderit-ingress
  namespace: orderit-prod
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod  # For HTTPS (if cert-manager installed)
spec:
  ingressClassName: nginx
  rules:
  - host: orderit.example.com  # Replace with actual domain
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
  tls:
  - hosts:
    - orderit.example.com
    secretName: orderit-tls  # Cert-manager will populate this
```

**Prerequisites:**
- Install nginx-ingress controller: `helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace`
- Optional: Install cert-manager for auto-HTTPS

---

### 1.9 Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: orderit-backend-hpa
  namespace: orderit-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orderit-backend
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale up if avg CPU > 70%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
```

**Requirement:** Metrics Server must be installed for HPA to work:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

### 1.10 Network Policy (Optional but Recommended)

Restrict traffic: frontend ↔ backend, both ↔ external services only.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: orderit-network-policy
  namespace: orderit-prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: orderit
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: orderit
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53  # DNS
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 443  # External HTTPS (MongoDB Atlas, Stripe, Cloudinary)
    - protocol: TCP
      port: 25   # SMTP (Mailtrap)
```

---

## Part 2: AWS EKS (AWS-Specific Architecture)

### 2.1 VPC & Networking

**Infrastructure:**
- VPC with CIDR `10.0.0.0/16`
- 2 Availability Zones (high availability)
- Public subnets for NAT gateways + ALB
- Private subnets for EKS nodes (no direct internet access)
- NAT Gateways for egress (nodes → MongoDB Atlas, Stripe, Cloudinary, SMTP)

**AWS Resources:**
- VPC + Internet Gateway
- Public Subnets: `10.0.0.0/24` (AZ-a), `10.0.1.0/24` (AZ-b)
- Private Subnets: `10.0.10.0/24` (AZ-a), `10.0.11.0/24` (AZ-b)
- NAT Gateways: one per AZ
- Route tables: public (→ IGW), private (→ NAT)

---

### 2.2 EKS Cluster

**Cluster Setup:**
- Kubernetes version: 1.27+
- Cluster name: `orderit-eks-prod`
- Endpoint access: Private (no public endpoint) or restrict via security groups
- Logging: CloudWatch (API server, audit, authenticator, controller manager, scheduler)

**Node Group:**
- Name: `orderit-ng-main`
- Instance type: `t3.medium` (2 vCPU, 4 GB RAM) — cost-effective for small-medium workloads
- Min nodes: 2 (high availability)
- Max nodes: 4 (scaling limit)
- Desired: 2
- AMI type: AL2 (Amazon Linux 2)
- Block device: 50 GB gp3 EBS
- IAM role: Allows EC2 instance role to pull from ECR, write logs to CloudWatch

---

### 2.3 ECR (Elastic Container Registry)

Create repositories for images:

```bash
# Backend repo
aws ecr create-repository --repository-name orderit-backend --region us-east-1

# Frontend repo
aws ecr create-repository --repository-name orderit-frontend --region us-east-1
```

Image URIs:
- Backend: `<AWS_ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/orderit-backend:1.0.0`
- Frontend: `<AWS_ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/orderit-frontend:1.0.0`

---

### 2.4 AWS Secrets Manager + External Secrets Operator

Instead of hardcoding K8s Secrets, use AWS Secrets Manager for sensitive data:

**Create secret in Secrets Manager:**
```bash
aws secretsmanager create-secret \
  --name orderit/backend \
  --secret-string '{
    "DB_LOCAL_URI": "mongodb+srv://...",
    "JWT_SECRET": "...",
    "CLOUDINARY_CLOUD_NAME": "...",
    "STRIPE_SECRET_KEY": "sk_live_..."
  }' \
  --region us-east-1
```

**Install External Secrets Operator (Helm):**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace
```

**SecretStore (references AWS Secrets Manager):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: orderit-prod
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: orderit-app
```

**ExternalSecret (syncs AWS secret → K8s Secret):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: orderit-backend-secrets
  namespace: orderit-prod
spec:
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: orderit-backend-secrets
    creationPolicy: Owner
  data:
  - secretKey: DB_LOCAL_URI
    remoteRef:
      key: orderit/backend
      property: DB_LOCAL_URI
  - secretKey: JWT_SECRET
    remoteRef:
      key: orderit/backend
      property: JWT_SECRET
  # ... (repeat for all secrets)
```

**IAM Role for Service Account (IRSA):**
```yaml
# Trust policy for External Secrets Operator to assume role
apiVersion: v1
kind: ServiceAccount
metadata:
  name: orderit-app
  namespace: orderit-prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT>:role/orderit-app-role
```

IAM role `orderit-app-role` policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:<ACCOUNT>:secret:orderit/*"
    }
  ]
}
```

---

### 2.5 ALB Ingress Controller (AWS Load Balancer Controller)

**Install Helm chart:**
```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=orderit-eks-prod \
  --set serviceAccount.create=true
```

**Ingress with ALB annotation:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orderit-alb-ingress
  namespace: orderit-prod
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:<ACCOUNT>:certificate/<CERT-ID>
    alb.ingress.kubernetes.io/group.name: orderit-alb
    alb.ingress.kubernetes.io/group.order: '10'
spec:
  ingressClassName: alb
  rules:
  - host: orderit.example.com
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

---

### 2.6 Route53 + ACM (DNS & TLS)

**ACM Certificate:**
- Request public cert for `orderit.example.com` in ACM
- Validate via DNS CNAME in Route53
- ARN: `arn:aws:acm:us-east-1:<ACCOUNT>:certificate/<CERT-ID>`

**Route53 Record:**
```
Name: orderit.example.com
Type: A (Alias)
Alias Target: ALB DNS name (auto-populated by ALB Ingress Controller)
```

---

### 2.7 CloudWatch Container Insights (Monitoring & Logs)

**Enable on cluster:**
```bash
aws eks update-cluster-logging --cluster-name orderit-eks-prod \
  --logging-config clusterLogging='[
    {
      "enabled": true,
      "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    }
  ]' \
  --region us-east-1
```

**Install Container Insights agent:**
```bash
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | kubectl apply -f -
```

**View logs & metrics:**
- CloudWatch → Container Insights → Performance Monitoring (pods, nodes, cluster)
- CloudWatch → Log Groups → `/aws/eks/orderit-eks-prod/...`

---

## Part 3: Terraform Modules (Infrastructure as Code)

Recommended Terraform modules for AWS EKS deployment:

### 3.1 VPC
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "orderit-vpc"
  cidr = "10.0.0.0/16"
  
  azs              = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false  # HA: NAT per AZ
  enable_dns_hostnames = true
  
  tags = {
    Name = "orderit-vpc"
  }
}
```

### 3.2 EKS Cluster
```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = "orderit-eks-prod"
  cluster_version = "1.27"
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  
  eks_managed_node_groups = {
    main = {
      name         = "orderit-ng-main"
      min_size     = 2
      max_size     = 4
      desired_size = 2
      
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      disk_size = 50
      
      labels = {
        Environment = "prod"
        Workload    = "general"
      }
    }
  }
  
  tags = {
    Name = "orderit-eks"
  }
}
```

### 3.3 ECR Repositories
```hcl
module "ecr_backend" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"
  
  repository_name = "orderit-backend"
  repository_type = "private"
  
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description = "Keep last 10 images"
        selection = {
          tagStatus = "untagged"
          countType = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
  
  tags = {
    Name = "orderit-backend"
  }
}

module "ecr_frontend" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"
  
  repository_name = "orderit-frontend"
  repository_type = "private"
  
  tags = {
    Name = "orderit-frontend"
  }
}
```

### 3.4 IAM Role for Service Accounts (IRSA)
```hcl
module "irsa_orderit_app" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  
  role_name = "orderit-app-role"
  
  attach_secrets_manager_policy = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:orderit/*"
  ]
  
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["orderit-prod:orderit-app"]
    }
  }
  
  tags = {
    Name = "orderit-app"
  }
}
```

### 3.5 ACM Certificate
```hcl
module "acm_cert" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"
  
  domain_name = "orderit.example.com"
  zone_id     = aws_route53_zone.main.zone_id
  
  validation_method = "DNS"
  
  tags = {
    Name = "orderit-cert"
  }
}
```

### 3.6 Addons (ALB Controller, Metrics Server, etc.)
```hcl
module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"
  
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  enable_aws_load_balancer_controller = true
  enable_metrics_server = true
  enable_external_secrets = true
  
  tags = {
    Name = "orderit-addons"
  }
}
```

---

## Deployment Workflow

### Step 1: Infrastructure (Terraform)
```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
# Outputs: EKS cluster name, ECR repo URIs, ALB DNS
```

### Step 2: Build & Push Images
```bash
# Backend
docker build -t orderit-backend:1.0.0 app/backend/
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URI
docker tag orderit-backend:1.0.0 $ECR_URI/orderit-backend:1.0.0
docker push $ECR_URI/orderit-backend:1.0.0

# Frontend
docker build -t orderit-frontend:1.0.0 app/frontend/ -f Dockerfile
docker tag orderit-frontend:1.0.0 $ECR_URI/orderit-frontend:1.0.0
docker push $ECR_URI/orderit-frontend:1.0.0
```

### Step 3: Namespace & Secrets
```bash
kubectl create namespace orderit-prod
kubectl create serviceaccount orderit-app -n orderit-prod

# Apply External Secrets for AWS Secrets Manager
kubectl apply -f k8s/secretstore.yaml
kubectl apply -f k8s/externalsecret.yaml

# Or directly create K8s Secret for local testing
kubectl create secret generic orderit-backend-secrets -n orderit-prod \
  --from-literal=DB_LOCAL_URI="..." \
  --from-literal=JWT_SECRET="..." \
  # ... (all env vars)
```

### Step 4: Deploy Manifests
```bash
# Update image URIs in manifests first
sed -i 's|<REGISTRY>|'$ECR_URI'|g' k8s/backend-deployment.yaml
sed -i 's|<REGISTRY>|'$ECR_URI'|g' k8s/frontend-deployment.yaml

# Apply
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### Step 5: Verify
```bash
# Check pods
kubectl get pods -n orderit-prod -w

# Check services
kubectl get svc -n orderit-prod

# Check ingress
kubectl get ingress -n orderit-prod

# Monitor logs
kubectl logs -n orderit-prod -f deployment/orderit-backend --tail 50
```

---

## Security Best Practices

1. **Network Isolation:** Use Security Groups + Network Policies
2. **Secrets Management:** AWS Secrets Manager + External Secrets Operator (not K8s Secrets in Git)
3. **RBAC:** Limit service accounts to minimal permissions
4. **Pod Security:** Run containers as non-root, read-only filesystem where possible
5. **Image Scanning:** Enable ECR image scanning for vulnerabilities
6. **TLS:** All external traffic encrypted (ALB + ACM)
7. **Logging & Auditing:** CloudWatch Container Insights + EKS audit logs
8. **Backup:** Regular MongoDB Atlas backups (automatic), no in-cluster DBs to manage

---

## Cost Optimization

- **Instance type:** t3.medium (burstable, cost-effective for variable workloads)
- **Auto-scaling:** HPA + Cluster Autoscaler (scale down idle nodes)
- **Reserved Instances:** Consider AWS RIs for stable baseline (1-3 year commitment)
- **NAT Gateway:** Single NAT per AZ (2 NATs = ~$0.045/hour combined)
- **ALB:** Hourly charge + per LCU (typically ~$0.03/hour for low traffic)
- **Monitoring:** CloudWatch charges per metric + log ingestion (~$0.50/GB)

---

## Monitoring & Alerting

### CloudWatch Alarms
- **Pod Restarts:** Alert if pod restarts > 5 in 5 mins
- **CPU/Memory:** Alert if avg > 80% for 5 mins
- **Node Count:** Alert if nodes fall below min (scale-down issue)
- **ALB Target Health:** Alert if unhealthy targets > 0
- **API Latency:** Alert if p99 latency > 500ms

### Dashboards
Create CloudWatch dashboard with:
- Pod count, node count, request count
- Error rate (HTTP 5xx)
- Latency (p50, p95, p99)
- Database connection count
- Stripe API errors (if exposed)

---

## Scaling Strategy

| Metric | Current | Peak Load | Scaling Action |
|--------|---------|-----------|-----------------|
| Backend Pods | 2 | 6 | HPA scales CPU/memory-based |
| Frontend Pods | 2 | 2 | Static (lightweight, CDN for static assets) |
| EKS Nodes | 2 | 4 | Cluster Autoscaler adds nodes |
| ALB | ✓ | ✓ | Auto-scales connections/requests |
| MongoDB Atlas | ✓ | ✓ | Auto-scales based on workload |

---

## Post-Deployment Checklist

- [ ] Health check endpoints implemented in backend (`/health`, `/ready`)
- [ ] Secrets rotated (JWT, API keys) in production
- [ ] TLS certificate verified in browser
- [ ] CloudWatch logs flowing from cluster
- [ ] HPA tested (stress-test backend, verify scale-up)
- [ ] Disaster recovery plan (DB backup, cluster backup)
- [ ] Security scanning enabled on ECR
- [ ] Team onboarded to kubectl access + RBAC
- [ ] Monitoring alerts configured + tested
- [ ] Cost monitoring dashboard created

---

## References

- **EKS Best Practices Guide:** https://aws.github.io/aws-eks-best-practices/
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **AWS ALB Ingress:** https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **External Secrets:** https://external-secrets.io/
- **Terraform AWS Modules:** https://registry.terraform.io/namespaces/terraform-aws-modules
