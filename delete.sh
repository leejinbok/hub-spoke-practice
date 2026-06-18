#!/bin/bash

echo "🧹 Starting complete ArgoCD and Hub-and-Spoke teardown..."

# ==========================================
# Set Environment Variables
# ==========================================
PORT="8080"
SPOKE_NAMESPACES="team-one-ns team-two-ns" 
# ==========================================

echo "Step 1: Stopping background port-forwarding..."
# Find and kill the process holding the port, suppress errors if none exist
lsof -ti:$PORT | xargs kill -9 2>/dev/null || echo "   -> No port-forward currently running on $PORT."

echo "Step 2: Deleting Spoke team namespaces..."
for ns in $SPOKE_NAMESPACES; do
  echo "   -> Removing namespace: $ns"
  kubectl delete namespace $ns --ignore-not-found=true || true
done

echo "Uninstalling ArgoCD controller components..."
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found=true || true

echo "Step 4: Deleting argocd namespace..."
kubectl delete namespace argocd --ignore-not-found=true || true

echo "Step 5: Checking and Cleaning ArgoCD CRDs..."
kubectl get crds -o name | grep 'argoproj.io' | xargs -r kubectl delete || true

echo ""
echo "======================================================"
echo "                 Teardown complete!"
echo "======================================================"