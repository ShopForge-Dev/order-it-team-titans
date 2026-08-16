# CI/CD pipeline

Three workflows:

| File | Trigger | Does |
|---|---|---|
| `ci.yml` | PR / push to `main`, `develop` | Installs, tests, builds backend & frontend; builds (doesn't push) both Docker images; `terraform fmt`/`validate`. Uses path filtering so a docs-only or terraform-only PR doesn't run npm jobs. |
| `cd.yml` | push to `develop` → dev, push to `main` → prod (or manual dispatch) | Builds & pushes both images to GHCR, tagged with the commit sha **and** a moving tag (`develop`/`stable`) matching what `app/k8s/base/kustomization.yaml` already expects. Then fetches OKE kubeconfig and applies the matching Kustomize overlay with the sha tag pinned in. |
| `terraform.yml` | PR touching `terraform/**` → plan (both envs); manual dispatch → apply one env | Provisions/updates the OCI infra (compartment, VCN, OKE, storage). |

## One-time setup before these will run

**1. Repository secrets** (Settings → Secrets and variables → Actions):

- `OCI_CLI_USER`, `OCI_CLI_TENANCY`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_REGION` — from your OCI API key.
- `OCI_CLI_KEY_CONTENT` — the full contents of the OCI API private key PEM file.
- `OKE_CLUSTER_ID` — OCID of the OKE cluster (Terraform outputs this as `cluster_id` after the first apply).

GHCR push needs no secret — it uses the built-in `GITHUB_TOKEN` (the workflow already requests `packages: write`).

**2. GitHub Environments** (Settings → Environments): create `development` and `production`. Add required reviewers on `production` if you want manual approval before prod deploys/applies — the workflows are already wired to those environment names.

**3. Terraform remote state**: `terraform/versions.tf` has the OCI Object Storage (S3-compatible) backend commented out, so state is currently local-only. Bootstrap the bucket, uncomment that block, and run `terraform init -migrate-state` locally once — otherwise the `terraform.yml` workflow re-plans from a blank state on every run instead of tracking drift.

**4. Kustomize image placeholders**: `app/k8s/base/kustomization.yaml` and both overlays still say `ghcr.io/GITHUB_USER/...`. Replace `GITHUB_USER` with your actual GitHub username/org (or org name if this repo moves to `ShopForge-Dev`) so it matches `${{ github.repository_owner }}` used in the workflows.

## Flow

```
PR opened          → ci.yml (test + build check, no push)
merge to develop    → cd.yml → push :develop image → deploy to dev overlay
merge to main        → cd.yml → push :stable image  → deploy to prod overlay (needs approval)
terraform/** PR      → terraform.yml plan (dev + prod, posted to job summary)
workflow_dispatch    → terraform.yml apply to chosen env (needs approval on prod)
```
