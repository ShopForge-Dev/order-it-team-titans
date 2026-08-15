# Health Endpoints - Orderit K8s

Complete guide to health check endpoints and how they're exposed through the Kubernetes stack.

---

## 📊 Health Endpoints Overview

Backend exposes 3 critical health endpoints required by Kubernetes:

| Endpoint | Port | Purpose | HTTP Status |
|----------|------|---------|------------|
| `/health` | 4000 | Pod alive? | 200 (healthy), 500 (error) |
| `/ready` | 4000 | Ready for traffic? | 200 (ready), 503 (not ready) |
| `/metrics` | 9090 | Prometheus metrics | 200 (text/plain) |

---

## 🔧 Backend Implementation Required

Add these endpoints to `app/backend/server.js`:

```javascript
const mongoose = require('mongoose');
const express = require('express');

const app = express();

// ==================
// Health Check Endpoints
// ==================

/**
 * Liveness Probe: Is the pod still running?
 * K8s restarts pod if this fails 3+ times
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'orderit-backend',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

/**
 * Readiness Probe: Is the pod ready for traffic?
 * K8s removes pod from load balancer if this fails
 * Checks: DB connection, external dependencies
 */
app.get('/ready', (req, res) => {
  const checks = {
    database: mongoose.connection.readyState === 1, // 1 = Connected
    // Add more checks here if needed:
    // redis: redisClient.connected,
    // cache: cacheReady,
  };

  const isReady = Object.values(checks).every(check => check === true);

  if (isReady) {
    return res.status(200).json({
      ready: true,
      checks: checks,
      timestamp: new Date().toISOString()
    });
  }

  res.status(503).json({
    ready: false,
    checks: checks,
    timestamp: new Date().toISOString()
  });
});

/**
 * Metrics: Prometheus-format metrics
 * Consumed by: Prometheus, Grafana, HPA
 * Format: text/plain
 */
app.get('/metrics', (req, res) => {
  // Using prom-client library (optional)
  // For now, return basic metrics
  res.type('text/plain');
  res.send(`
# HELP app_requests_total Total number of requests
# TYPE app_requests_total counter
app_requests_total{method="GET",status="200"} 1234
app_requests_total{method="POST",status="200"} 567

# HELP app_errors_total Total number of errors
# TYPE app_errors_total counter
app_errors_total{status="500"} 2
app_errors_total{status="503"} 0

# HELP app_response_time_seconds Response time in seconds
# TYPE app_response_time_seconds histogram
app_response_time_seconds_bucket{le="0.1"} 100
app_response_time_seconds_bucket{le="0.5"} 500
app_response_time_seconds_bucket{le="1.0"} 800
app_response_time_seconds_sum 500
app_response_time_seconds_count 1000

# HELP nodejs_memory_usage_bytes Memory usage in bytes
# TYPE nodejs_memory_usage_bytes gauge
nodejs_memory_usage_bytes{type="external"} ${process.memoryUsage().external}
nodejs_memory_usage_bytes{type="heapUsed"} ${process.memoryUsage().heapUsed}
nodejs_memory_usage_bytes{type="heapTotal"} ${process.memoryUsage().heapTotal}

# HELP process_uptime_seconds Process uptime in seconds
# TYPE process_uptime_seconds gauge
process_uptime_seconds ${process.uptime()}
  `);
});

// ==================
// Other routes
// ==================

// ... rest of your app routes ...

module.exports = app;
```

---

## 🔌 How Health Endpoints Are Exposed in K8s

### 1. Backend Service Exposes Ports

**File:** `k8s/base/backend-service.yaml`

```yaml
spec:
  ports:
    - name: http
      port: 4000        # Service port (inside cluster)
      targetPort: http  # Pod port
      protocol: TCP
    - name: metrics
      port: 9090        # Prometheus scrape port
      targetPort: metrics
      protocol: TCP
```

**Access:**

- **From within cluster:** `http://backend:4000/health`
- **From frontend pod:** `http://backend:4000/ready`
- **From Prometheus:** `http://backend:9090/metrics`

### 2. Kubernetes Probes (Automatic Checks)

**File:** `k8s/base/backend-deployment.yaml`

