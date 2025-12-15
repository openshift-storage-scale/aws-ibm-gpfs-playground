#!/bin/bash

#############################################################################
# Extract Hitachi Operator YAML from Deployed Resources
#
# This script extracts YAML from an installed Hitachi operator deployment
# so you can version control and replicate the exact configuration
#
# Usage:
#   ./scripts/extract-hitachi-yaml.sh [--all]
#
# Examples:
#   ./scripts/extract-hitachi-yaml.sh                    # Extract hitachi-system namespace
#   ./scripts/extract-hitachi-yaml.sh --all              # Extract all Hitachi resources cluster-wide
#############################################################################

set -e

NAMESPACE="hitachi-system"
EXTRACT_DIR="manifests/hitachi-extracted"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Hitachi Operator YAML Extraction Tool                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create extraction directory
mkdir -p "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR/manifests"
mkdir -p "$EXTRACT_DIR/subscriptions"
mkdir -p "$EXTRACT_DIR/csvs"
mkdir -p "$EXTRACT_DIR/deployments"
mkdir -p "$EXTRACT_DIR/rbac"

echo -e "${YELLOW}[INFO]${NC} Extraction directory: $EXTRACT_DIR"
echo ""

#############################################################################
# 1. Extract Subscription (if operator installed via OLM)
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. EXTRACTING SUBSCRIPTIONS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if kubectl get subscription -n "$NAMESPACE" 2>/dev/null | grep -q vsp; then
    echo -e "${GREEN}✓${NC} Found subscription in $NAMESPACE"
    kubectl get subscription -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/subscriptions/hitachi-subscription-${TIMESTAMP}.yaml"
    kubectl get subscription -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/subscriptions/hitachi-subscription-LATEST.yaml"
    echo -e "${GREEN}✓${NC} Saved: subscriptions/hitachi-subscription-LATEST.yaml"
else
    echo -e "${YELLOW}!${NC} No subscription found (operator may not be installed via OLM)"
fi

#############################################################################
# 2. Extract ClusterServiceVersion (CSV)
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. EXTRACTING CLUSTERSERVICEVERSIONS (CSV)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if kubectl get csv -n "$NAMESPACE" 2>/dev/null | grep -q vsp; then
    echo -e "${GREEN}✓${NC} Found CSV in $NAMESPACE"
    kubectl get csv -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/csvs/hitachi-csv-${TIMESTAMP}.yaml"
    kubectl get csv -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/csvs/hitachi-csv-LATEST.yaml"
    echo -e "${GREEN}✓${NC} Saved: csvs/hitachi-csv-LATEST.yaml"
else
    echo -e "${YELLOW}!${NC} No CSV found"
fi

#############################################################################
# 3. Extract Deployments
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. EXTRACTING DEPLOYMENTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

