#!/bin/bash
##############################################################################
# troubleshoot-hitachi-deployment.sh
# Purpose: Diagnose and troubleshoot Hitachi deployment issues
# Usage: ./troubleshoot-hitachi-deployment.sh
##############################################################################

set +e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../" && pwd)"
LOG_DIR="${PROJECT_ROOT}/Logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Setup logging
LOG_FILE="${LOG_DIR}/troubleshoot-hitachi-$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Hitachi Deployment Troubleshooting"
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
export KUBECONFIG="$KUBECONFIG_PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# ============================================================================
# 1. CHECK DEPLOYMENT EXISTS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. CHECKING DEPLOYMENT STATUS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if ! kubectl get deployment vsp-one-sds-hspc -n hitachi-system &>/dev/null; then
    log_error "Deployment not found in hitachi-system namespace"
    log_info "Run deployment first: ./scripts/deployment/deploy-hitachi-operator-disconnected.sh"
    exit 1
fi

log_info "Deployment found: vsp-one-sds-hspc"
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o wide
echo ""

# ============================================================================
# 2. CHECK POD STATUS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. CHECKING POD STATUS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

POD_STATUS=$(kubectl get pods -n hitachi-system -l app=vsp-one-sds-hspc -o jsonpath='{.items[0].status.phase}')
log_info "Pod Status: $POD_STATUS"
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n hitachi-system -l app=vsp-one-sds-hspc -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    log_error "No pods found for deployment"
    exit 1
fi

log_info "Pod Name: $POD_NAME"
kubectl get pod "$POD_NAME" -n hitachi-system -o wide
echo ""

# ============================================================================
# 3. CHECK CONTAINER STATUS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. CHECKING CONTAINER STATUS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

CONTAINER_STATUS=$(kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.status.containerStatuses[0].state}')
log_debug "Container state: $CONTAINER_STATUS"

CONTAINER_READY=$(kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.status.containerStatuses[0].ready}')
if [ "$CONTAINER_READY" = "true" ]; then
    log_info "✓ Container is ready"
else
    log_warn "✗ Container is not ready"
fi

# Check for image pull errors
CONTAINER_IMAGE=$(kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.status.containerStatuses[0].image}')
log_info "Container Image: $CONTAINER_IMAGE"

