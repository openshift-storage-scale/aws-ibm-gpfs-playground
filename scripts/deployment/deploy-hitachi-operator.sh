#!/bin/bash
##############################################################################
# deploy-hitachi-operator.sh
# Purpose: Deploy Hitachi Storage Plug-in for Containers (HSPC) operator
# Usage: ./deploy-hitachi-operator.sh [kubeconfig-path] [namespace] [version] [use-local-chart]
# Example: ./deploy-hitachi-operator.sh ~/.kube/config hitachi-system 3.14.0 true
##############################################################################

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
LOG_DIR="${PROJECT_ROOT}/Logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Setup logging
LOG_FILE="${LOG_DIR}/deploy-hitachi-operator-$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""

KUBECONFIG_PATH="${1:-$(echo $KUBECONFIG)}"
NAMESPACE="${2:-hitachi-system}"
HELM_VERSION="${3:-3.14.0}"
USE_LOCAL_CHART="${4:-true}"
HELM_REPO="hitachi"
HELM_CHART="vsp-one-sds-hspc"
HELM_REPO_URL="https://cdn.hitachivantara.com/charts/hitachi"
LOCAL_CHART_PATH="${PROJECT_ROOT}/charts/vsp-one-sds-hspc"

if [ -z "$KUBECONFIG_PATH" ]; then
    echo "Error: KUBECONFIG not set"
    echo "Usage: $0 [kubeconfig-path] [namespace] [version]"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "=========================================="
echo "Hitachi HSPC Operator Deployment"
echo "=========================================="
echo "KUBECONFIG: $KUBECONFIG_PATH"
echo "Namespace: $NAMESPACE"
echo "Helm Chart Version: $HELM_VERSION"
echo ""

# Step 1: Verify cluster connectivity
echo "[1/5] Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "✗ Cannot connect to cluster"
    exit 1
fi
CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')
echo "✓ Cluster connected (version: $CLUSTER_VERSION)"
echo ""

# Step 2: Verify namespace exists
echo "[2/5] Verifying namespace..."
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "✗ Namespace $NAMESPACE does not exist"
    echo "  Please run: kubectl create namespace $NAMESPACE"
    exit 1
fi
echo "✓ Namespace $NAMESPACE exists"
echo ""

# Step 3: Handle chart deployment
echo "[3/5] Preparing Helm chart..."

if [ "$USE_LOCAL_CHART" == "true" ] && [ -d "$LOCAL_CHART_PATH" ]; then
    echo "✓ Using pre-downloaded local chart: $LOCAL_CHART_PATH"
    CHART_REFERENCE="$LOCAL_CHART_PATH"
elif [ "$USE_LOCAL_CHART" == "true" ] && [ ! -d "$LOCAL_CHART_PATH" ]; then
    echo "✗ Local chart not found at: $LOCAL_CHART_PATH"
    echo "  To download the chart for offline use:"
    echo "  From a machine with internet access:"
    echo "    helm repo add hitachi $HELM_REPO_URL"
    echo "    helm pull hitachi/$HELM_CHART --version $HELM_VERSION --untar"
    echo "    mkdir -p $PROJECT_ROOT/charts"
    echo "    mv $HELM_CHART $PROJECT_ROOT/charts/"
    exit 1
else
    echo "Adding Hitachi Helm repository..."
    helm repo add "$HELM_REPO" "$HELM_REPO_URL" 2>&1 | grep -v "already exists" || true
    helm repo update 2>&1 | grep -E "Hang tight|Update Complete|^$" || true
    echo "✓ Helm repository configured"
    CHART_REFERENCE="$HELM_REPO/$HELM_CHART"
fi
echo ""

# Step 4: Deploy HSPC operator via Helm
echo "[4/5] Deploying Hitachi HSPC operator..."
echo "  Chart: $CHART_REFERENCE"
echo "  Version: $HELM_VERSION"
echo "  Release: $HELM_REPO-$HELM_CHART"
echo ""

helm upgrade --install "$HELM_REPO-$HELM_CHART" \
    "$CHART_REFERENCE" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$HELM_VERSION" \
    --set image.registry=docker.io \
    --set image.repository=hitachi/vsp-one-sds-hspc \
    --set image.tag="$HELM_VERSION" \
    --set image.pullPolicy=IfNotPresent \
    --set rbac.create=true \
    --set serviceAccount.create=true \
    --set serviceAccount.name=vsp-one-sds-hspc \
    --set resources.limits.cpu=1000m \
    --set resources.limits.memory=1024Mi \
    --set resources.requests.cpu=500m \
    --set resources.requests.memory=512Mi \
    2>&1 | tail -20

echo ""
echo "✓ Helm deployment initiated"
echo ""

# Step 5: Wait for operator to be ready
echo "[5/5] Waiting for Hitachi HSPC operator to be ready..."
echo "  This may take 2-3 minutes..."
echo ""

MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Get deployment status
    REPLICAS=$(kubectl get deployment -n "$NAMESPACE" \
        -l app=vsp-one-sds-hspc \
        -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || echo "0")
    
    DESIRED=$(kubectl get deployment -n "$NAMESPACE" \
        -l app=vsp-one-sds-hspc \
        -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "0")
    
    if [ "$REPLICAS" == "$DESIRED" ] && [ "$DESIRED" != "0" ]; then
        echo "✓ Hitachi HSPC operator is ready (replicas: $REPLICAS/$DESIRED)"
        echo ""
        break
    fi
    
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS - Ready replicas: $REPLICAS/$DESIRED"
    sleep 3
done

if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "✗ Timeout waiting for operator to become ready"
    echo ""
    echo "Operator status:"
    kubectl describe deployment -n "$NAMESPACE" -l app=vsp-one-sds-hspc 2>/dev/null || echo "No deployment found"
    exit 1
fi

echo ""

# Display deployment status
echo "=========================================="
echo "✓ Deployment complete"
echo "=========================================="
echo ""
echo "Operator Status:"
kubectl get deployment -n "$NAMESPACE" -l app=vsp-one-sds-hspc -o wide
echo ""
echo "Operator Pods:"
kubectl get pods -n "$NAMESPACE" -l app=vsp-one-sds-hspc -o wide
echo ""
echo "Next steps:"
echo "  1. Configure storage array connection"
echo "  2. Create StorageClass"
echo "  3. Deploy test applications"
echo ""
