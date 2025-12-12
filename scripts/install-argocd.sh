#!/bin/bash
set -e

# Configuration
ARGOCD_VERSION="v2.10.0"
ARGOCD_NAMESPACE="argocd"
MGMT_CLUSTER_NAME="dev-mgmt-cluster"
REGION="eu-west-1"

echo "=== ArgoCD Bootstrap ==="

# 1. Connect to Management Cluster
echo "Connecting to EKS Management Cluster: $MGMT_CLUSTER_NAME..."
aws eks update-kubeconfig --name "$MGMT_CLUSTER_NAME" --region "$REGION"

# 2. Install ArgoCD
echo "Creating namespace $ARGOCD_NAMESPACE..."
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ArgoCD $ARGOCD_VERSION..."
kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml

# 3. Wait for ArgoCD to be ready
echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n "$ARGOCD_NAMESPACE" --timeout=300s

# 4. Apply Guestbook Application
echo "Applying Guestbook Application..."
kubectl apply -f ../k8s/argocd/guestbook-app.yaml

echo "=== Bootstrap Complete ==="
echo "ArgoCD is running in namespace: $ARGOCD_NAMESPACE"
echo "Guestbook App configured to sync from k8s/manifests/guestbook"
