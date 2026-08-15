# Orderit DevOps - Terraform Modules Reference Guide

**Purpose:** Comprehensive guide to Terraform modules for provisioning AWS infrastructure (EKS, VPC, ECR, RDS, networking, security) for Orderit food delivery app.

**Target:** DevOps engineers implementing IaC for production deployment on AWS.

---

## Module Overview & Selection Guide

### Core Infrastructure Modules (AWS Provider ~> 5.0)

| Module | Purpose | Terraform Registry | Recommended Version |
|--------|---------|-------------------|-------------------|
| **vpc** | VPC, subnets, NAT, route tables, IGW | `terraform-aws-modules/vpc/aws` | `~> 5.0` |
| **eks** | EKS cluster, managed node groups, security groups | `terraform-aws-modules/eks/aws` | `~> 19.0` |
| **iam** | IAM roles, policies, service accounts | `terraform-aws-modules/iam/aws` | `~> 5.0` |
| **ecr** | ECR repositories, lifecycle policies | `terraform-aws-modules/ecr/aws` | `~> 1.0` |
| **acm** | ACM certificates, Route53 validation | `terraform-aws-modules/acm/aws` | `~> 4.0` |
| **security-group** | Security groups, ingress/egress rules | `terraform-aws-modules/security-group/aws` | `~> 4.0` |
| **autoscaling** | Auto Scaling Groups (for node scaling) | `terraform-aws-modules/autoscaling/aws` | `~> 6.0` |

### EKS Addons & Kubernetes Modules

| Module | Purpose | Registry | Version |
|--------|---------|----------|---------|
| **eks-blueprints-addons** | Bundled EKS addons (ALB controller, metrics-server, Karpenter, etc.) | `aws-ia/eks-blueprints-addons/aws` | `~> 1.0` |
| **external-secrets** | Helm chart for External Secrets Operator | Community Helm repo | Latest |
| **ingress-nginx** | Nginx Ingress Controller | Community Helm repo | Latest |
| **cert-manager** | Let's Encrypt / ACM cert automation | Community Helm repo | Latest |

---

## Detailed Module Configurations

### 1. VPC Module

**Purpose:** Create isolated networking environment (VPC, public/private subnets across 2 AZs, NAT gateways, route tables).

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "orderit-vpc"
  cidr = "10.0.0.0/16"

  # Availability Zones (2 for HA)
  azs = ["us-east-1a", "us-east-1b"]

  # Public subnets (for NAT gateways + ALB)
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnet_names = ["orderit-public-1a", "orderit-public-1b"]

  # Private subnets (for EKS nodes)
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  private_subnet_names = ["orderit-private-1a", "orderit-private-1b"]

  # Database subnets (optional, for future RDS)
  database_subnets = ["10.0.20.0/24", "10.0.21.0/24"]

  # NAT Gateway (high availability setup)
  enable_nat_gateway   = true
  single_nat_gateway   = false  # One NAT per AZ for HA
  enable_vpn_gateway   = false
  one_nat_gateway_per_az = true

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags
  tags = {
    Name        = "orderit-vpc"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}
```

**Cost:** ~$0.045/hour per NAT (2 NATs = ~$32/month)

---

### 2. EKS Cluster Module

**Purpose:** Create EKS cluster with managed node groups, security groups, logging.

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "orderit-eks-prod"
  cluster_version = "1.27"

  # Cluster endpoint access
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restrict in prod

  # Network
  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  # Cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7
  cloudwatch_log_group_kms_key_id = null  # Set to KMS key ARN for encryption

  # Cluster security group
  cluster_security_group_additional_rules = {
    egress_to_worker_nodes = {
      type                     = "egress"
      from_port                = 0
      to_port                  = 65535
      protocol                 = "tcp"
      destination_security_group_id = aws_security_group.node_additional.id
    }
  }

  # Managed node groups
  eks_managed_node_groups = {
    # Primary node group for application workloads
    general = {
      name            = "orderit-ng-general"
      use_name_prefix = true
      description     = "General purpose node group for Orderit"

      # Scaling
      min_size     = 2
      max_size     = 4
      desired_size = 2

      # Instance configuration
      instance_types = ["t3.medium"]  # 2 vCPU, 4 GB RAM
      capacity_type  = "ON_DEMAND"

      # Storage
      disk_size = 50
      disk_type = "gp3"
      disk_iops = 3000
      disk_throughput = 125

      # IAM
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      # Labels
      labels = {
        Environment = "prod"
        Workload    = "general"
      }

      # Tags
      tags = {
        Name = "orderit-ng-general"
      }
    }

    # Optional: Spot instance group for cost savings (non-critical workloads)
    # (uncommment below for additional savings on static workloads)
    /*
    spot = {
      name            = "orderit-ng-spot"
      use_name_prefix = true
      min_size        = 0
      max_size        = 2
      desired_size    = 1
      instance_types  = ["t3.medium", "t3a.medium"]  # Multiple types for flexibility
      capacity_type   = "SPOT"
      
      labels = {
        Environment = "prod"
        Workload    = "spot"
      }
    }
    */
  }

  # Cluster addons (auto-upgrade)
  cluster_addons = {
    coredns = {
      preserve = true
      most_recent = true
    }
    kube-proxy = {
      preserve = true
      most_recent = true
    }
    vpc-cni = {
      preserve = true
      most_recent = true
      configuration_values = jsonencode({
        env = {
          WARM_IP_TARGET = "1"
        }
      })
    }
  }

  # Tags
  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_managed_node_groups" {
  value = module.eks.eks_managed_node_groups
}
```

