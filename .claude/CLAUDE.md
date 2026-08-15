# Orderit Project - Claude Code Instructions

## 🚀 Project Overview

**App:** Orderit Food Delivery (MERN Stack)  
**Status:** Development, local testing complete  
**Deployment Target:** $0 cost infrastructure (free tier services only)

---

## 💰 CRITICAL: $0 Cost Policy (NON-NEGOTIABLE)

**This project is budget-$0. ALL infrastructure & service decisions MUST follow this policy.**

### ✅ ALLOWED

- **Compute:** Oracle Cloud free tier (always free), local development (laptop)
- **Kubernetes:** K3s (open-source, lightweight)
- **Database:** MongoDB Atlas M0 (512 MB, free forever)
- **Images:** Cloudinary free tier (10 GB/month)
- **Email:** Mailtrap free (50/month)
- **Payments:** Stripe test mode ($0)
- **Registry:** GitHub Container Registry (free)
- **CI/CD:** GitHub Actions (2,000 min/month free)
- **DNS:** DuckDNS (free subdomain, not custom domain)
- **HTTPS:** Let's Encrypt (free, auto-renew)
- **Monitoring:** Prometheus (open-source), K3s logs, free tiers (Uptime Robot, Sentry)
- **Other:** Any open-source tool, anything on free tier with no credit card required

### ❌ FORBIDDEN

- **AWS services:** EKS ($73/month), EC2 beyond free tier, RDS, ALB (>$10/month)
- **GCP:** Beyond free tier (f1-micro after 12 months costs money)
- **Azure:** Any paid service
- **Paid domains:** .com, .io, .dev (costs $10+/year) — use duckdns.org
- **Paid monitoring:** DataDog, New Relic, paid tiers of SaaS
- **Paid storage:** S3 (regional transfer costs money) — use Cloudinary free
- **Paid email:** SendGrid, Mailgun, etc. (until $$ justifies)
- **Terraform Cloud/Enterprise:** Use local state or free GitHub
- **Container registries:** Docker Hub private (use GHCR)

### 🛑 When Hitting Free Tier Limits

