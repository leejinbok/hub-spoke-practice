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
PORT="8080"
SPOKE_NAMESPACES="team-one-ns team-two-ns" 
# ==========================================

echo -e "${BOLD}Starting ArgoCD teardown...${NC}\n"

echo -e "${CYAN}Step 1: Stopping background port-forwarding...${NC}"

lsof -ti:$PORT | xargs kill -9 2>/dev/null || echo -e "${YELLOW}   -> No port-forward currently running on $PORT.${NC}"

echo -e "${CYAN}Step 2: Deleting Spoke team namespaces...${NC}"
for ns in $SPOKE_NAMESPACES; do
  echo -e "   -> Removing namespace: ${YELLOW}$ns${NC}"
  kubectl delete namespace $ns --ignore-not-found=true || true
done

echo -e "${CYAN}Step 3: Stripping finalizers from ArgoCD Apps to prevent namespace hang...${NC}"

kubectl patch app --all -n argocd -p '{"metadata": {"finalizers": null}}' --type merge 2>/dev/null || true
kubectl patch appproject --all -n argocd -p '{"metadata": {"finalizers": null}}' --type merge 2>/dev/null || true

echo -e "${CYAN}Step 4: Uninstalling ArgoCD controller components...${NC}"
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found=true || true

echo -e "${CYAN}Step 5: Deleting argocd namespace...${NC}"
kubectl delete namespace argocd --ignore-not-found=true || true

echo -e "${CYAN}Step 6: Checking and Cleaning ArgoCD CRDs...${NC}"
kubectl get crds -o name | grep 'argoproj.io' | xargs -r kubectl delete || true

echo -e ""
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}                Teardown complete!${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"