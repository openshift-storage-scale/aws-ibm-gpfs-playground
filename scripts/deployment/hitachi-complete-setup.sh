#!/bin/bash
##############################################################################
# hitachi-complete-setup.sh
# Purpose: Complete end-to-end Hitachi SDS setup orchestration
# Usage: ./hitachi-complete-setup.sh [region] [cluster-name] [profile]
# Example: ./hitachi-complete-setup.sh eu-north-1 gpfs-levanon-c4qpp default
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${1:-eu-north-1}"
CLUSTER_NAME="${2:-gpfs-levanon-c4qpp}"
AWS_PROFILE="${3:-default}"
KUBECONFIG_PATH="${HOME}/aws-gpfs-playground/ocp_install_files/auth/kubeconfig"
STACK_NAME="hitachi-sds-block-${CLUSTER_NAME}"
MANAGEMENT_ENI_ID="${MANAGEMENT_ENI_ID:-eni-01fb79c3038d88dcb}"
NAMESPACE="${NAMESPACE:-hitachi-system}"
HELM_VERSION="${HELM_VERSION:-3.14.0}"

export KUBECONFIG="$KUBECONFIG_PATH"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Hitachi SDS Complete Setup Orchestration                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME"
echo "  Stack: $STACK_NAME"
echo "  KUBECONFIG: $KUBECONFIG_PATH"
echo "  AWS Profile: $AWS_PROFILE"
echo ""

# Verify prerequisites
echo "[PHASE 0] Verifying prerequisites..."
echo ""

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "✗ KUBECONFIG not found at $KUBECONFIG_PATH"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "✗ kubectl not found in PATH"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "✗ helm not found in PATH"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "✗ aws CLI not found in PATH"
    exit 1
fi

echo "✓ All prerequisites met"
echo ""

# Phase 1: Verify infrastructure
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ PHASE 1: Verify CloudFormation Infrastructure             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" != "CREATE_COMPLETE" ]; then
    echo "✗ CloudFormation stack status: $STACK_STATUS"
    echo ""
    echo "Please deploy infrastructure first:"
    echo "  ansible-playbook -i hosts playbooks/sds-block-deploy.yml"
    exit 1
fi

echo "✓ CloudFormation stack is ready"
echo ""

# Phase 2: Verify cluster connectivity
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ PHASE 2: Verify OCP Cluster Connectivity                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if ! kubectl cluster-info &>/dev/null; then
    echo "✗ Cannot connect to cluster"
    echo ""
    echo "Check KUBECONFIG:"
    echo "  export KUBECONFIG=$KUBECONFIG_PATH"
    exit 1
fi

NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "✓ Cluster connected with $NODES nodes"
echo ""

# Phase 3: Prepare namespaces
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ PHASE 3: Prepare Kubernetes Namespaces                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

"$SCRIPT_DIR/prepare-namespaces.sh" "$KUBECONFIG_PATH" "$NAMESPACE"
echo ""

# Phase 4: Deploy Hitachi HSPC operator
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ PHASE 4: Deploy Hitachi HSPC Operator                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

"$SCRIPT_DIR/deploy-hitachi-operator.sh" "$KUBECONFIG_PATH" "$NAMESPACE" "$HELM_VERSION"
echo ""

# Phase 5: Allocate Elastic IP
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ PHASE 5: Allocate Elastic IP for Management Console      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

"$SCRIPT_DIR/allocate-eip.sh" "$REGION" "$MANAGEMENT_ENI_ID" "$AWS_PROFILE"
echo ""

# Final summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║ ✓ SETUP COMPLETE                                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo "Next steps:"
echo ""
echo "1. Access Hitachi SDS Management Console:"
echo "   - Check the Elastic IP output above"
echo "   - Navigate to https://<PUBLIC_IP>:8443"
echo ""
echo "2. Monitor operator deployment:"
echo "   export KUBECONFIG=$KUBECONFIG_PATH"
echo "   kubectl get pods -n $NAMESPACE -l app=vsp-one-sds-hspc -w"
echo ""
echo "3. Create storage configuration:"
echo "   kubectl apply -f config/hitachi/storage/"
echo ""
echo "4. Verify integration:"
echo "   kubectl get storageclass"
echo "   kubectl get volumesnapshotclass"
echo ""
