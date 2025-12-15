#!/bin/bash

#############################################################################
# Compare UI Installation vs Script Deployment
#
# This script helps you understand the differences between:
# - Operator installed via OpenShift Console UI
# - Operator deployed via script
#
# Usage:
#   ./scripts/compare-ui-vs-script.sh
#############################################################################

set -e

NAMESPACE="hitachi-system"
OUTPUT_DIR="reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     UI Installation vs Script Deployment Comparison           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

#############################################################################
# 1. Check Subscription (UI indicator)
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. SUBSCRIPTION CHECK (Indicator of UI Installation)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

SUBSCRIPTION=$(kubectl get subscription -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$SUBSCRIPTION" ]; then
    echo -e "${YELLOW}!${NC} No subscription found (likely script-deployed)"
    echo ""
    echo "  ℹ️  Subscriptions are created by OLM (OperatorHub UI installation)"
    echo "  ℹ️  Direct script deployment doesn't use subscriptions"
else
    echo -e "${GREEN}✓${NC} Found subscription: $SUBSCRIPTION"
    echo ""
    echo "  ℹ️  This indicates operator was installed via OpenShift Console UI"
    echo ""
    echo "  Subscription details:"
    kubectl describe subscription "$SUBSCRIPTION" -n "$NAMESPACE" | grep -A 20 "Status:"
fi

echo ""

#############################################################################
# 2. Compare Deployment Details
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. DEPLOYMENT DETAILS COMPARISON${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if ! kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗${NC} Deployment not found!"
    exit 1
fi

echo -e "${CYAN}Image Information:${NC}"
echo ""

IMAGE=$(kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "  Image: $IMAGE"
echo ""

# Analyze image
if [[ "$IMAGE" == *"hitachivantara"* ]]; then
    echo -e "  ${GREEN}✓${NC} Image is from Hitachi registry"
elif [[ "$IMAGE" == *"registry.connect.redhat.com"* ]]; then
    echo -e "  ${GREEN}✓${NC} Image is from Red Hat Connect (certified)"
elif [[ "$IMAGE" == *"quay.io"* ]]; then
    echo -e "  ${GREEN}✓${NC} Image is from Quay.io"
elif [[ "$IMAGE" == *"docker.io"* ]]; then
    echo -e "  ${YELLOW}!${NC} Image is from Docker Hub (may require credentials)"
else
    echo -e "  ${YELLOW}!${NC} Image is from: $(echo $IMAGE | cut -d'/' -f1)"
fi

echo ""
echo -e "${CYAN}Resource Requests/Limits:${NC}"
echo ""

kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o yaml | grep -A 10 "resources:" | head -15

echo ""
echo -e "${CYAN}Environment Variables:${NC}"
echo ""

ENV_COUNT=$(kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | wc -w)
if [ "$ENV_COUNT" -gt 0 ]; then
    echo "  Found $ENV_COUNT environment variables:"
    kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | tr ' ' '\n' | sed 's/^/    - /'
else
    echo "  No environment variables configured"
fi

echo ""
echo -e "${CYAN}Ports:${NC}"
echo ""

PORTS=$(kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].ports}')
if [ -z "$PORTS" ] || [ "$PORTS" == "null" ]; then
    echo "  No ports configured"
else
    echo "  Configured ports:"
    kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].ports}' | jq . | sed 's/^/    /'
fi

echo ""