**DO NOT automatically upgrade to paid tier. Instead:**
1. Analyze the limit (what's breaking? why?)
2. Optimize before scaling (compress images, archive old data, cache more)
3. If optimization insufficient, **ask the team** before upgrading
4. Provide cost breakdown: monthly cost + revenue/ROI justification
5. Explore free alternatives first

**Example:** "MongoDB 512 MB full. Options: (1) Archive old orders to JSON files [$0, adds complexity], (2) Upgrade to M2 10 GB [$57/month], (3) Switch to PostgreSQL on free VM [$0 but maintenance]"

---

## 📚 Documentation Structure

All docs in `app/docs/`:

| File | Purpose | When to Use |
|------|---------|-----------|
| **README.md** | Quick start, next steps, troubleshooting | Onboarding new people |
| **ARCHITECTURE.md** | Backend/frontend code structure, APIs, schemas | Understanding the app |
| **ZERO_COST_INFRA.md** | $0 deployment on K3s + free services | **THIS IS THE DEPLOYMENT GUIDE** |
| **INFRA_DESIGN.md** | EKS/generic K8s design (archived for reference, not used for $0) | Reference only, do NOT implement |
| **TERRAFORM_MODULES.md** | Terraform modules reference (archived, not used for $0) | Reference only, do NOT implement |

---

## 🔧 Development Workflow

### Local Development
```bash
cd app/backend
npm install --legacy-peer-deps
NODE_ENV=DEVELOPMENT node server.js  # Port 4000

cd app/frontend
npm install --legacy-peer-deps
npm start  # Port 3000, auto-proxies /api to :4000
```

### Testing
- Always test against **real MongoDB Atlas** (not local MongoDB)
- Use **Stripe test keys** (sk_test_..., pk_test_...)
- Use **Cloudinary sandbox** (not production account)
- Use **Mailtrap** for email testing (emails captured, not sent)

### Deployment
- Use **ZERO_COST_INFRA.md** (not INFRA_DESIGN.md or TERRAFORM_MODULES.md)
- Deploy to **K3s on Oracle Cloud free VM** (not EKS)
- Push images to **GitHub Container Registry** (not ECR)
- Use **DuckDNS** for domain (not Route53)
- Use **Let's Encrypt** for HTTPS (not ACM)

---

## ⚠️ Code Quality Issues (MUST FIX)

1. **Code Obfuscation** (CRITICAL)
   - `app.js`, `server.js`, `database.js` are obfuscated
   - Blocks AI tooling, security review, readability
   - **Action:** De-obfuscate using js-beautify before any production push
   - **Reference:** ARCHITECTURE.md > Code Quality Notes

2. **Missing Health Endpoints** (CRITICAL)
   - K8s needs `/health` (liveness) and `/ready` (readiness)
   - **Action:** Add to `server.js`:
     ```javascript
     app.get('/health', (req, res) => res.json({ status: 'ok' }));
     app.get('/ready', (req, res) => {
       if (mongoose.connection.readyState === 1) {
         return res.json({ ready: true });
       }
       res.status(503).json({ ready: false });
     });
     ```

3. **Input Validation** (HIGH)
   - No sanitization on user inputs (XSS, SQL injection risks)
   - **Action:** Use `express-validator` or similar

4. **JWT Storage** (HIGH)
   - Stored in localStorage (XSS vulnerable)
   - **Action:** Switch to httpOnly cookies

5. **CORS Configuration** (MEDIUM)
   - Likely using `*` (too open)
   - **Action:** Restrict to frontend domain only

---

## 🎯 When Making Changes to Infrastructure/Services

**BEFORE you suggest or implement ANY change:**

1. **Ask:** "Does this cost money?"
2. **If yes:** Can it be done free? (open-source alternative? free tier?)
3. **If must be paid:** Provide full cost breakdown (monthly, annual)
4. **If free:** Implement it

**Examples:**

❌ DON'T SAY: "Let's use AWS EKS for production"
✅ DO SAY: "Use K3s on Oracle free VM (saves $73/month vs EKS)"

❌ DON'T SAY: "Deploy to Route53"
✅ DO SAY: "Use DuckDNS free domain + Let's Encrypt (free), or custom domain later when $$ comes in"

❌ DON'T SAY: "Add monitoring with DataDog"
✅ DO SAY: "Use Prometheus stack (open-source) + Grafana Cloud free tier"

---

## 🔐 Security for $0 Setup

- All secrets in K8s Secrets (not hardcoded)
- HTTPS via Let's Encrypt (free, auto-renew)
- Firewall: Only HTTP(S) exposed
- MongoDB: IP whitelist (not 0.0.0.0/0) for prod
- Stripe: Test keys only, no live data
- Image scanning: GHCR built-in (free)
- Backups: MongoDB Atlas auto-backups (free)

---

## 📋 Pre-Deployment Checklist (From ZERO_COST_INFRA.md)

- [ ] Oracle Cloud free account created
- [ ] K3s installed on free VM
- [ ] GitHub Container Registry set up
- [ ] MongoDB Atlas M0 cluster created
- [ ] Cloudinary free account created
- [ ] DuckDNS domain registered
- [ ] GitHub Actions workflow created
- [ ] K8s manifests created (see ZERO_COST_INFRA.md)
- [ ] App deployed & accessible via https://orderit.duckdns.org

---

## 🚫 Things NOT to Do

- ❌ Use AWS EKS, RDS, ALB (costs money)
- ❌ Use paid domains like orderit.com (use DuckDNS)
- ❌ Suggest Terraform Cloud (use free local state + GitHub)
- ❌ Use Docker Hub private repos (use GHCR)
- ❌ Add any paid SaaS without cost justification
- ❌ Store secrets in Git (use K8s Secrets or external-secrets)
- ❌ Use console.log for production logging (use structured logs)
- ❌ Leave obfuscated code (de-obfuscate immediately)

---

## 📞 When You're Unsure

If you're about to suggest infrastructure/tools/services and unsure about cost:
1. Check if there's a free tier
2. Check if there's an open-source alternative
3. If cost is involved, ask first (provide options + cost breakdown)
4. Default to $0 options unless explicitly told otherwise

---

## 🎯 Success Metrics for This Project

- [ ] App running locally ✓ (confirmed)
- [ ] Deployed to $0 infrastructure ✓ (next step)
- [ ] Zero monthly cost ✓ (goal)
- [ ] All code readable & de-obfuscated ✓ (pending)
- [ ] Health checks working ✓ (pending)
- [ ] HTTPS enabled (Let's Encrypt) ✓ (pending)
- [ ] All team members can deploy independently ✓ (pending)
- [ ] Clear runbooks for common operations ✓ (pending)

---

## 📖 References

- **Deployment Guide:** `app/docs/ZERO_COST_INFRA.md` ⭐ **USE THIS**
- **Code Architecture:** `app/docs/ARCHITECTURE.md`
- **K3s Docs:** https://docs.k3s.io/
- **MongoDB Atlas Free:** https://www.mongodb.com/cloud/atlas
- **GitHub Container Registry:** https://docs.github.com/en/packages
- **Let's Encrypt:** https://letsencrypt.org/
- **DuckDNS:** https://www.duckdns.org/

---

**Last Updated:** 2026-08-15  
**Policy Version:** 1.0  
**Status:** ACTIVE - Follow this for ALL Orderit decisions
