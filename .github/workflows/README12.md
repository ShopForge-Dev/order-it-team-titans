# CI/CD Pipeline

## Workflows Overview

| File | Trigger | Purpose |
|------|---------|---------|
| `ci-check.yml` | PR, push to `main`/`develop` | Code quality gate: lint (FE), syntax check (BE), obfuscation detection, terraform fmt |
| `ci-app.yml` | Push to `main`/`develop`, manual | Build Docker images → Trivy scan (FAIL on CRITICAL/HIGH) → Push to GHCR (sha + moving tags) → Generate SBOM |
| `cd-deploy.yml` | Push `develop` → staging, Push `main` → prod (with approval), manual | Terraform apply → Deploy to K8s (staging: K3s VM via SSH, prod: OKE via OCI CLI) |
| `cd-monitoring.yml` | Manual (workflow_dispatch) | Deploy monitoring: staging (self-hosted Prometheus+Grafana on K3s), prod (OCI Native Monitoring + Grafana on OKE) |
| `action.yml` | Composite action | Reusable deploy action supporting both staging (SSH) and production (OCI CLI) paths |
| `terraform.yml` | PR touching `terraform/**` | Terraform plan (both envs); manual apply |

## Branch Strategy

| Branch | Protection | Deploys To |
|--------|------------|------------|
| `develop` | Direct push allowed | **Staging** (Oracle VM + K3s) |
| `main` | PR required from `develop`, reviewers required | **Production** (OCI OKE) |

## Environments

| Environment | Cluster | Monitoring |
|-------------|---------|------------|
| Staging | Oracle Always Free VM (4 ARM, 24GB) + K3s | Self-hosted Prometheus + Grafana on K3s |
| Production | OCI OKE (Always Free: 2 nodes × 2 OCPU/12GB) | OCI Native Monitoring + Self-hosted Grafana on OKE |

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `OCI_CLI_USER` | OCI API user OCID |
| `OCI_CLI_TENANCY` | OCI Tenancy OCID |
| `OCI_CLI_FINGERPRINT` | API key fingerprint |
| `OCI_CLI_REGION` | OCI region (e.g., `ap-mumbai-1`) |
| `OCI_CLI_KEY_CONTENT` | Full PEM private key content |
| `OKE_CLUSTER_ID` | OKE cluster OCID (from Terraform output) |
| `STAGING_VM_IP` | Staging VM public IP (from Terraform output) |
| `STAGING_SSH_KEY` | SSH private key for staging VM access |
| `DUCKDNS_TOKEN` | DuckDNS token for staging domain |
| `GRAFANA_ADMIN_USER` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password |

## Deployment Flow

```
Push to develop → ci-check → ci-app → terraform-apply (staging) → deploy-staging (K3s via SSH)
                                                      ↓
Create PR develop → main → ci-check → ci-app → terraform-apply (prod) → deploy-production (OKE, needs approval)
```

## Local Testing

```bash
# Run CI checks locally
cd app/backend && npm run lint
cd app/frontend && npm run lint

# Build Docker images
docker build -t orderit-backend app/backend
docker build -t orderit-frontend app/frontend

# Test Terraform
cd terraform && terraform fmt -check -recursive && terraform validate
```

## Free Tier Compliance

All workflows use only free tier services:
- GitHub Actions: 2,000 min/month free
- GHCR: 500 MB free storage
- OCI: Always Free tier (OKE, VM, Object Storage, Monitoring)
- Trivy: Open source scanner
- K3s: Lightweight Kubernetes (open source)