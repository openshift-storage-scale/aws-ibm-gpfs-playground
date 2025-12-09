#!/bin/bash

# Hitachi Operators Installation Script
# Deploys Hitachi VSP One SDS operators to Kubernetes cluster

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/aws-gpfs-playground/ocp_install_files/auth/kubeconfig}"
NAMESPACE="${1:-hitachi-sds}"

echo "=========================================="
echo "Hitachi Operators Installation"
echo "=========================================="
echo ""
echo "KUBECONFIG: $KUBECONFIG"
echo "Namespace: $NAMESPACE"
echo ""

# Verify cluster connectivity
if ! export KUBECONFIG="$KUBECONFIG" && kubectl cluster-info >/dev/null 2>&1; then
    echo "✓ Connected to cluster"
else
    echo "❌ Cannot connect to cluster"
    exit 1
fi

# Create namespace
echo ""
echo "Creating namespaces..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace hitachi-system --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespaces created"

# Label namespaces
echo ""
echo "Labeling namespaces..."
kubectl label namespace "$NAMESPACE" name=hitachi --overwrite
kubectl label namespace hitachi-system name=hitachi-system --overwrite
echo "✓ Namespaces labeled"

# Check for existing deployments
echo ""
echo "Checking existing Hitachi resources..."
POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
DEPLOYMENT_COUNT=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$POD_COUNT" -gt 0 ]; then
    echo "⚠️  Found $POD_COUNT pods already in $NAMESPACE"
    kubectl get pods -n "$NAMESPACE" -o wide
else
    echo "✓ Namespace is clean"
fi

echo ""
echo "To continue with Hitachi operator deployment:"
echo "  1. Run: make install-hitachi"
echo "  2. Or check the playbooks/install-hitachi.yml for manual deployment"
echo ""
echo "Monitor deployment progress with:"
echo "  ./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1"
echo ""