**Cost:** ~$0.10/hour for cluster (master) + nodes (see node instances above)

---

### 3. IAM Roles & Service Accounts (IRSA)

**Purpose:** Create IAM roles that K8s service accounts can assume for accessing AWS services (Secrets Manager, CloudWatch, ECR, etc.).

```hcl
module "irsa_external_secrets" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "orderit-external-secrets-"

  attach_secrets_manager_policy = true
  attach_ssm_managed_policy = true

  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:orderit/*"
  ]

  ssm_parameter_arns = [
    "arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter/orderit/*"
  ]

  # Link to OIDC provider for EKS
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-secrets", "orderit-prod:external-secrets"]
    }
  }

  tags = {
    Name = "orderit-external-secrets"
  }
}

# Second role for Orderit app
module "irsa_orderit_app" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "orderit-app-"

  # ECR pull permissions
  attach_ecr_read_only_policy = true

  # CloudWatch logs
  attach_cloudwatch_logs_policy = true

  # Custom policy for Secrets Manager
  attach_policy_statements = true
  policy_statements = {
    GetSecrets = {
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = [
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:orderit/*"
      ]
    }
  }

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

output "irsa_external_secrets_role_arn" {
  value = module.irsa_external_secrets.iam_role_arn
}

output "irsa_orderit_app_role_arn" {
  value = module.irsa_orderit_app.iam_role_arn
}
```

**Cost:** Free (IAM roles have no direct cost)

---

### 4. ECR Repositories

**Purpose:** Create private ECR repos for backend & frontend Docker images.

```hcl
module "ecr_backend" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"

  repository_name           = "orderit-backend"
  repository_type           = "private"
  image_tag_mutability      = "MUTABLE"
  image_scan_on_push        = true
  repository_encryption_type = "AES256"

  # Lifecycle policy: keep last 10 images, delete untagged after 7 days
  create_repository_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus     = "untagged"
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus       = "tagged"
          tagPrefixList   = ["v", "release"]
          countType       = "imageCountMoreThan"
          countNumber     = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  # Access logging (optional)
  attach_repository_policy = true
  repository_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowPush"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })

  tags = {
    Name = "orderit-backend"
  }
}

module "ecr_frontend" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"

  repository_name      = "orderit-frontend"
  repository_type      = "private"
  image_scan_on_push   = true

  create_repository_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus     = "untagged"
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Name = "orderit-frontend"
  }
}

output "ecr_backend_repository_url" {
  value = module.ecr_backend.repository_url
}

output "ecr_frontend_repository_url" {
  value = module.ecr_frontend.repository_url
}
```

**Cost:** ~$0.06/month per repository (scanning not charged if no images)

---

### 5. ACM Certificate

**Purpose:** Create public TLS certificate for the domain, validate via Route53.

```hcl
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = "orderit.example.com"
  zone_id     = aws_route53_zone.main.zone_id

  # Request additional SANs if needed
  subject_alternative_names = [
    "www.orderit.example.com",
    "api.orderit.example.com"
  ]

  # Auto-validate using Route53 DNS
  validation_method = "DNS"
  create_route53_records = true

  # Allow overwrite for renewal
  wait_for_validation = true

  tags = {
    Name = "orderit-cert"
  }
}

output "acm_certificate_arn" {
  value = module.acm.acm_certificate_arn
}

output "acm_certificate_domain_validation_options" {
  value = module.acm.acm_certificate_domain_validation_options
}
```

**Cost:** Free (AWS managed cert)

---

### 6. Security Group (ALB)

**Purpose:** Security group for Application Load Balancer.

```hcl
module "alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "orderit-alb-sg"
  description = "Security group for Orderit ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]  # Public

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "orderit-alb-sg"
  }
}

output "alb_security_group_id" {
  value = module.alb_security_group.security_group_id
}
```

**Cost:** Free (security groups have no cost)

