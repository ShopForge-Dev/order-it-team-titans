# Orderit — Project Context

**Audience:** engineers joining this repo, and AI coding agents working in it.
**Last verified:** 2026-08-15. Every claim below was checked against the working tree
on that date; anything unverified is labelled.

---

## 1. What this is

Orderit is a MERN food-delivery application (React frontend, Express/Node backend,
MongoDB) being taken from "runs on a laptop" to "runs on managed Kubernetes with
CI/CD, monitoring and security controls". That programme is tracked internally as
**ZIDD 2.0**, a five-task DevOps exercise: containerize, deploy, observe, secure,
automate.

Two things make this repo unusual, and you should know both before touching it:

1. **Most of the backend is obfuscated.** It was shipped through
   `javascript-obfuscator`. 31 of 34 backend source files are still machine-generated
   gibberish. See §5.
2. **The budget is $0.** Not "cheap" — zero. Every infrastructure choice is
   constrained by free-tier limits. See §7.

---

## 2. Fast start

```bash
# Backend — http://localhost:4000
cd app/backend
npm install --legacy-peer-deps
NODE_ENV=DEVELOPMENT node server.js

# Frontend — http://localhost:3000, proxies /api to :4000
cd app/frontend
npm install --legacy-peer-deps
npm start
```

`--legacy-peer-deps` is required, not optional: the dependency tree does not resolve
under modern npm's strict peer rules.

Backend config comes from `app/backend/config/config.env` (gitignored). Copy
`config.env.example` and fill in MongoDB Atlas, Stripe test keys, and Mailtrap.

Health endpoints, used by the Kubernetes probes:

| Endpoint | Purpose | Success |
|---|---|---|
| `GET /health` | Liveness — process is up | `200` always |
| `GET /ready` | Readiness — Mongoose `readyState === 1` | `200`, else `503` |
| `GET /metrics` | Prometheus text exposition | `200` |

---

## 3. Repo map

```
app/
├── backend/           Express API, port 4000
│   ├── app.js         Route mounting, middleware, health endpoints   [readable]
│   ├── server.js      Startup, crash handlers                        [readable]
│   ├── config/        database.js                                    [readable]
│   ├── controllers/   8 files                                        [OBFUSCATED]
│   ├── models/        7 Mongoose schemas                             [OBFUSCATED]
│   ├── routes/        9 route modules                                [OBFUSCATED]
│   ├── middlewares/   2 files                                        [OBFUSCATED]
│   └── utils/         5 files (imgbbUpload.js readable, rest not)
├── frontend/          React 18 + Redux, CRA, port 3000
├── k8s/               Kustomize: base/ + overlays/{dev,prod}
├── docs/              Architecture and infra design docs
└── docker-compose.yml Local 3-service stack

terraform/             OCI infrastructure — see terraform/README.md
graphify-out/          Generated code graph (graph.html is browsable)
```

### Document index

| File | Read it when |
|---|---|
| `ONBOARDING.md` | You are here. Start point. |
| `app/docs/ARCHITECTURE.md` | Understanding app internals, schemas, API surface |
| `app/docs/ZERO_COST_INFRA.md` | Deploying. This is the operative deployment guide. |
| `terraform/README.md` | Provisioning OCI infra; cost guardrails; SOP deviations |
| `app/k8s/K8S_DEPLOYMENT.md` | Applying manifests to a cluster |
| `DE_OBFUSCATION_STATUS.md` | Working on the obfuscation problem |
| `OCI_SETUP.md` | OCI credential layout |
| `app/docs/INFRA_DESIGN.md`, `TERRAFORM_MODULES.md` | **Reference only — AWS/EKS. Do not implement.** |

---

## 4. Current state

Verified against the tree on 2026-08-15.

| Area | State | Detail |
|---|---|---|
| Backend runtime | Working | Starts on :4000, connects to MongoDB Atlas; ImgBB image uploads wired |
| Frontend build | Working | `npm run build` succeeds; all TypeErrors fixed |
| Health endpoints | Done | `/health`, `/ready`, `/metrics` in `app.js` |
| Image uploads | Migrated | Cloudinary → ImgBB (free tier, no limits) |
| Seed script | Ready | `node seeds/seedDatabase.js` populates DB with sample restaurants + ImgBB images |
| Dockerfiles | Present, **not hardened** | Both run as root; see §6 |
| docker-compose | Present | backend + frontend + mongo, healthchecks wired |
| K8s manifests | Complete, **not applied** | Deployments, HPA, NetworkPolicy, RBAC, Ingress + cert-manager |
| Terraform (OCI) | Written, **not applied** | Dev config is $0-cost (no NAT gateway); `validate` not yet run — see §6 |
| OCI credentials | Active | `~/.oci/`, region `ap-mumbai-1`, keys `chmod 600` |
| CI/CD | **Not started** | A stub `Jenkinsfile` exists; no GitHub Actions workflow |
| Monitoring | **Not started** | `/metrics` is exposed; no Prometheus/Grafana deployed |
| De-obfuscation | **3 of 34 files** | §5 |

