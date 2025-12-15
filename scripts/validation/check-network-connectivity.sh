#!/bin/bash
##############################################################################
# check-network-connectivity.sh
# Purpose: Diagnose network connectivity issues from the cluster
# Usage: ./check-network-connectivity.sh
##############################################################################

set +e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../" && pwd)"
LOG_DIR="${PROJECT_ROOT}/Logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Setup logging
LOG_FILE="${LOG_DIR}/check-network-connectivity-$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
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

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Cluster Network Connectivity Diagnostic${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 1. Check kubectl connectivity
echo -e "${YELLOW}[1] Kubernetes Connectivity${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓${NC} kubectl can connect to cluster"
    kubectl cluster-info | head -2
else
    echo -e "${RED}✗${NC} Cannot connect to cluster"
    exit 1
fi
echo ""

# 2. Check if any pod can access external internet
echo -e "${YELLOW}[2] External Internet Connectivity${NC}"
kubectl run -q -it --rm network-test --image=curlimages/curl --restart=Never --timeout=10s -- \
    curl -s -m 5 -o /dev/null -w "HTTP Status: %{http_code}\n" https://cdn.hitachivantara.com/charts/hitachi 2>/dev/null && \
    echo -e "${GREEN}✓${NC} Can reach cdn.hitachivantara.com" || \
    echo -e "${RED}✗${NC} Cannot reach cdn.hitachivantara.com"
echo ""

# 3. Check DNS resolution
echo -e "${YELLOW}[3] DNS Resolution${NC}"
kubectl run -q -it --rm network-test --image=busybox --restart=Never --timeout=10s -- \
    nslookup cdn.hitachivantara.com 2>&1 | grep -q "Address" && \
    echo -e "${GREEN}✓${NC} DNS can resolve cdn.hitachivantara.com" || \
    echo -e "${RED}✗${NC} DNS cannot resolve cdn.hitachivantara.com"
echo ""

# 4. Check Docker Hub connectivity
echo -e "${YELLOW}[4] Docker Hub Connectivity${NC}"
kubectl run -q -it --rm network-test --image=curlimages/curl --restart=Never --timeout=10s -- \
    curl -s -m 5 -o /dev/null -w "HTTP Status: %{http_code}\n" https://registry.hub.docker.com/v2/ 2>/dev/null && \
    echo -e "${GREEN}✓${NC} Can reach Docker Hub" || \
    echo -e "${RED}✗${NC} Cannot reach Docker Hub"
echo ""

# 5. Check Quay.io connectivity
echo -e "${YELLOW}[5] Quay.io Connectivity${NC}"
kubectl run -q -it --rm network-test --image=curlimages/curl --restart=Never --timeout=10s -- \
    curl -s -m 5 -o /dev/null -w "HTTP Status: %{http_code}\n" https://quay.io/api/v1/ 2>/dev/null && \
    echo -e "${GREEN}✓${NC} Can reach Quay.io" || \
    echo -e "${RED}✗${NC} Cannot reach Quay.io"
echo ""

# 6. Check NetworkPolicies
echo -e "${YELLOW}[6] Network Policies${NC}"
NETPOLS=$(kubectl get networkpolicies --all-namespaces 2>/dev/null | wc -l)
if [ "$NETPOLS" -gt 1 ]; then
    echo -e "${YELLOW}!${NC} Network policies found: $(($NETPOLS - 1))"
    kubectl get networkpolicies --all-namespaces
else
    echo -e "${GREEN}✓${NC} No NetworkPolicies restricting traffic"
fi
echo ""

# 7. Check egress policies
echo -e "${YELLOW}[7] Firewall/Egress Rules${NC}"
echo "Checking for restrictive policies..."
POLICIES=$(kubectl get networkpolicies --all-namespaces -o json | \
    jq '.items[] | select(.spec.policyTypes[] | contains("Egress")) | .metadata.name' 2>/dev/null | wc -l)

if [ "$POLICIES" -gt 0 ]; then
    echo -e "${YELLOW}!${NC} Found egress policies that may restrict external traffic"
    kubectl get networkpolicies --all-namespaces -o json | \
        jq '.items[] | select(.spec.policyTypes[] | contains("Egress")) | {name: .metadata.name, namespace: .metadata.namespace}'
else
    echo -e "${GREEN}✓${NC} No egress policies found"
fi
echo ""

# 8. Check if running in disconnected mode
echo -e "${YELLOW}[8] Environment Detection${NC}"
IS_AIRGAPPED=true

# Test multiple external URLs
for url in "https://cdn.hitachivantara.com" "https://docker.io" "https://quay.io" "https://github.com"; do
    kubectl run -q -it --rm network-test --image=curlimages/curl --restart=Never --timeout=5s -- \
        curl -s -m 3 -o /dev/null "$url" 2>/dev/null && IS_AIRGAPPED=false && break
done

if [ "$IS_AIRGAPPED" = "true" ]; then
    echo -e "${RED}✗${NC} Environment appears to be AIR-GAPPED (disconnected)"
    echo "   Solution: Use disconnected deployment script"
else
    echo -e "${GREEN}✓${NC} Environment has external internet access"
    echo "   Solution: Standard deployment should work"
fi
echo ""

# Summary and recommendations
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Recommendations${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$IS_AIRGAPPED" = "true" ]; then
    echo "Your cluster appears to be in a disconnected/air-gapped environment."
    echo ""
    echo "Recommended actions:"
    echo "1. Use: ./deploy-hitachi-operator-disconnected.sh"
    echo "2. Or pre-download charts on external machine and transfer"
    echo "3. Or set up internal container registry mirror"
    echo ""
    echo "Documentation: docs/HITACHI_NETWORK_TROUBLESHOOTING.md"
else
    echo "Your cluster has external internet access."
    echo ""
    echo "If deployment still fails:"
    echo "1. Check if specific URLs are blocked: https://cdn.hitachivantara.com"
    echo "2. Verify Helm repositories:"
    echo "   helm repo list"
    echo "3. Try adding repo with verbose output:"
    echo "   helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi -v 10"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo "Diagnostic complete"
echo -e "${BLUE}================================================${NC}"
