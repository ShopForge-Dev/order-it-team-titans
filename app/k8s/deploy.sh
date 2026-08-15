#!/bin/bash
# Kubernetes deployment script for Orderit

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ENVIRONMENT="${1:-dev}"
NAMESPACE="orderit"
GITHUB_USER="${GITHUB_USER:-}"

echo -e "${YELLOW}🚀 Orderit Kubernetes Deployment${NC}\n"

# Validate environment
case "$ENVIRONMENT" in
  dev|development)
    OVERLAY="overlays/dev"
    ENVIRONMENT="development"
    ;;
  prod|production)
    OVERLAY="overlays/prod"
    ENVIRONMENT="production"
    ;;
  *)
    echo -e "${RED}✗ Invalid environment. Use: dev or prod${NC}"
    echo "Usage: $0 [dev|prod] [action]"
    exit 1
    ;;
esac

# Validate kubectl
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}✗ kubectl not found. Install kubectl first.${NC}"
  exit 1
fi

# Validate kustomize
if ! command -v kustomize &> /dev/null; then
  echo -e "${RED}✗ kustomize not found. Install kustomize first.${NC}"
  echo "Download: https://kubectl.docs.kubernetes.io/installation/kustomize/"
  exit 1
fi

# Get action (default: apply)
ACTION="${2:-apply}"

case "$ACTION" in
  apply)
    echo -e "${YELLOW}📦 Deploying to $ENVIRONMENT${NC}\n"

    # Validate secrets are set
    if grep -q "change-me\|your-\|GITHUB_USER" "k8s/base/secret.yaml"; then
      echo -e "${RED}⚠️  ERROR: Update k8s/base/secret.yaml with real values first!${NC}"
      echo "  - JWT_SECRET"
      echo "  - CLOUDINARY_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET"
      echo "  - STRIPE_KEY, STRIPE_SECRET_KEY"
      echo "  - SMTP credentials"
      echo "  - REGISTRY credentials (if using private registry)"
      exit 1
    fi

    # Build manifests
    echo -e "${YELLOW}🔨 Building manifests with kustomize${NC}"
    kustomize build "k8s/$OVERLAY" > /tmp/orderit-manifests.yaml

    # Show diff
    echo -e "${YELLOW}📋 Changes to apply:${NC}"
    kubectl diff -f /tmp/orderit-manifests.yaml || true

    # Confirm
    read -p "Apply changes? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      exit 1
    fi

    # Apply
    kubectl apply -f /tmp/orderit-manifests.yaml

    echo -e "\n${GREEN}✓ Deployment complete${NC}"
    echo -e "${YELLOW}Verifying...${NC}\n"

    kubectl -n $NAMESPACE get all
    ;;

  delete)
    echo -e "${YELLOW}🗑️  Deleting $ENVIRONMENT deployment${NC}\n"

    read -p "Delete all resources in namespace $NAMESPACE? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      exit 1
    fi

    kustomize build "k8s/$OVERLAY" | kubectl delete -f - || true
    kubectl delete namespace $NAMESPACE || true

    echo -e "${GREEN}✓ Deletion complete${NC}"
    ;;

  status)
    echo -e "${YELLOW}📊 Deployment Status${NC}\n"

    echo -e "${YELLOW}Pods:${NC}"
    kubectl -n $NAMESPACE get pods -o wide

    echo -e "\n${YELLOW}Services:${NC}"
    kubectl -n $NAMESPACE get svc

    echo -e "\n${YELLOW}Ingress:${NC}"
    kubectl -n $NAMESPACE get ingress

    echo -e "\n${YELLOW}HPA Status:${NC}"
    kubectl -n $NAMESPACE get hpa

    echo -e "\n${YELLOW}Resource Usage:${NC}"
    kubectl -n $NAMESPACE top pods || echo "Metrics not available yet"
    ;;

  logs)
    SERVICE="${3:-backend}"
    echo -e "${YELLOW}📋 Logs for $SERVICE${NC}\n"
    kubectl -n $NAMESPACE logs -f deployment/$SERVICE --all-containers=true --timestamps=true
    ;;

  exec)
    SERVICE="${3:-backend}"
    echo -e "${YELLOW}🔧 Shell for $SERVICE${NC}\n"
    kubectl -n $NAMESPACE exec -it deployment/$SERVICE -- sh
    ;;

  restart)
    SERVICE="${3:-}"
    if [ -z "$SERVICE" ]; then
      echo -e "${RED}✗ Specify service: deploy.sh restart backend${NC}"
      exit 1
    fi

    echo -e "${YELLOW}🔄 Restarting $SERVICE${NC}\n"
    kubectl -n $NAMESPACE rollout restart deployment/$SERVICE
    kubectl -n $NAMESPACE rollout status deployment/$SERVICE
    echo -e "${GREEN}✓ Rollout complete${NC}"
    ;;

  rollback)
    SERVICE="${3:-}"
    if [ -z "$SERVICE" ]; then
      echo -e "${RED}✗ Specify service: deploy.sh rollback backend${NC}"
      exit 1
    fi

    echo -e "${YELLOW}⏮️  Rolling back $SERVICE${NC}\n"
    kubectl -n $NAMESPACE rollout undo deployment/$SERVICE
    kubectl -n $NAMESPACE rollout status deployment/$SERVICE
    echo -e "${GREEN}✓ Rollback complete${NC}"
    ;;

  scale)
    SERVICE="${3:-backend}"
    REPLICAS="${4:-3}"

    echo -e "${YELLOW}📈 Scaling $SERVICE to $REPLICAS replicas${NC}\n"
    kubectl -n $NAMESPACE scale deployment/$SERVICE --replicas=$REPLICAS
    echo -e "${GREEN}✓ Scaling complete${NC}"
    ;;

  *)
    echo "Usage: $0 [dev|prod] [action] [options]"
    echo ""
    echo "Actions:"
    echo "  apply         - Deploy to cluster (default)"
    echo "  delete        - Delete all resources"
    echo "  status        - Show deployment status"
    echo "  logs          - View logs (service: backend|frontend|mongo)"
    echo "  exec          - Shell into pod (service: backend|frontend|mongo)"
    echo "  restart       - Restart deployment (service: backend|frontend|mongo)"
    echo "  rollback      - Rollback to previous version (service: backend|frontend|mongo)"
    echo "  scale         - Scale deployment (service replicas)"
    echo ""
    echo "Examples:"
    echo "  $0 dev apply"
    echo "  $0 prod apply"
    echo "  $0 dev logs backend"
    echo "  $0 prod status"
    echo "  $0 dev exec frontend"
    echo "  $0 prod scale backend 5"
    exit 1
    ;;
esac