```yaml
spec:
  containers:
    - name: backend
      ports:
        - name: http
          containerPort: 4000
        - name: metrics
          containerPort: 9090

      # Liveness: Pod alive?
      livenessProbe:
        httpGet:
          path: /health
          port: http
          scheme: HTTP
        initialDelaySeconds: 15    # Wait before first check
        periodSeconds: 30          # Check every 30 seconds
        timeoutSeconds: 10         # Timeout if no response in 10s
        failureThreshold: 3        # Restart after 3 failures

      # Readiness: Ready for traffic?
      readinessProbe:
        httpGet:
          path: /ready
          port: http
          scheme: HTTP
        initialDelaySeconds: 10
        periodSeconds: 10          # Check every 10 seconds
        timeoutSeconds: 5
        failureThreshold: 3        # Remove from LB after 3 failures

      # Startup: App initializing?
      startupProbe:
        httpGet:
          path: /health
          port: http
          scheme: HTTP
        initialDelaySeconds: 0
        periodSeconds: 10
        failureThreshold: 30       # Give 30 * 10s = 5 min to start
```

### 3. Nginx Ingress Routes Health Endpoints

**File:** `k8s/base/ingress.yaml`

```yaml
rules:
  - host: orderit.duckdns.org
    http:
      paths:
        # Health check exposed to external clients
        - path: /health
          pathType: Exact
          backend:
            service:
              name: backend
              port:
                number: 4000

        # Readiness probe exposed to external clients
        - path: /ready
          pathType: Exact
          backend:
            service:
              name: backend
              port:
                number: 4000

        # Metrics endpoint exposed (for Prometheus)
        - path: /metrics
          pathType: Exact
          backend:
            service:
              name: backend
              port:
                number: 9090

        # API routes
        - path: /api
          pathType: Prefix
          backend:
            service:
              name: backend
              port:
                number: 4000
```

---

## 📡 Access Patterns

### Kubernetes Internal (Inside Cluster)

| What | URL | Who | Purpose |
|------|-----|-----|---------|
| **Liveness Probe** | `http://backend:4000/health` | Kubelet | Check if pod is alive |
| **Readiness Probe** | `http://backend:4000/ready` | Kubelet | Check if pod ready for traffic |
| **Frontend App** | `http://backend:4000/api/*` | Frontend Pod | API calls |
| **Prometheus** | `http://backend:4000/metrics` | Prometheus Pod | Scrape metrics |

### External (Outside Cluster - Via Ingress)

| What | URL | Who | Purpose |
|------|-----|-----|---------|
| **Health Check** | `https://orderit.duckdns.org/health` | Monitoring tools | External health check |
| **Readiness Check** | `https://orderit.duckdns.org/ready` | LB health check | Traffic routing decision |
| **Metrics** | `https://orderit.duckdns.org/metrics` | Prometheus scraper | Collect metrics |
| **API** | `https://orderit.duckdns.org/api/*` | Frontend browser | API calls |
| **Frontend** | `https://orderit.duckdns.org/` | Browser | Web app |

---

## 🧪 Testing Health Endpoints

### From Localhost (Docker)

```bash
# Backend container
docker-compose exec backend wget -O- http://localhost:4000/health
docker-compose exec backend wget -O- http://localhost:4000/ready

# From frontend container
docker-compose exec frontend wget -O- http://backend:4000/health
```

### From K8s Cluster

```bash
# Backend pod
kubectl -n orderit exec deployment/backend -- wget -O- http://localhost:4000/health
kubectl -n orderit exec deployment/backend -- wget -O- http://localhost:4000/ready

# From frontend pod
kubectl -n orderit exec deployment/frontend -- wget -O- http://backend:4000/health

# From any pod
kubectl run -it --rm debug --image=curlimages/curl:latest --restart=Never -- \
  curl http://backend.orderit.svc.cluster.local:4000/health
```

### From External (Via Ingress)

```bash
# Health check
curl https://orderit.duckdns.org/health

# Readiness check
curl https://orderit.duckdns.org/ready

# Metrics
curl https://orderit.duckdns.org/metrics
```

### Monitor Probe Results

