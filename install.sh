#!/bin/bash

# ==========================================
# TERMINAL COLORS
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color (This is crucial to reset the terminal!)
# ==========================================
# Set Environment Variables
# ==========================================
set -e
STATIC_PASSWORD="admin" # Change this to your preferred static password
PORT="8080"
# ==========================================

echo "Creating argocd namespace..."
# Using dry-run to ensure it doesn't fail if the namespace already exists
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ArgoCD..."
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD deployments to become available (this may take 1-3 minutes)..."
kubectl wait --for=condition=Available deployments --all -n argocd --timeout=300s

echo "Setting static admin password to '$STATIC_PASSWORD'..."
BCRYPT_HASH=$(kubectl exec -n argocd deployment/argocd-server -- argocd account bcrypt --password "$STATIC_PASSWORD")


kubectl patch secret argocd-secret -n argocd -p '{"stringData": { "admin.password": "'$BCRYPT_HASH'", "admin.passwordMtime": "'$(date +%FT%T%Z)'" }}'

# 3. Restart the server pod so it drops its cache and accepts the new password instantly
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

echo -e "${YELLOW}Bootstrapping the Hub Application...${NC}"
if [ -f "bootstrap/hub.yaml" ]; then
  kubectl apply -f bootstrap/hub.yaml
  echo -e "${GREEN}   -> Hub Application successfully submitted to the cluster!${NC}"
else
  echo -e "${RED}   -> WARNING: bootstrap/hub.yaml not found. Are you running this from the repo root?${NC}"
fi

echo "Port-forwarding ArgoCD UI to localhost:$PORT in the background..."
# Quietly kill any old port-forward process that might be hogging this port
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true

# Run the port-forward using nohup so it survives in the background
nohup kubectl port-forward svc/argocd-server -n argocd $PORT:443 > /tmp/argocd-pf.log 2>&1 &
PF_PID=$!

echo ""
echo "======================================================"
echo "ArgoCD is successfully installed and running!"
echo "URL:       https://localhost:$PORT"
echo "Username:  admin"
echo "Password:  $STATIC_PASSWORD"
echo "Port-Forward PID: $PF_PID"
echo "======================================================"
echo "Note: To stop the background port-forward later, run: kill $PF_PID"
echo "Logs for the port-forward are located at /tmp/argocd-pf.log"