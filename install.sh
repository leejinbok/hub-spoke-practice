#!/bin/bash

# ==========================================
# TERMINAL COLORS
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
# ==========================================
# Set Environment Variables
# ==========================================
set -e
STATIC_PASSWORD="admin" # Change this to your preferred static password
PORT="8080"
# ==========================================

echo -e "${BOLD}Starting ArgoCD installation...${NC}\n"

echo -e "${CYAN}Step 1: Creating argocd namespace...${NC}"
# Using dry-run to ensure it doesn't fail if the namespace already exists
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "${CYAN}Step 2: Installing ArgoCD...${NC}"
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${YELLOW}Step 3: Waiting for ArgoCD deployments to become available (this may take 1-3 minutes)...${NC}"
kubectl wait --for=condition=Available deployments --all -n argocd --timeout=300s

echo -e "${CYAN}Step 4: Setting static admin password to '${YELLOW}$STATIC_PASSWORD${CYAN}'...${NC}"
BCRYPT_HASH=$(kubectl exec -n argocd deployment/argocd-server -- argocd account bcrypt --password "$STATIC_PASSWORD")
kubectl patch secret argocd-secret -n argocd -p '{"stringData": { "admin.password": "'$BCRYPT_HASH'", "admin.passwordMtime": "'$(date +%FT%T%Z)'" }}'

# Restart the server pod so it drops its cache and accepts the new password instantly
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

echo -e "${CYAN}Step 5: Bootstrapping the Hub Application...${NC}"
if [ -f "bootstrap/hub.yaml" ]; then
  kubectl apply -f bootstrap/hub.yaml
  echo -e "${GREEN}   -> Hub Application successfully submitted to the cluster!${NC}"
else
  echo -e "${RED}   -> ⚠️ WARNING: bootstrap/hub.yaml not found. Are you running this from the repo root?${NC}"
fi

echo -e "${CYAN}Step 6: Port-forwarding ArgoCD UI to localhost:$PORT in the background...${NC}"
# Quietly kill any old port-forward process that might be hogging this port
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true

# Run the port-forward using nohup so it survives in the background
nohup kubectl port-forward svc/argocd-server -n argocd $PORT:443 > /tmp/argocd-pf.log 2>&1 &
PF_PID=$!

echo -e ""
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}         ArgoCD is successfully installed!${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${BOLD} URL:       ${NC}https://localhost:$PORT"
echo -e "${BOLD} Username:  ${NC}admin"
echo -e "${BOLD} Password:  ${YELLOW}$STATIC_PASSWORD${NC}"
echo -e "${BOLD} PID:       ${NC}$PF_PID"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${YELLOW}Note:${NC} To stop the background port-forward later, run: ${BOLD}kill $PF_PID${NC}"
echo -e "${YELLOW}Logs:${NC} /tmp/argocd-pf.log"