```bash
# Describe pod to see probe results
kubectl -n orderit describe pod <backend-pod-name>

# Look for:
# Liveness:   http-get delay=15s timeout=10s period=30s #success=1 #failure=3
#   Last Probe:   Thu Aug 15 12:34:56 2026
#   Last Result:  Success

# Readiness: http-get delay=10s timeout=5s period=10s #success=1 #failure=3
#   Last Probe:   Thu Aug 15 12:34:56 2026
#   Last Result:  Success
```

---

## 🔍 Health Endpoint Response Examples

### `/health` Response (Alive)

```json
{
  "status": "ok",
  "service": "orderit-backend",
  "timestamp": "2026-08-15T12:34:56.789Z",
  "uptime": 3600.5
}
```

### `/ready` Response (Ready)

```json
{
  "ready": true,
  "checks": {
    "database": true
  },
  "timestamp": "2026-08-15T12:34:56.789Z"
}
```

### `/ready` Response (Not Ready)

```json
{
  "ready": false,
  "checks": {
    "database": false
  },
  "timestamp": "2026-08-15T12:34:56.789Z"
}
```

HTTP Status: **503 Service Unavailable**

---

## ⚙️ Probe Configuration Tuning

### Fast Startup (Dev)

```yaml
startupProbe:
  failureThreshold: 10  # 10 * 10s = 100s max startup
```

### Slow Startup (Legacy App)

```yaml
startupProbe:
  failureThreshold: 60  # 60 * 10s = 10 min max startup
```

### Aggressive Liveness (Fast Failure Detection)

```yaml
livenessProbe:
  periodSeconds: 10     # Check every 10s (vs 30s)
  failureThreshold: 2   # Restart after 2 failures (vs 3)
```

### Lenient Readiness (Avoid Thrashing)

```yaml
readinessProbe:
  periodSeconds: 20     # Check every 20s (vs 10s)
  failureThreshold: 5   # Remove from LB after 5 failures
```

---

## 📋 Checklist

- [ ] Backend implements `/health` endpoint
- [ ] Backend implements `/ready` endpoint (checks DB connection)
- [ ] Backend exposes ports 4000 (http) and 9090 (metrics)
- [ ] Deployment has liveness, readiness, startup probes configured
- [ ] Service routes ports correctly (4000, 9090)
- [ ] Ingress routes `/health`, `/ready`, `/metrics` to backend
- [ ] Test health endpoints work locally (`docker-compose`)
- [ ] Test health endpoints work in K8s (`kubectl exec`)
- [ ] Monitor probe results (`kubectl describe pod`)
- [ ] HPA metrics-server can access metrics
- [ ] External health checks pass

---

## 🚨 Common Issues

### "Readiness probe failed"

**Problem:** Pod marked as "Not Ready", removed from service

**Causes:**
- Database not connected
- External service unreachable
- `/ready` endpoint not returning 200

**Fix:**
```bash
# Check pod
kubectl -n orderit describe pod backend-xyz

# Check logs
kubectl -n orderit logs backend-xyz

# Check endpoint manually
kubectl -n orderit exec deployment/backend -- wget -O- http://localhost:4000/ready
```

### "Liveness probe failed - pod restarted"

**Problem:** Pod keeps crashing and restarting

**Causes:**
- App crashes after starting
- `/health` endpoint throws error
- High memory/CPU usage

**Fix:**
```bash
# Check logs
kubectl -n orderit logs --previous backend-xyz

# Increase initialDelaySeconds if app needs time to start
# Increase timeoutSeconds if app is slow to respond
```

### "Pod stuck in CrashLoopBackOff"

**Problem:** Pod crashes immediately on start

**Causes:**
- Missing environment variables
- Database connection string wrong
- Port already in use

**Fix:**
```bash
# Check for startup errors
kubectl -n orderit logs backend-xyz

# Check env vars
kubectl -n orderit exec deployment/backend -- env | grep DB_

# Check if port is available
kubectl -n orderit exec deployment/backend -- netstat -tulpn | grep 4000
```

---

## 🔗 References

- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [HTTP Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#http-probes)
- [Probe Behavior](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes)

---

**Last Updated:** 2026-08-15
