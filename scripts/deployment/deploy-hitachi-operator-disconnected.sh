#!/bin/bash
##############################################################################
# deploy-hitachi-operator-disconnected.sh
# Purpose: Deploy Hitachi HSPC operator for disconnected/air-gapped environments
# Works with pre-downloaded charts or local container images
# Usage: ./deploy-hitachi-operator-disconnected.sh [options]
##############################################################################

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
LOG_DIR="${PROJECT_ROOT}/Logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Setup logging
LOG_FILE="${LOG_DIR}/deploy-hitachi-operator-disconnected-$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""

# Configuration
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
NAMESPACE="${NAMESPACE:-hitachi-system}"
HELM_VERSION="${HELM_VERSION:-3.14.0}"
LOCAL_CHART_PATH="${LOCAL_CHART_PATH:-${PROJECT_ROOT}/charts/vsp-one-sds-hspc}"
REGISTRY_URL="${REGISTRY_URL:-docker.io}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verify prerequisites
verify_prerequisites() {
    log_info "Verifying prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm."
        exit 1
    fi
    
    # Check kubeconfig
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_error "KUBECONFIG not found at: $KUBECONFIG_PATH"
        exit 1
    fi
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    # Verify cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to cluster"
        exit 1
    fi
    
    CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')
    log_info "✓ Connected to cluster (version: $CLUSTER_VERSION)"
}

# Create namespace if it doesn't exist
create_namespace() {
    log_info "Setting up namespace..."
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_info "✓ Namespace $NAMESPACE already exists"
    else
        log_info "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
        log_info "✓ Namespace created"
    fi
}

# Deploy operator with local/cached chart
deploy_with_local_chart() {
    log_info "Deploying Hitachi HSPC operator with local chart..."
    
    # Check if chart path is provided and valid
    if [ -z "$LOCAL_CHART_PATH" ] || [ ! -d "$LOCAL_CHART_PATH" ]; then
        log_warn "LOCAL_CHART_PATH not accessible: $LOCAL_CHART_PATH"
        log_info "Checking default chart location: ${PROJECT_ROOT}/charts/vsp-one-sds-hspc"
        if [ ! -d "${PROJECT_ROOT}/charts/vsp-one-sds-hspc" ]; then
            log_error "No pre-downloaded chart found."
            log_info "To download the chart for offline use:"
            log_info "  From a machine with internet access:"
            log_info "  helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi"
            log_info "  helm pull hitachi/vsp-one-sds-hspc --version $HELM_VERSION --untar"
            log_info "  mkdir -p ${PROJECT_ROOT}/charts"
            log_info "  mv vsp-one-sds-hspc ${PROJECT_ROOT}/charts/"
            return 1
        fi
        LOCAL_CHART_PATH="${PROJECT_ROOT}/charts/vsp-one-sds-hspc"
    fi
    
    log_info "Using chart from: $LOCAL_CHART_PATH"
    
    helm upgrade --install vsp-one-sds-hspc \
        "$LOCAL_CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set image.registry="$REGISTRY_URL" \
        --set image.repository=hitachi/vsp-one-sds-hspc \
        --set image.tag="$HELM_VERSION" \
        --set image.pullPolicy=IfNotPresent \
        --set rbac.create=true \
        --set serviceAccount.create=true \
        --set serviceAccount.name=vsp-one-sds-hspc \
        --set resources.limits.cpu=1000m \
        --set resources.limits.memory=1024Mi \
        --set resources.requests.cpu=500m \
        --set resources.requests.memory=512Mi
    
    log_info "✓ Helm deployment initiated"
}

# Deploy operator directly with manifest
deploy_with_manifest() {
    log_info "Deploying Hitachi HSPC operator with direct manifest..."
    
    cat > /tmp/hitachi-hspc-operator.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vsp-one-sds-hspc
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vsp-one-sds-hspc
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vsp-one-sds-hspc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: vsp-one-sds-hspc
subjects:
- kind: ServiceAccount
  name: vsp-one-sds-hspc
  namespace: $NAMESPACE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vsp-one-sds-hspc
  namespace: $NAMESPACE
  labels:
    app: vsp-one-sds-hspc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vsp-one-sds-hspc
  template:
    metadata:
      labels:
        app: vsp-one-sds-hspc
    spec:
      serviceAccountName: vsp-one-sds-hspc
      containers:
      - name: vsp-one-sds-hspc
        image: $REGISTRY_URL/hitachi/vsp-one-sds-hspc:$HELM_VERSION
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
          requests:
            cpu: 500m
            memory: 512Mi
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        ports:
        - containerPort: 8080
          name: metrics
          protocol: TCP
EOF
    
    kubectl apply -f /tmp/hitachi-hspc-operator.yaml
    log_info "✓ Manifest deployment applied"
}

# Wait for operator readiness
wait_for_operator() {
    log_info "Waiting for Hitachi HSPC operator to be ready..."
    log_info "This may take 2-3 minutes..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        
        local ready=$(kubectl get deployment -n "$NAMESPACE" vsp-one-sds-hspc \
            -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")
        
        if [ "$ready" == "True" ]; then
            log_info "✓ Hitachi HSPC operator is ready"
            return 0
        fi
        
        echo -n "."
        sleep 3
    done
    
    echo ""
    log_error "Timeout waiting for operator to become ready"
    return 1
}

# Display deployment status
show_status() {
    log_info "Deployment Status:"
    echo ""
    
    echo "Deployment:"
    kubectl get deployment -n "$NAMESPACE" vsp-one-sds-hspc -o wide
    echo ""
    
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=vsp-one-sds-hspc -o wide
    echo ""
    
    echo "ServiceAccount:"
    kubectl get sa -n "$NAMESPACE" vsp-one-sds-hspc -o wide
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Hitachi HSPC Operator Deployment (Disconnected)"
    echo "=========================================="
    echo ""
    
    verify_prerequisites
    echo ""
    
    create_namespace
    echo ""
    
    # Choose deployment method
    if [ -n "$LOCAL_CHART_PATH" ]; then
        deploy_with_local_chart || deploy_with_manifest
    else
        log_warn "No LOCAL_CHART_PATH provided. Using direct manifest deployment..."
        deploy_with_manifest
    fi
    echo ""
    
    wait_for_operator || {
        log_error "Operator deployment failed"
        show_status
        exit 1
    }
    echo ""
    
    show_status
    
    echo "=========================================="
    log_info "✓ Deployment complete"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Configure storage array connection"
    echo "  2. Create StorageClass"
    echo "  3. Deploy test applications"
    echo ""
}

# Run main
main "$@"