DEPLOYMENTS=$(kubectl get deployment -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$DEPLOYMENTS" ]; then
    echo -e "${YELLOW}!${NC} No deployments found in $NAMESPACE"
else
    for DEPLOY in $DEPLOYMENTS; do
        if [[ "$DEPLOY" == *"hitachi"* ]] || [[ "$DEPLOY" == *"vsp"* ]] || [[ "$DEPLOY" == *"hspc"* ]]; then
            echo -e "${GREEN}✓${NC} Found deployment: $DEPLOY"
            kubectl get deployment "$DEPLOY" -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/deployments/${DEPLOY}-${TIMESTAMP}.yaml"
            kubectl get deployment "$DEPLOY" -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/deployments/${DEPLOY}-LATEST.yaml"
            echo -e "${GREEN}✓${NC} Saved: deployments/${DEPLOY}-LATEST.yaml"
        fi
    done
fi

#############################################################################
# 4. Extract RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. EXTRACTING RBAC (ServiceAccount, Roles, Bindings)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# ServiceAccounts
SA_COUNT=$(kubectl get serviceaccount -n "$NAMESPACE" 2>/dev/null | wc -l)
if [ "$SA_COUNT" -gt 1 ]; then
    echo -e "${GREEN}✓${NC} Found $(($SA_COUNT - 1)) service accounts"
    kubectl get serviceaccount -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/rbac/serviceaccounts-${TIMESTAMP}.yaml"
    kubectl get serviceaccount -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/rbac/serviceaccounts-LATEST.yaml"
    echo -e "${GREEN}✓${NC} Saved: rbac/serviceaccounts-LATEST.yaml"
fi

# ClusterRoles
CR_COUNT=$(kubectl get clusterrole -n "$NAMESPACE" 2>/dev/null | grep vsp | wc -l)
if [ "$CR_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $CR_COUNT cluster roles"
    kubectl get clusterrole -n "$NAMESPACE" -o yaml 2>/dev/null | grep -A 100 "name: vsp" | head -100 > "$EXTRACT_DIR/rbac/clusterroles-${TIMESTAMP}.yaml" || true
    kubectl get clusterrole -n "$NAMESPACE" -o yaml 2>/dev/null | grep -A 100 "name: vsp" | head -100 > "$EXTRACT_DIR/rbac/clusterroles-LATEST.yaml" || true
    echo -e "${GREEN}✓${NC} Saved: rbac/clusterroles-LATEST.yaml"
fi

# ClusterRoleBindings
CRB_COUNT=$(kubectl get clusterrolebinding 2>/dev/null | grep vsp | wc -l)
if [ "$CRB_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $CRB_COUNT cluster role bindings"
    kubectl get clusterrolebinding -o yaml 2>/dev/null | grep -A 100 "name: vsp" | head -100 > "$EXTRACT_DIR/rbac/clusterrolebindings-${TIMESTAMP}.yaml" || true
    kubectl get clusterrolebinding -o yaml 2>/dev/null | grep -A 100 "name: vsp" | head -100 > "$EXTRACT_DIR/rbac/clusterrolebindings-LATEST.yaml" || true
    echo -e "${GREEN}✓${NC} Saved: rbac/clusterrolebindings-LATEST.yaml"
fi

#############################################################################
# 5. Extract Custom Resources (if any)
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. CHECKING FOR CUSTOM RESOURCES${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Get all CRDs in hitachi-system namespace
CRDS=$(kubectl get crds 2>/dev/null | grep -i hitachi || echo "")

if [ -z "$CRDS" ]; then
    echo -e "${YELLOW}!${NC} No Hitachi custom resource definitions found"
else
    echo -e "${GREEN}✓${NC} Found Hitachi CRDs"
    echo "$CRDS"
    
    # Extract each CRD
    for CRD in $CRDS; do
        echo -e "  Extracting $CRD..."
        kubectl get "$CRD" -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/${CRD}-${TIMESTAMP}.yaml" 2>/dev/null || true
        kubectl get "$CRD" -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/${CRD}-LATEST.yaml" 2>/dev/null || true
    done
fi

#############################################################################
# 6. Extract Entire Namespace
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. EXTRACTING ENTIRE NAMESPACE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}[INFO]${NC} Exporting all resources from namespace: $NAMESPACE"
kubectl get all -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/namespace-all-${TIMESTAMP}.yaml"
kubectl get all -n "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/namespace-all-LATEST.yaml"
echo -e "${GREEN}✓${NC} Saved: manifests/namespace-all-LATEST.yaml"

# Also export the namespace object itself
kubectl get namespace "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/namespace-object-${TIMESTAMP}.yaml" 2>/dev/null || true
kubectl get namespace "$NAMESPACE" -o yaml > "$EXTRACT_DIR/manifests/namespace-object-LATEST.yaml" 2>/dev/null || true

#############################################################################
# 7. Summary
#############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}EXTRACTION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}Extracted files:${NC}"
echo ""

if [ -d "$EXTRACT_DIR" ]; then
    find "$EXTRACT_DIR" -type f -name "*-LATEST.yaml" | while read -r file; do
        SIZE=$(wc -l < "$file")
        echo "  ✓ $(basename "$file") ($SIZE lines)"
    done
fi

echo ""
echo -e "${YELLOW}To use these manifests in your deployment script:${NC}"
echo ""
echo "  1. Review the extracted YAML files:"
echo "     less $EXTRACT_DIR/manifests/namespace-all-LATEST.yaml"
echo ""
echo "  2. Copy relevant sections to your deployment script:"
echo "     cat $EXTRACT_DIR/deployments/*-LATEST.yaml"
echo ""
echo "  3. Version control the manifests:"
echo "     git add $EXTRACT_DIR/"
echo "     git commit -m 'Extract Hitachi operator manifests from UI deployment'"
echo ""

#############################################################################
# 8. Create a consolidated manifest file
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}CREATING CONSOLIDATED MANIFEST${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

CONSOLIDATED="$EXTRACT_DIR/hitachi-operator-consolidated-${TIMESTAMP}.yaml"
CONSOLIDATED_LATEST="$EXTRACT_DIR/hitachi-operator-consolidated-LATEST.yaml"

{
    echo "# Hitachi VSP One SDS HSPC Operator - Consolidated Manifest"
    echo "# Extracted: $(date)"
    echo "# Source: OpenShift cluster deployment"
    echo ""
    echo "---"
    echo "# Namespace"
    echo "---"
    if [ -f "$EXTRACT_DIR/manifests/namespace-object-LATEST.yaml" ]; then
        cat "$EXTRACT_DIR/manifests/namespace-object-LATEST.yaml"
    fi
    
    echo ""
    echo "---"
    echo "# RBAC"
    echo "---"
    if [ -f "$EXTRACT_DIR/rbac/serviceaccounts-LATEST.yaml" ]; then
        cat "$EXTRACT_DIR/rbac/serviceaccounts-LATEST.yaml"
    fi
    
    echo ""
    echo "---"
    echo "# Deployments"
    echo "---"
    if [ -f "$EXTRACT_DIR/deployments"/*-LATEST.yaml ]; then
        cat "$EXTRACT_DIR/deployments"/*-LATEST.yaml 2>/dev/null || true
    fi
    
    echo ""
    echo "---"
    echo "# Subscriptions (if installed via OLM)"
    echo "---"
    if [ -f "$EXTRACT_DIR/subscriptions/hitachi-subscription-LATEST.yaml" ]; then
        cat "$EXTRACT_DIR/subscriptions/hitachi-subscription-LATEST.yaml"
    fi
} > "$CONSOLIDATED_LATEST"

cp "$CONSOLIDATED_LATEST" "$CONSOLIDATED"

echo -e "${GREEN}✓${NC} Created consolidated manifest: $(basename "$CONSOLIDATED_LATEST")"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Review the consolidated manifest:"
echo "     cat $CONSOLIDATED_LATEST"
echo ""
echo "  2. Update deploy-hitachi-operator.sh with exact image and configuration:"
echo "     grep -E 'image:|containers:' $CONSOLIDATED_LATEST"
echo ""
echo "  3. Commit changes:"
echo "     git add $EXTRACT_DIR/"
echo ""

echo ""
echo -e "${GREEN}✓${NC} Extraction complete!"
echo ""