IMAGE_PULL_REASON=$(kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
if [ ! -z "$IMAGE_PULL_REASON" ]; then
    log_error "Container Waiting Reason: $IMAGE_PULL_REASON"
    log_warn "Image pull may be failing. See events below."
fi

echo ""

# ============================================================================
# 4. CHECK POD EVENTS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. CHECKING POD EVENTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

log_info "Recent pod events:"
kubectl describe pod "$POD_NAME" -n hitachi-system | grep -A 100 "^Events:"
echo ""

# ============================================================================
# 5. CHECK IMAGE ACCESSIBILITY
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. CHECKING IMAGE ACCESSIBILITY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

log_info "Attempting to access image: $CONTAINER_IMAGE"
echo ""

# Try different ways to access the image
log_info "Method 1: Using podman/docker from control plane"
if command -v podman &>/dev/null; then
    log_debug "Testing with podman..."
    podman pull "$CONTAINER_IMAGE" &>/dev/null && \
        log_info "✓ Image accessible via podman" || \
        log_warn "✗ Image not accessible via podman"
elif command -v docker &>/dev/null; then
    log_debug "Testing with docker..."
    docker pull "$CONTAINER_IMAGE" &>/dev/null && \
        log_info "✓ Image accessible via docker" || \
        log_warn "✗ Image not accessible via docker"
else
    log_warn "No podman/docker available to test image pull"
fi

echo ""
log_info "Method 2: Checking image in cluster node"
POD_NODE=$(kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.spec.nodeName}')
log_info "Pod is running on node: $POD_NODE"
echo ""

# ============================================================================
# 6. CHECK IMAGE PULL SECRETS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. CHECKING IMAGE PULL SECRETS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

PULL_SECRETS=$(kubectl get serviceaccount vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.imagePullSecrets}')
if [ -z "$PULL_SECRETS" ] || [ "$PULL_SECRETS" = "[]" ]; then
    log_warn "No image pull secrets configured"
    log_info "If image requires authentication, create secret:"
    log_info "  kubectl create secret docker-registry hitachi-creds \\"
    log_info "    --docker-server=<registry> \\"
    log_info "    --docker-username=<user> \\"
    log_info "    --docker-password=<pass> \\"
    log_info "    -n hitachi-system"
else
    log_info "Image pull secrets configured: $PULL_SECRETS"
fi
echo ""

# ============================================================================
# 7. SOLUTIONS BASED ON STATUS
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}7. RECOMMENDED SOLUTIONS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if [[ "$IMAGE_PULL_REASON" == *"ImagePullBackOff"* ]] || [[ "$IMAGE_PULL_REASON" == *"Failed"* ]]; then
    log_error "Image Pull Error Detected"
    echo ""
    echo "SOLUTION OPTIONS:"
    echo ""
    echo "Option 1: Update Image Registry"
    echo "  $ kubectl set image deployment/vsp-one-sds-hspc \\"
    echo "      vsp-one-sds-hspc=<new-registry>/<new-image>:<version> \\"
    echo "      -n hitachi-system"
    echo ""
    echo "Option 2: Use Internal Mirror"
    echo "  $ kubectl set image deployment/vsp-one-sds-hspc \\"
    echo "      vsp-one-sds-hspc=registry.internal.com/hitachi/vsp-one-sds-hspc:3.14.0 \\"
    echo "      -n hitachi-system"
    echo ""
    echo "Option 3: Use Alternative Image for Testing"
    echo "  $ kubectl set image deployment/vsp-one-sds-hspc \\"
    echo "      vsp-one-sds-hspc=busybox:latest \\"
    echo "      -n hitachi-system"
    echo ""
    echo "Option 4: Add Image Pull Secret and Retry"
    echo "  1. Create secret with credentials"
    echo "  2. Patch service account"
    echo "  3. Delete pod to force re-pull"
    echo ""
elif [ "$CONTAINER_READY" = "true" ]; then
    log_info "✓ Deployment is healthy!"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Configure Hitachi storage array connection"
    echo "  2. Create StorageClass"
    echo "  3. Deploy test workload"
    echo ""
else
    log_warn "Deployment is in unknown state"
    echo ""
    echo "Check pod logs for more information:"
    echo "  kubectl logs -n hitachi-system $POD_NAME"
    echo ""
fi

# ============================================================================
# 8. SUMMARY
# ============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}8. DIAGNOSTIC SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "Current State:"
echo "  Deployment: $(kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.status.replicas}' 2>/dev/null || echo 'Not found')/1"
echo "  Pod Status: $POD_STATUS"
echo "  Container Ready: $CONTAINER_READY"
echo "  Image: $CONTAINER_IMAGE"
echo ""

echo "Useful Commands:"
echo "  Logs:"
echo "    kubectl logs -n hitachi-system $POD_NAME"
echo ""
echo "  Events:"
echo "    kubectl get events -n hitachi-system --sort-by=.metadata.creationTimestamp"
echo ""
echo "  Full Pod Description:"
echo "    kubectl describe pod $POD_NAME -n hitachi-system"
echo ""
echo "  Update Image:"
echo "    kubectl set image deployment/vsp-one-sds-hspc \\"
echo "      vsp-one-sds-hspc=<new-image> -n hitachi-system"
echo ""
echo "  Restart Pod:"
echo "    kubectl rollout restart deployment/vsp-one-sds-hspc -n hitachi-system"
echo ""

echo "Diagnostic log saved to: $LOG_FILE"
echo ""