#############################################################################
# 3. Compare RBAC
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. RBAC COMPARISON${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo -e "${CYAN}Service Accounts:${NC}"
SA=$(kubectl get serviceaccount -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^$")
if [ -z "$SA" ]; then
    echo "  No service accounts found"
else
    echo "  Found:"
    echo "$SA" | sed 's/^/    - /'
fi

echo ""
echo -e "${CYAN}ClusterRoles (containing 'vsp'):${NC}"
CR=$(kubectl get clusterrole -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -i vsp || echo "")
if [ -z "$CR" ]; then
    echo "  No vsp-specific ClusterRoles found"
else
    echo "  Found:"
    echo "$CR" | sed 's/^/    - /'
fi

echo ""
echo -e "${CYAN}ClusterRoleBindings (containing 'vsp'):${NC}"
CRB=$(kubectl get clusterrolebinding -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -i vsp || echo "")
if [ -z "$CRB" ]; then
    echo "  No vsp-specific ClusterRoleBindings found"
else
    echo "  Found:"
    echo "$CRB" | sed 's/^/    - /'
fi

echo ""

#############################################################################
# 4. Pod Status Analysis
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. POD STATUS ANALYSIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
POD_COUNT=$(echo "$PODS" | wc -w)

echo "Found $POD_COUNT pod(s):"
echo ""

for POD in $PODS; do
    STATUS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    READY=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    if [ "$READY" == "True" ]; then
        echo -e "  ${GREEN}✓${NC} $POD ($STATUS)"
    else
        echo -e "  ${RED}✗${NC} $POD ($STATUS)"
        
        # Show waiting reason if not ready
        WAITING=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
        if [ -n "$WAITING" ]; then
            echo -e "     Reason: $WAITING"
        fi
    fi
done

echo ""

#############################################################################
# 5. CSV Information (if UI-installed)
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. CLUSTERSERVICEVERSION (CSV) - UI Installation Indicator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

CSV=$(kubectl get csv -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$CSV" ]; then
    echo -e "${YELLOW}!${NC} No CSV found (likely script-deployed, not UI-installed)"
else
    echo -e "${GREEN}✓${NC} Found CSV: $CSV"
    echo ""
    
    CSV_PHASE=$(kubectl get csv "$CSV" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "  Phase: $CSV_PHASE"
    
    CSV_VERSION=$(kubectl get csv "$CSV" -n "$NAMESPACE" -o jsonpath='{.spec.version}' 2>/dev/null || echo "Unknown")
    echo "  Version: $CSV_VERSION"
fi

echo ""

#############################################################################
# 6. Comparison Summary
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. COMPARISON SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo ""
echo -e "${CYAN}Current Deployment Type:${NC}"
echo ""

if [ -n "$SUBSCRIPTION" ] && [ -n "$CSV" ]; then
    echo -e "  ${GREEN}✓ UI Installation${NC}"
    echo ""
    echo "  Indicators:"
    echo "    - Subscription found: $SUBSCRIPTION"
    echo "    - ClusterServiceVersion found: $CSV"
    echo "    - Operator managed by OLM"
    echo ""
    echo "  Next steps:"
    echo "    1. Run: ./scripts/extract-hitachi-yaml.sh"
    echo "    2. Review: manifests/hitachi-extracted/"
    echo "    3. Update deployment scripts with extracted YAML"
else
    echo -e "  ${YELLOW}⚠️  Script Deployment${NC}"
    echo ""
    echo "  Indicators:"
    echo "    - No Subscription found"
    echo "    - No ClusterServiceVersion found"
    echo "    - Manual/script deployment"
    echo ""
    echo "  Next steps:"
    echo "    1. Check deployment script: scripts/deployment/deploy-hitachi-operator-disconnected.sh"
    echo "    2. Verify image can be pulled: $IMAGE"
    echo "    3. Monitor pod logs if image pull fails"
fi

echo ""

#############################################################################
# 7. Detailed Comparison Export
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}7. EXPORTING DETAILED COMPARISON${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

REPORT="$OUTPUT_DIR/ui-vs-script-comparison-${TIMESTAMP}.txt"

{
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     UI Installation vs Script Deployment Comparison           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Report generated: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "FULL DEPLOYMENT MANIFEST"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    kubectl get deployment vsp-one-sds-hspc -n "$NAMESPACE" -o yaml
    echo ""
    
    if [ -n "$SUBSCRIPTION" ]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "SUBSCRIPTION (UI Indicator)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        kubectl get subscription "$SUBSCRIPTION" -n "$NAMESPACE" -o yaml
        echo ""
    fi
    
    if [ -n "$CSV" ]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "CLUSTERSERVICEVERSION (UI Indicator)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        kubectl get csv "$CSV" -n "$NAMESPACE" -o yaml | head -100
        echo ""
        echo "... (full CSV truncated, use kubectl to view)"
        echo ""
    fi
    
} > "$REPORT"

echo -e "${GREEN}✓${NC} Detailed report saved to: $REPORT"
echo ""

#############################################################################
# 8. Recommendations
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}8. RECOMMENDATIONS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo ""
if [ -z "$IMAGE" ] || [[ "$IMAGE" == *"docker.io"* ]]; then
    echo -e "${YELLOW}⚠️  IMAGE ISSUE DETECTED${NC}"
    echo ""
    echo "Current image: $IMAGE"
    echo ""
    echo "Recommendations:"
    echo "  1. Contact Hitachi support for correct image location"
    echo "  2. Request image registry credentials if needed"
    echo "  3. Update deployment with correct image:"
    echo ""
    echo "     kubectl set image deployment/vsp-one-sds-hspc \\"
    echo "       vsp-one-sds-hspc=<CORRECT-IMAGE> \\"
    echo "       -n $NAMESPACE"
    echo ""
fi

if [ -z "$SUBSCRIPTION" ]; then
    echo -e "${CYAN}To use UI installation in future:${NC}"
    echo "  1. Access OpenShift Console"
    echo "  2. Go to Operators → OperatorHub"
    echo "  3. Search for 'Hitachi VSP One SDS HSPC'"
    echo "  4. Click Install → Select 'hitachi-system' namespace"
    echo ""
fi

echo -e "${CYAN}Always extract YAML after successful installation:${NC}"
echo "  ./scripts/extract-hitachi-yaml.sh"
echo ""

echo -e "${GREEN}✓${NC} Comparison complete!"
echo ""
