# Docker Setup Guide - Orderit

Complete guide to containerize and run the Orderit application using Docker and Docker Compose.

---

## 📋 Prerequisites

- Docker installed (v20.10+)
- Docker Compose installed (v2.0+)
- `.env` file with required environment variables (see `.env.docker.example`)

---

## 🚀 Quick Start

### 1. Prepare Environment Variables

Copy and customize the example file:

```bash
cd app
cp .env.docker.example .env.docker
# Edit .env.docker with your actual credentials
nano .env.docker
```

### 2. Build & Start Containers

```bash
cd app
docker-compose up -d
```

Services start:
- **Backend:** http://localhost:4000
- **Frontend:** http://localhost:80
- **MongoDB:** localhost:27017

### 3. Verify Services

```bash
docker-compose ps
docker-compose logs -f backend  # Backend logs
docker-compose logs -f frontend # Frontend logs
docker-compose logs -f mongo    # Database logs
```

### 4. Stop Services

```bash
docker-compose down
# Remove volumes too (cleans DB):
docker-compose down -v
```

---

## 🛠️ Development Workflow

### Rebuild After Code Changes

```bash
# Rebuild specific service
docker-compose build backend
docker-compose up -d backend

# Or rebuild all
docker-compose build
docker-compose up -d
```

### Access Container Shell

```bash
# Backend shell
docker-compose exec backend sh

# Frontend shell (nginx - limited shell)
docker-compose exec frontend sh

# MongoDB shell
docker-compose exec mongo mongosh
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service (last 50 lines, follow new logs)
docker-compose logs -f --tail=50 backend

# Without timestamps
docker-compose logs -f --no-log-prefix backend
```

---

## 🏗️ Architecture

### Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **backend** | node:18-alpine | 4000 | Express API server |
| **frontend** | nginx:1.25-alpine | 80 | React SPA + reverse proxy |
| **mongo** | mongo:6-alpine | 27017 | MongoDB database |

### Network

All services communicate via `orderit-network` bridge network:
- Backend → MongoDB: `mongodb://mongo:27017/orderit`
- Frontend → Backend: `http://backend:4000` (via nginx proxy)

### Volumes

- `mongo-data`: Persists MongoDB data between container restarts

---

## 📁 File Structure

```
app/
├── backend/
│   ├── Dockerfile              # Multi-stage Node.js build
│   ├── .dockerignore           # Excludes node_modules, .env, etc.
│   └── server.js               # Entry point
├── frontend/
│   ├── Dockerfile              # Multi-stage React + nginx
│   ├── .dockerignore
│   ├── nginx.conf              # Reverse proxy config
│   └── package.json
├── docker-compose.yml          # Orchestration config
├── .env.docker.example         # Environment template
└── docs/
    └── DOCKER_SETUP.md         # This file
```

---

## 🔧 Configuration

### Backend Environment Variables

```env
NODE_ENV=development              # production, development
DB_LOCAL_URI=mongodb://mongo:27017/orderit
CLOUDINARY_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
STRIPE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
SMTP_HOST=sandbox.smtp.mailtrap.io
SMTP_PORT=2525
SMTP_PASSWORD=...
SMTP_FROM_EMAIL=...
JWT_SECRET=...
JWT_EXPIRE=7d
COOKIE_EXPIRE=7
```

### Frontend Nginx Config

The frontend `nginx.conf` handles:
- **SPA Routing:** All unknown paths → `/index.html`
- **API Proxy:** `/api/*` → `http://backend:4000`
- **Cache:** Static assets cached for 1 year
- **Health Check:** `GET /health` → 200 OK

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check for port conflicts
docker-compose ps
lsof -i :80    # Port 80
lsof -i :4000  # Port 4000
lsof -i :27017 # Port 27017

# Remove conflicting containers
docker-compose down -v
docker system prune -a
```

### Backend Can't Connect to MongoDB

```bash
# Check MongoDB is running
docker-compose logs mongo

# Test connection
docker-compose exec backend sh
# Inside container:
mongosh mongodb://mongo:27017/orderit

# If fails, restart:
docker-compose restart mongo
```

### Frontend Blank Page / 502 Bad Gateway

```bash
# Check backend is running
docker-compose logs backend

# Check nginx proxy config
docker-compose exec frontend cat /etc/nginx/conf.d/default.conf

# Test backend from frontend container
docker-compose exec frontend wget -O- http://backend:4000/api/v1/restaurants
```

### Permission Denied on `.env.docker`

```bash
chmod 600 .env.docker
```

### Database Lost After `docker-compose down -v`

This is expected — volumes are deleted. If you need to preserve data:

```bash
# Down WITHOUT removing volumes
docker-compose down
# Data persists in mongo-data/
```

---

## 🚢 Pushing to Registry (For K3s Deployment)

Once tested locally, push images for K3s deployment:

```bash
# Log in to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build images with tags
docker-compose build

# Tag images
docker tag app-backend:latest ghcr.io/USERNAME/orderit-backend:v1.0.0
docker tag app-frontend:latest ghcr.io/USERNAME/orderit-frontend:v1.0.0

# Push to registry
docker push ghcr.io/USERNAME/orderit-backend:v1.0.0
docker push ghcr.io/USERNAME/orderit-frontend:v1.0.0
```

Then use these image URLs in K8s manifests (see `ZERO_COST_INFRA.md`).

---

## 📊 Health Checks

Each service has a health check endpoint:

- **Backend:** `GET http://localhost:4000/health` → expects `{ status: 'ok' }`
- **Frontend:** `GET http://localhost/health` → expects HTTP 200
- **MongoDB:** `mongosh ping` → expects `{ ok: 1 }`

Services auto-restart if unhealthy after 3 failed checks (30s timeout).

---

## ⚡ Performance Tips

1. **Use BuildKit for faster builds:**
   ```bash
   DOCKER_BUILDKIT=1 docker-compose build
   ```

2. **Multi-stage builds reduce image size:**
   - Backend: `284 MB` (without node_modules)
   - Frontend: `24 MB` (nginx + static files only)

3. **Cache dependencies:**
   - Dockerfiles copy `package.json` before source code
   - Rebuild code without re-installing deps (cache hit)

4. **Alpine base images:**
   - Smaller, faster, less attack surface
   - Backend: `node:18-alpine` (172 MB)
   - Frontend: `nginx:1.25-alpine` (45 MB)

---

## 🔐 Security Notes

1. **Never commit `.env` or `.env.docker`** — use `.gitignore`
2. **Use environment variable secrets** — not hardcoded in Dockerfile
3. **Non-root user** — add `USER node` in backend Dockerfile for production
4. **Read-only root filesystem** — possible with K3s securityContext
5. **Network policies** — restrict inter-service communication if needed

---

## 📚 Next Steps

- Test locally with `docker-compose up`
- Push images to GitHub Container Registry
- Deploy to K3s cluster (see `ZERO_COST_INFRA.md`)
- Set up CI/CD pipeline for automated builds (GitHub Actions)

---

## 🆘 Support

For issues:
1. Check logs: `docker-compose logs -f`
2. Verify `.env.docker` has all required keys
3. Ensure ports 80, 4000, 27017 are available
4. Read error messages carefully (often very helpful)

---

**Last Updated:** 2026-08-15  
**Docker Version:** 20.10+  
**Docker Compose Version:** 2.0+