**Nothing is deployed to any cloud yet.** The cluster does not exist; Terraform has
never been applied.

---

## 5. The obfuscation problem

`app.js`, `server.js` and `config/database.js` were hand-reconstructed and are now
readable. Their originals are preserved as `*.obfuscated` next to them.

Everything else still looks like this:

```javascript
cloudinary = require(_0x43429f(0x9c))["v2"],
_0x45e6bc = await cloudinary[_0x346f0a(0x9f)]["upload"](
```

List the remaining files:

```bash
grep -rl "_0x[0-9a-f]\{4,\}" app/backend/{controllers,models,routes,utils,middlewares}
```

**Do not assume the three completed files predict the effort.** Those were pure
wiring — the obfuscator's string array decoded straight to module paths and config
keys, making substitution mechanical. The controllers contain real business logic
(auth flows, Stripe payment handling, Mongo aggregation). Recovering those means
reconstructing intent, not substituting strings.

**Why this blocks ZIDD 2.0 Task 4 (Security):** SAST, dependency-risk analysis and
code review all see nothing meaningful in 91% of the backend. A security sign-off on
this codebase today would be theatre.

---

## 6. Known issues

Ranked by how much they will hurt. Evidence given so you can confirm rather than trust.

### High

**Containers run as root.** Neither Dockerfile has a `USER` directive
(`grep -c "^USER" app/backend/Dockerfile app/frontend/Dockerfile` → `0`, `0`). The
governing SOP requires non-root plus `dumb-init` for PID-1 signal handling, so
SIGTERM currently does not reach Node and pods will not drain gracefully on rollout.

**Frontend Docker build is likely broken — UNVERIFIED.** `app/frontend/.dockerignore`
excludes `src` and `public`, but the builder stage runs `COPY . .` then
`npm run build`. Those sources should therefore never reach the build context. I could
not confirm this: the Docker daemon was not running. **Verify before trusting any
frontend image:** `docker build -t t app/frontend`. If it fails, drop `src` and
`public` from `.dockerignore`.

**~9,300 `node_modules` files are committed to git** (`git ls-files | grep -c
node_modules/`). This bloats clones, poisons diffs, and defeats dependency scanning.
Needs `git rm -r --cached` plus a history decision.

### Medium

**Prod replica counts exceed cluster capacity.** `app/k8s/overlays/prod` sets backend
and frontend to 3 replicas each with HPA `maxReplicas` of 20 and 10. The planned OCI
cluster is 2 nodes × 2 OCPU / 12 GB — the entire Always-Free ARM allowance. Those
ceilings are unreachable; HPA will sit pinned at max-unschedulable under load.

**Image references are placeholders.** Both overlays point at
`ghcr.io/GITHUB_USER/orderit-{backend,frontend}`. `GITHUB_USER` is literal and must be
replaced before any deploy.