---

### 7. EKS Blueprints Addons (ALB Controller, Metrics Server, etc.)

**Purpose:** Install and configure essential EKS addons (ALB Ingress Controller, Metrics Server for HPA, External Secrets, Cluster Autoscaler).

```hcl
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # AWS Load Balancer Controller (for ALB/NLB ingress)
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version       = "2.6.0"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }

  # Metrics Server (required for HPA)
  enable_metrics_server = true
  metrics_server = {
    chart_version = "3.11.0"
  }

  # Cluster Autoscaler (auto-scale node groups)
  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    chart_version = "9.29.0"
  }

  # External Secrets Operator (for AWS Secrets Manager integration)
  enable_external_secrets = true
  external_secrets = {
    chart_version = "0.9.0"
  }

  # CoreDNS (already installed, but can be managed here)
  # enable_coredns = true

  # Optional addons (uncomment as needed)
  # enable_karpenter = true  # Advanced autoscaling (Karpenter)
  # enable_ebs_csi_driver = true  # For EBS volumes
  # enable_efs_csi_driver = true  # For EFS volumes

  tags = {
    Name = "orderit-addons"
  }
}

# ECR token for pulling public images
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

# Alias provider for ECR public
provider "aws" {
  alias  = "ecr"
  region = "us-east-1"
}
```

**Cost:** Free (addons are bundled with EKS)

---

## Terraform Configuration Structure

### Directory Layout

```
infra/
├── terraform/
│   ├── main.tf               # Provider, backend, locals
│   ├── vpc.tf                # VPC module
│   ├── eks.tf                # EKS module
│   ├── iam.tf                # IAM roles (IRSA)
│   ├── ecr.tf                # ECR repos
│   ├── acm.tf                # ACM cert
│   ├── security-groups.tf    # Security groups
│   ├── addons.tf             # EKS Blueprints addons
│   ├── outputs.tf            # Outputs (cluster name, ECR URIs, etc.)
│   ├── variables.tf          # Input variables
│   ├── locals.tf             # Local values
│   ├── route53.tf            # Route53 zone & records (optional)
│   ├── terraform.tfvars      # Variable values
│   └── terraform.tfvars.example  # Example values
└── k8s/                      # Kubernetes manifests (ConfigMap, Deployments, etc.)
    ├── configmap.yaml
    ├── backend-deployment.yaml
    ├── frontend-deployment.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    └── secretstore.yaml
```

### main.tf

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }

  # Uncomment below for remote state (S3 + DynamoDB)
  # backend "s3" {
  #   bucket         = "orderit-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "orderit"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_caller_identity" "current" {}
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
```

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "domain_name" {
  description = "Domain name for the app"
  type        = string
  default     = "orderit.example.com"
}
```

---

## Deployment Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan (dry-run)
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Output cluster info
terraform output cluster_name
terraform output ecr_backend_repository_url
terraform output cluster_endpoint

# Destroy (careful!)
terraform destroy
```

---

## Cost Estimate (Monthly)

| Resource | Cost | Notes |
|----------|------|-------|
| EKS Cluster | $73 | Master plane (fixed) |
| EC2 Nodes (2 × t3.medium) | $30 | 2 x $15/month |
| NAT Gateways (2) | $32 | $16/month each (HA) |
| ALB | $16 | Hourly charge ($0.0225/hour) |
| NAT Data Transfer | $5-15 | Outbound traffic to Atlas, Stripe, etc. |
| CloudWatch Logs | $5-15 | EKS logs (7-day retention) |
| ECR | <$1 | 2 repos, minimal images |
| **Total (baseline)** | **$150-180** | Scales with traffic + node scaling |

**Optimizations:**
- Use Spot instances (50% savings) for non-critical workloads
- Reserved Instances (1-3 year): 30-70% discount on compute
- Consolidate to 1 NAT gateway (saves ~$16/month, reduces HA)

---

## Post-Deployment

1. **Validate cluster:**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. **Deploy app:**
   ```bash
   # Update image URIs and secrets in k8s manifests
   kubectl apply -f k8s/
   ```

3. **Monitor:**
   - CloudWatch Container Insights dashboard
   - CloudWatch Alarms (pod restarts, CPU, memory)
   - ALB target health

4. **Backup & DR:**
   - MongoDB Atlas: Enable automated backups (defaults to 7-day retention)
   - EKS: No state to backup (stateless app + external DB)
   - Terraform state: Use S3 backend with versioning + MFA delete

---

## References

- **terraform-aws-modules:** https://registry.terraform.io/namespaces/terraform-aws-modules
- **aws-ia/eks-blueprints:** https://github.com/aws-ia/terraform-aws-eks-blueprints
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest
- **EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/
