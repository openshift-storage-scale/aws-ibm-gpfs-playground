#!/bin/bash
##############################################################################
# find-hitachi-image.sh
# Purpose: Help locate the correct Hitachi operator image
# Usage: ./find-hitachi-image.sh
##############################################################################

set +e

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

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   Hitachi Image Finder & Validator                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. COMMON HITACHI IMAGE LOCATIONS TO TRY
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Testing Common Hitachi Image Locations${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

VERSIONS=("3.14.0" "3.13.0" "3.12.0" "latest")
REGISTRIES=(
    "docker.io/hitachi/vsp-one-sds-hspc"
    "quay.io/hitachi/vsp-one-sds-hspc"
    "quay.io/openshift-operators/vsp-one-sds-hspc"
    "registry.hitachivantara.com/vsp-one-sds-hspc"
    "registry.connect.redhat.com/hitachi/vsp-one-sds-hspc"
)

echo "Testing image registries..."
echo ""

FOUND_IMAGES=()

for registry in "${REGISTRIES[@]}"; do
    for version in "${VERSIONS[@]}"; do
        IMAGE="${registry}:${version}"
        
        if command -v podman &>/dev/null; then
            echo -n "Testing: $IMAGE ... "
            if podman pull "$IMAGE" &>/dev/null 2>&1; then
                echo -e "${GREEN}✓ FOUND${NC}"
                FOUND_IMAGES+=("$IMAGE")
            else
                echo "✗"
            fi
        elif command -v docker &>/dev/null; then
            echo -n "Testing: $IMAGE ... "
            if docker pull "$IMAGE" &>/dev/null 2>&1; then
                echo -e "${GREEN}✓ FOUND${NC}"
                FOUND_IMAGES+=("$IMAGE")
            else
                echo "✗"
            fi
        fi
    done
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Results${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ ${#FOUND_IMAGES[@]} -eq 0 ]; then
    log_error "No publicly accessible Hitachi images found"
    echo ""
    echo "This is expected for proprietary enterprise software."
    echo ""
    echo "NEXT STEPS:"
    echo ""
    echo "1. Check Hitachi Documentation"
    echo "   - Search for 'Docker image' or 'container image'"
    echo "   - Look for 'VSP One SDS HSPC' operator documentation"
    echo ""
    echo "2. Contact Hitachi Support"
    echo "   - Provide your license/subscription details"
    echo "   - Ask for image registry access (private or mirror)"
    echo "   - Request air-gapped deployment instructions"
    echo ""
    echo "3. Check Company Internal Resources"
    echo "   - Internal image registry mirrors"
    echo "   - Artifact repository (Artifactory, Nexus, etc.)"
    echo "   - Container image mirrors"
    echo ""
    echo "4. Common Hitachi Image Registries"
    echo "   - registry.hitachivantara.com (likely private)"
    echo "   - registry.connect.redhat.com (for certified operators)"
    echo "   - Quay.io (less likely)"
    echo ""
else
    log_info "Found ${#FOUND_IMAGES[@]} accessible image(s):"
    echo ""
    for img in "${FOUND_IMAGES[@]}"; do
        echo "  ✓ $img"
    done
    echo ""
    echo "You can use any of these images with:"
    echo ""
    echo "  kubectl set image deployment/vsp-one-sds-hspc \\"
    echo "    vsp-one-sds-hspc=<image-name> \\"
    echo "    -n hitachi-system"
    echo ""
fi

# ============================================================================
# 2. ALTERNATIVE: MANUAL IMAGE SPECIFICATION
# ============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}If You Have the Correct Image Location${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "If you know the correct image location from Hitachi documentation:"
echo ""
echo "OPTION 1: Update deployment directly"
echo "  $ export KUBECONFIG=/path/to/kubeconfig"
echo "  $ kubectl set image deployment/vsp-one-sds-hspc \\"
echo "      vsp-one-sds-hspc=<correct-image> \\"
echo "      -n hitachi-system"
echo ""
echo "OPTION 2: Update the deployment manifest script"
echo "  Edit: scripts/deployment/deploy-hitachi-operator-disconnected.sh"
echo "  Change this line:"
echo "    image: \$REGISTRY_URL/hitachi/vsp-one-sds-hspc:\$HELM_VERSION"
echo "  To:"
echo "    image: <correct-registry>/vsp-one-sds-hspc:<version>"
echo ""
echo "OPTION 3: Using environment variables"
echo "  $ export REGISTRY_URL=<registry-url>"
echo "  $ export IMAGE_TAG=<image>:<version>"
echo "  $ ./scripts/deployment/deploy-hitachi-operator-disconnected.sh"
echo ""

# ============================================================================
# 3. CREDENTIAL SETUP
# ============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}If Image Requires Authentication${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "If the image registry requires credentials:"
echo ""
echo "Step 1: Create a secret with your credentials"
echo "  $ kubectl create secret docker-registry hitachi-pull-secret \\"
echo "      --docker-server=<registry-url> \\"
echo "      --docker-username=<your-username> \\"
echo "      --docker-password=<your-password> \\"
echo "      --docker-email=<your-email> \\"
echo "      -n hitachi-system"
echo ""
echo "Step 2: Update the service account"
echo "  $ kubectl patch serviceaccount vsp-one-sds-hspc \\"
echo "      -p '{\"imagePullSecrets\": [{\"name\": \"hitachi-pull-secret\"}]}' \\"
echo "      -n hitachi-system"
echo ""
echo "Step 3: Force pod restart to use new credentials"
echo "  $ kubectl delete pod -n hitachi-system -l app=vsp-one-sds-hspc"
echo ""
echo "Step 4: Monitor the restart"
echo "  $ kubectl get pods -n hitachi-system -w"
echo ""

# ============================================================================
# 4. VERIFICATION
# ============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Verify Deployment Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
export KUBECONFIG="$KUBECONFIG_PATH"

if kubectl get deployment vsp-one-sds-hspc -n hitachi-system &>/dev/null; then
    echo "Deployment exists. Current status:"
    echo ""
    kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o wide
    echo ""
    
    POD_NAME=$(kubectl get pods -n hitachi-system -l app=vsp-one-sds-hspc -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$POD_NAME" ]; then
        echo "Pod status:"
        kubectl get pod "$POD_NAME" -n hitachi-system -o wide
        echo ""
        echo "Waiting reason:"
        kubectl get pod "$POD_NAME" -n hitachi-system -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "Not waiting"
        echo ""
    fi
else
    log_warn "No deployment found. Run deployment first:"
    echo "  ./scripts/deployment/deploy-hitachi-operator-disconnected.sh"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo "For more detailed diagnostics, run:"
echo "  ./scripts/troubleshoot-hitachi-deployment.sh"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
