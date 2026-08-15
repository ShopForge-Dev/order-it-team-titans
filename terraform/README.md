# Orderit — OCI Infrastructure (Terraform)

Provisions the OCI substrate that the Kustomize manifests in `app/k8s/` deploy onto:
a compartment with IAM policies, a VCN, an OKE cluster backed by an Always-Free ARM
node pool, and Object Storage.

## Layout

```
terraform/
├── versions.tf          Provider + optional Object Storage remote state
├── providers.tf         Provider config, home-region alias, ADs, naming locals
├── variables.tf         All inputs
├── main.tf              Module wiring + cost guardrails
├── outputs.tf           Cluster IDs, kubeconfig and scaling commands
├── env/
│   ├── dev.tfvars       $0 footprint: public workers, no NAT, 1 node
│   └── prod.tfvars      Private workers behind NAT, 2 nodes
└── modules/
    ├── iam/             Compartment, dynamic group, node + OKE service policies
    ├── network/         VCN, IGW/NAT/SGW, route tables, security lists, subnets
    ├── oke/             Cluster, node pool, image + version resolution
    └── storage/         Object Storage buckets, optional OCIR repos
```

## Prerequisites

- Terraform >= 1.5
- An OCI API signing key at `~/.oci/` (already configured — see `../OCI_SETUP.md`)
- The `oci` CLI, for generating the kubeconfig after apply

Authentication comes from `TF_VAR_*` environment variables, which are exported in
`~/.zshrc`:

```bash
TF_VAR_tenancy_ocid      TF_VAR_user_ocid       TF_VAR_fingerprint
TF_VAR_private_key_path  TF_VAR_region
```

Confirm they are present before planning:

```bash
env | grep TF_VAR_ | sed 's/=.*/=<set>/'
```

## Usage

```bash
cd terraform
terraform init

# dev
terraform plan  -var-file=env/dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan

# prod
terraform plan  -var-file=env/prod.tfvars -out=prod.tfplan
terraform apply prod.tfplan
```

State is local by default. Each environment builds a separate compartment, VCN and
cluster, so keep them in separate workspaces to avoid one clobbering the other:

```bash
terraform workspace new dev && terraform workspace select dev
```

### Connect to the cluster

```bash
eval "$(terraform output -raw kubeconfig_command)"
kubectl get nodes
```

### Deploy the application

The cluster is empty on creation. `app/k8s/` supplies the workloads:

```bash
kubectl apply -k app/k8s/overlays/dev
```

ingress-nginx and cert-manager must be installed first — neither is managed here.

## What this does NOT provision, and why

| Component | Owner | Reason |
|---|---|---|
| Load balancer | ingress-nginx | Created as a `Service` of type `LoadBalancer`. Terraform only supplies `lb_subnet_id`. |
| TLS certificates | cert-manager | Issued from Let's Encrypt via the `ClusterIssuer` in `app/k8s/base/ingress.yaml`. |
| MongoDB | MongoDB Atlas M0 | Free tier, outside OCI. The backend reads `DB_LOCAL_URI`. |
| DNS | DuckDNS | Free subdomain (`orderit.duckdns.org`); no OCI DNS zone required. |
| Container images | GHCR | Per the design doc. `container_repositories` is empty so no unused OCIR repos are created. |

### Keeping the load balancer Always-Free

OCI's Always-Free allowance covers one **10 Mbps flexible** load balancer. The
default OKE-provisioned LB is larger and bills against credits. Pin the shape on the
ingress-nginx Service:

```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"
```

## Cost

Everything below is inside Always-Free **except** the NAT gateway.

| Resource | Always-Free allowance | This stack (prod) |
|---|---|---|
| OKE control plane | Free for `BASIC_CLUSTER` | 1 cluster |
| A1.Flex compute | 4 OCPU / 24 GB total | 2 x (2 OCPU / 12 GB) — fully consumed |
| Block storage | 200 GB | 2 x 50 GB boot |
| Object Storage | 20 GB | 2 buckets |
| Load balancer | 1 x 10 Mbps flexible | 1, created by ingress-nginx |
| **NAT gateway** | **none — billed hourly + per GB** | 1 in prod, 0 in dev |

`main.tf` carries two `check` blocks that fail the plan if the node pool exceeds the
A1 allowance, or if a NAT gateway is enabled outside prod.

To reach a true $0 in prod, set `workers_in_public_subnet = true` and
`enable_nat_gateway = false`. This puts worker nodes on public IPs — acceptable for
a learning cluster, not for anything holding real data.

### Preserving trial credits

The design doc calls for parking the cluster overnight. `node_count` is under
`ignore_changes`, so scaling out-of-band will not be reverted by the next apply:

```bash
terraform output -raw scale_to_zero_command   # 22:00 UTC
terraform output -raw scale_up_command        # 08:00 UTC
```

## Deviations from the Technical Design Document

The TDD specifies OCI services by name but contains no CIDRs, shapes, OCPU counts,
ports or IAM policy statements, and its architecture diagram is still the original
AWS one (Route 53 / CloudFront / S3 / EC2 / RDS). Every concrete value here was
chosen, not transcribed. The notable calls:

| Item | TDD | Here | Why |
|---|---|---|---|
| Region | `us-ashburn-1` | `ap-mumbai-1` | Matches the tenancy in `~/.oci/config`. Override with `-var region=...`. |
| Database | OCI Autonomous Database (PostgreSQL) | MongoDB Atlas M0 | The app is Mongoose/MongoDB. Autonomous DB is PostgreSQL and would require a full data-layer rewrite. |
| Dev/staging | K3s on ARM compute | OKE, 1 node | One provisioning path instead of two. Set `node_count = 0` when idle. |
| CDN | OCI Content Delivery | none | The frontend is served by the in-cluster nginx container. |
| Registry | GHCR | GHCR | Unchanged. |

The TDD also references `manage_gke_credits.py` (GCP) alongside `manage_oke_credits.py`,
numbers SOP-INFRA-001 as 1,2,3,5, and assigns SSL termination to both the API gateway
and the ingress. Those were not resolved before writing this; the ingress terminates TLS here.

## Known constraints

- **A1 capacity.** Always-Free Ampere capacity is allocated per availability domain and
  is frequently exhausted. The node pool declares a placement config in every AD in the
  region to maximise the chance of a launch. An `Out of host capacity` error means retry
  later or change region — it is not a configuration fault.
- **Compartment creation** needs tenancy-level `manage compartments`. Without it, set
  `create_compartment = false` and pass `existing_compartment_ocid`.
- **API endpoint** defaults to public with `api_allowed_cidrs = ["0.0.0.0/0"]` so a fresh
  clone works. Narrow it to your egress IP (`curl -s ifconfig.me`) before real use.
