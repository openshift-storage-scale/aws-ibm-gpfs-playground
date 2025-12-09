#!/bin/bash

# Hitachi SDS Block Deployment Runner
# Orchestrates the AWS infrastructure deployment

set -e

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KUBECONFIG="${KUBECONFIG:-$HOME/aws-gpfs-playground/ocp_install_files/auth/kubeconfig}"
REGION="${1:-eu-north-1}"
CLUSTER_NAME="${2:-gpfs-levanon-c4qpp}"

echo "=========================================="
echo "Hitachi SDS Block Deployment Runner"
echo "=========================================="
echo ""
echo "Workspace: $WORKSPACE_DIR"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "KUBECONFIG: $KUBECONFIG"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v ansible-playbook >/dev/null 2>&1 || { echo "❌ ansible-playbook not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ aws CLI not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }

if [ ! -f "$KUBECONFIG" ]; then
    echo "❌ KUBECONFIG not found: $KUBECONFIG"
    exit 1
fi

echo "✓ All prerequisites met"
echo ""

# Verify AWS credentials
echo "Verifying AWS credentials..."
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
AWS_IDENTITY=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
echo "✓ AWS Account: $AWS_ACCOUNT"
echo "✓ AWS Identity: $AWS_IDENTITY"
echo ""

# Verify cluster connectivity
echo "Verifying Kubernetes cluster..."
export KUBECONFIG="$KUBECONFIG"
if kubectl cluster-info >/dev/null 2>&1; then
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo "✓ Cluster accessible ($NODE_COUNT nodes)"
else
    echo "❌ Cannot access Kubernetes cluster"
    exit 1
fi
echo ""

# Get VPC ID
echo "Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:cluster_id,Values=$CLUSTER_NAME" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "❌ VPC not found for cluster: $CLUSTER_NAME"
    exit 1
fi
echo "✓ VPC: $VPC_ID"
echo ""

# Check EC2 key pair
echo "Checking EC2 key pair..."
KEY_NAME="nlevanon-key"
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✓ Key pair exists: $KEY_NAME"
else
    echo "⚠️  Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" --query 'KeyMaterial' --output text > /tmp/$KEY_NAME.pem
    chmod 600 /tmp/$KEY_NAME.pem
    echo "✓ Key pair created"
fi
echo ""

# Run the deployment playbook
echo "=========================================="
echo "Starting SDS Block Deployment"
echo "=========================================="
echo ""

cd "$WORKSPACE_DIR"

LOG_FILE="Temp/sds-deploy-$(date +%Y%m%d_%H%M%S).log"

ansible-playbook -i hosts \
    -e "aws_ec2_key_name=$KEY_NAME" \
    -e "aws_vpc_id=$VPC_ID" \
    -e "ocp_region=$REGION" \
    -e "ocp_cluster_name=$CLUSTER_NAME" \
    playbooks/sds-block-deploy.yml 2>&1 | tee "$LOG_FILE"

DEPLOY_STATUS=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ $DEPLOY_STATUS -eq 0 ]; then
    echo "✓ Deployment playbook completed successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor deployment progress:"
    echo "     ./scripts/monitoring/watch-hitachi-deployment.sh $REGION hitachi-sds-block-$CLUSTER_NAME"
    echo ""
    echo "  2. Install Hitachi operators:"
    echo "     make install-hitachi"
    echo ""
    echo "  3. Check deployment status:"
    echo "     ./scripts/monitoring/monitor-hitachi-deployment.sh $REGION hitachi-sds-block-$CLUSTER_NAME"
else
    echo "❌ Deployment playbook failed (exit code: $DEPLOY_STATUS)"
    echo ""
    echo "Check logs: $LOG_FILE"
fi
echo "=========================================="
echo ""
echo "Logs saved to: $LOG_FILE"
