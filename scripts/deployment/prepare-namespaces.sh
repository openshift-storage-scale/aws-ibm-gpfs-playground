#!/bin/bash
##############################################################################
# prepare-hitachi-namespace.sh
# Purpose: Prepare Kubernetes namespaces for Hitachi SDS deployment
# Usage: ./prepare-hitachi-namespace.sh [kubeconfig-path] [namespace]
# Example: ./prepare-hitachi-namespace.sh ~/.kube/config hitachi-system
##############################################################################

set -e

KUBECONFIG_PATH="${1:-$(echo $KUBECONFIG)}"
NAMESPACE="${2:-hitachi-system}"

if [ -z "$KUBECONFIG_PATH" ]; then
    echo "Error: KUBECONFIG not set"
    echo "Usage: $0 [kubeconfig-path] [namespace]"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "=========================================="
echo "Hitachi SDS Namespace Preparation"
echo "=========================================="
echo "KUBECONFIG: $KUBECONFIG_PATH"
echo "Namespace: $NAMESPACE"
echo ""

# Step 1: Verify cluster connectivity
echo "[1/5] Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "✗ Cannot connect to cluster"
    exit 1
fi
echo "✓ Cluster connectivity verified"
echo ""

# Step 2: Create hitachi-sds namespace
echo "[2/5] Creating hitachi-sds namespace..."
kubectl create namespace hitachi-sds --dry-run=client -o yaml | kubectl apply -f - 2>&1 | grep -v "already exists" || true
echo "✓ hitachi-sds namespace ready"
echo ""

# Step 3: Create hitachi-system namespace
echo "[3/5] Creating hitachi-system namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>&1 | grep -v "already exists" || true
echo "✓ $NAMESPACE namespace ready"
echo ""

# Step 4: Label namespaces for operator deployment
echo "[4/5] Labeling namespaces..."
kubectl label namespace hitachi-sds \
    app.kubernetes.io/name=hitachi-sds \
    app.kubernetes.io/component=storage \
    --overwrite 2>&1 | grep -v "already exists" || true

kubectl label namespace "$NAMESPACE" \
    app.kubernetes.io/name=hitachi-system \
    app.kubernetes.io/component=operators \
    --overwrite 2>&1 | grep -v "already exists" || true
echo "✓ Namespaces labeled"
echo ""

# Step 5: Verify namespace creation
echo "[5/5] Verifying namespace creation..."
echo ""
echo "Hitachi namespaces:"
kubectl get namespaces | grep -E "hitachi-|NAME"
echo ""

echo "=========================================="
echo "✓ Namespace preparation complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Add Hitachi Helm repository"
echo "  2. Deploy Hitachi SDS HSPC operator"
echo "  3. Configure storage classes"
echo ""