**Image storage migrated to ImgBB.** Replaced Cloudinary with free ImgBB API (no rate
limits, no signup required for basic use). `app/backend/utils/imgbbUpload.js` handles
uploads. Add `IMGBB_API_KEY` to `config.env` from [imgbb.com](https://imgbb.com/). Seed
script `app/backend/seeds/seedDatabase.js` ready to populate with sample restaurant images.

**Terraform ready to validate.** Dev config is sound and $0-cost-compliant. Before
applying: `cd terraform && terraform init && terraform validate`. OCI credentials
must be in `~/.oci/` (already active). Run `terraform plan -var-file=env/dev.tfvars`
to preview changes; this does NOT provision anything.

### Low

Leftover artefacts: `app/backend/app.js.deobf`, `*.obfuscated` files. Keep the
`.obfuscated` originals until de-obfuscation is finished; `.deobf` is a scratch file
and can go.

---

## 7. Constraints

### $0 budget — non-negotiable

The full policy is in `.claude/CLAUDE.md`. In brief:

**Allowed:** Oracle Cloud Always-Free, K3s/OKE, MongoDB Atlas M0, GitHub Container
Registry, GitHub Actions, Let's Encrypt, DuckDNS, Prometheus/Grafana self-hosted.

**Forbidden:** AWS EKS/RDS/ALB, paid domains, paid monitoring SaaS, Docker Hub private
repos, Terraform Cloud.

On hitting a free-tier limit: **do not upgrade.** Analyse, optimise, then bring options
with costs to the team.

The one place this bites in the current Terraform: an OCI NAT gateway is *not*
Always-Free (hourly + per-GB). `terraform/main.tf` carries a `check` block that fails
the plan if a NAT is enabled outside prod, and another that fails if the node pool
exceeds 4 OCPU / 24 GB. Dev environment (`terraform/env/dev.tfvars`) is already
configured for $0: `enable_nat_gateway = false`, `workers_in_public_subnet = true`.
Workers in public subnet is acceptable for learning, not for real data.

Image uploads use free ImgBB API (not Cloudinary). Get your API key from
[imgbb.com](https://imgbb.com/), add to `config.env`, then run `node seeds/seedDatabase.js`.

### Target architecture

```
Internet
   │
   ▼
DuckDNS (orderit.duckdns.org)
   │
   ▼
OCI Load Balancer  ← created by ingress-nginx, pinned to the 10 Mbps free flexible shape
   │
   ▼
ingress-nginx  ─ TLS via cert-manager / Let's Encrypt
   │
   ├── /api, /health, /ready ──▶ backend  Service :4000  (HPA)
   └── /                     ──▶ frontend Service :80    (HPA)
                                    │
                                    ▼
                          MongoDB Atlas M0 (outside OCI)
```

Terraform provisions the substrate only: compartment + IAM, VCN, OKE cluster, node
pool, Object Storage. The load balancer, certificates and MongoDB are deliberately
*not* Terraform-managed — see `terraform/README.md` §"What this does NOT provision".

---

## 8. Decisions on record

| Decision | Rationale |
|---|---|
| OCI over AWS | AWS EKS is $73/month for the control plane alone. OCI Always-Free covers the whole footprint. |
| Region `ap-mumbai-1` | Matches the existing tenancy in `~/.oci/config`. The design doc said `us-ashburn-1`. |
| MongoDB Atlas M0, not OCI Autonomous DB | Autonomous DB is PostgreSQL; this app is Mongoose/MongoDB end to end. Switching means a data-layer rewrite. |
| GHCR, not OCIR | Already the pipeline target. `container_repositories` is empty so no unused second registry is created. |
| OKE for dev too, not K3s | One provisioning path instead of two. Park it with `node_count = 0` when idle. |
| `ignore_changes` on node count | The nightly scale-to-zero job manages it out-of-band; apply must not fight it. |

### A caveat on the source SOPs

The Technical Design Document names OCI services but contains no CIDRs, shapes, OCPU
counts, ports or IAM policy statements, and its architecture diagram is still the
original AWS one (Route 53, CloudFront, S3, EC2, RDS). It also references
`manage_gke_credits.py` (GCP) alongside `manage_oke_credits.py`, and numbers one SOP
1, 2, 3, 5.

Every concrete value in `terraform/` was therefore **chosen, not transcribed**, and is
tabled in `terraform/README.md`. If someone authoritative owns that document, the
region and the Autonomous-DB-versus-Mongo question are the two worth settling first.

---

## 9. ZIDD 2.0 task status

| # | Task | Status | Next action |
|---|---|---|---|
| 1 | Containerization | Partial | Add non-root `USER` + `dumb-init`; fix frontend `.dockerignore`; verify builds |
| 2 | Deployment | Not started | `terraform init && validate`, apply dev, install ingress-nginx + cert-manager |
| 3 | Observability | Partial | `/metrics` exists; deploy Prometheus + Grafana into a `monitoring` namespace |
| 4 | Security | Blocked | Gated on de-obfuscation (§5). Trivy/Checkov are wired into nothing yet. |
| 5 | CI/CD | Not started | No GitHub Actions workflow exists; the `Jenkinsfile` is a stub |

Suggested order: fix the Task 1 container issues, apply dev infra, then CI/CD —
so de-obfuscation, which is slow and parallelisable, runs alongside rather than
blocking everything.

---

## 10. Open questions for a human

These cannot be resolved from the code and are not mine to decide:

1. **Region** — keep `ap-mumbai-1`, or follow the TDD's `us-ashburn-1`?
2. **Database** — is MongoDB Atlas M0 accepted, or is OCI Autonomous DB a hard
   requirement? The latter is a data-layer rewrite.
3. **Obfuscation** — does the original unobfuscated source exist anywhere (another
   branch, the original author, a backup)? Recovering it would save days over
   reconstruction.
4. **Committed `node_modules`** — rewrite history, or just remove going forward?
5. **Image host** — Cloudinary or ImgBB? Both are currently half-wired.

---

## Notes for AI agents

- Read `.claude/CLAUDE.md` first. The $0 policy overrides default recommendations, and
  suggesting AWS services is an explicit failure mode here.
- `app/docs/INFRA_DESIGN.md` and `TERRAFORM_MODULES.md` describe an **AWS/EKS** design
  that is archived and must not be implemented. `ZERO_COST_INFRA.md` is the live guide.
- Assume backend files are obfuscated unless you have checked. Grepping for a function
  name will silently miss the 31 obfuscated files.
- `graphify-out/graph.json` holds a pre-built code graph (534 nodes, 793 edges) — query
  it before re-scanning the tree.
- The state table in §4 is dated. Re-verify before relying on it; the commands to do so
  are given inline throughout.
