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
ARGO_PASSWORD="admin" # Change this to your preferred static password
PORT="8080" # Port to designate for port-forwarding

echo -e "${CYAN}Creating argocd namespace...${NC}"
# Creates argocd namespace; runs dry-run=client first in case it already exists
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "${CYAN}Installing ArgoCD...${NC}"
# Applies and installs ArgoCD using install.yaml
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${YELLOW}Waiting for ArgoCD deployments to become available (this may take 1-3 minutes)...${NC}"
# Before changing the admin password, checking to see if all deployments are up and running
kubectl wait --for=condition=Available deployments --all -n argocd --timeout=180s

echo -e "${CYAN}Setting admin password to '${YELLOW}$ARGO_PASSWORD${CYAN}'...${NC}"
# By default, ArgoCD generates a new admin password each time upon installation
# ArgoCD uses bcrypt hash; this sets the new password, retrieves the hash, and updates the k8s secret
# https://argo-cd.readthedocs.io/en/release-2.7/user-guide/commands/argocd_account_bcrypt/
BCRYPT_HASH=$(kubectl exec -n argocd deployment/argocd-server -- argocd account bcrypt --password "$STATIC_PASSWORD")
kubectl patch secret argocd-secret -n argocd -p '{"stringData": { "admin.password": "'$BCRYPT_HASH'", "admin.passwordMtime": "'$(date +%FT%T%Z)'" }}'

# Restart the server deployment to use new password
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s



echo -e "${CYAN}Fetching Git credentials...${NC}"
# This portion was created to automate several processes:
# The argo repo server needs access to any private repos; a new one repo access (k8s secret) will need to be created
# Instead of creating a new PAT just for this lab, this script renders the user's git credentials
# If git has cached user's git credentials, it can be retrieved using git `credential fill`
# https://git-scm.com/docs/git-credential#_typical_use_of_git_credential 
REPO_URL=$(git config --get remote.origin.url 2>/dev/null || true)

if [ -n "$REPO_URL" ]; then
  echo -e "   -> Repository: ${YELLOW}$REPO_URL${NC}"

  if [[ "$REPO_URL" == https://* || "$REPO_URL" == http://* ]]; then
    echo -e "   -> Requesting HTTPS credentials from local Git credential helper..."
    
    export GIT_TERMINAL_PROMPT=0
    export GIT_ASKPASS=true

    # Ask the host's Git to provide the credentials. 
    # Git strictly requires a double newline (\n\n) to signal the end of the input block.
    CREDS=$(printf "url=%s\n\n" "$REPO_URL" | git credential fill 2>/dev/null || true)
    
    if [ -n "$CREDS" ]; then
      GIT_USER=$(echo "$CREDS" | grep '^username=' | cut -d= -f2-)
      GIT_PASS=$(echo "$CREDS" | grep '^password=' | cut -d= -f2-)
      
      if [[ -n "$GIT_USER" && -n "$GIT_PASS" ]]; then
        kubectl create secret generic my-repo-creds -n argocd \
          --from-literal=url="$REPO_URL" \
          --from-literal=username="$GIT_USER" \
          --from-literal=password="$GIT_PASS" \
          --dry-run=client -o yaml | kubectl apply -f -
        
        kubectl label secret my-repo-creds -n argocd argocd.argoproj.io/secret-type=repository --overwrite
        echo -e "${GREEN}   -> Local HTTPS credentials successfully synced to cluster!${NC}"
      else
        echo -e "${RED}   -> Host Git credential helper did not return a password.${NC}"
      fi
    else
      echo -e "${RED}   -> Could not extract credentials from local Git helper.${NC}"
    fi
  fi
else
  echo -e "${YELLOW}   -> No Git remote found. Skipping auto-credential injection.${NC}"
fi

echo -e "${CYAN}Bootstrapping the Hub Application...${NC}"
# This portion was created to work with branches in the repository;
# By default, ArgoCD or other Helm charts will default to 'main' or 'HEAD'
# This will check and retrieve the current working branch name
# Once retrieved, it will initialize the Apps in Apps 
if [ -f "bootstrap/hub.yaml" ]; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")
  
  # Fallback in case of detached HEAD state where branch name is empty
  if [ -z "$CURRENT_BRANCH" ]; then CURRENT_BRANCH="HEAD"; fi

  echo -e "   -> Detected active branch: ${YELLOW}$CURRENT_BRANCH${NC}"

  cat bootstrap/hub.yaml | sed "s/targetRevision: .*/targetRevision: $CURRENT_BRANCH/g" | kubectl apply -f -
  
  echo -e "${GREEN}   -> Hub Application successfully submitted to the cluster tracking branch: $CURRENT_BRANCH!${NC}"
else
  echo -e "${RED}   -> WARNING: bootstrap/hub.yaml not found. Are you running this from the repo root?${NC}"
fi

echo -e "${CYAN}Port-forwarding ArgoCD UI to localhost:$PORT in the background...${NC}"
# Quietly kill any old port-forward process that might be using this port
# Port-forward requested port to argocd-server svc
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
nohup kubectl port-forward svc/argocd-server -n argocd $PORT:443 > /tmp/argocd-pf.log 2>&1 &
PF_PID=$!

echo -e ""
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}         ArgoCD is successfully installed!${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${BOLD}URL:       ${NC}https://localhost:$PORT"
echo -e "${BOLD}Username:  ${NC}admin"
echo -e "${BOLD}Password:  ${YELLOW}$STATIC_PASSWORD${NC}"
echo -e "${BOLD}PID:       ${NC}$PF_PID"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${YELLOW}Note:${NC} To stop the background port-forward later, run: ${BOLD}kill $PF_PID${NC}"
echo -e "${YELLOW}Logs:${NC} /tmp/argocd-pf.log"