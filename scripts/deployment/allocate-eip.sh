#!/bin/bash
##############################################################################
# allocate-eip.sh
# Purpose: Allocate and attach Elastic IP to Hitachi SDS Block management ENI
# Usage: ./allocate-eip.sh <region> <management-eni-id> [profile]
# Example: ./allocate-eip.sh eu-north-1 eni-01fb79c3038d88dcb default
##############################################################################

set -e

REGION="${1:-eu-north-1}"
MANAGEMENT_ENI_ID="${2:-eni-01fb79c3038d88dcb}"
AWS_PROFILE="${3:-default}"

if [ -z "$MANAGEMENT_ENI_ID" ]; then
    echo "Error: Management ENI ID is required"
    echo "Usage: $0 <region> <management-eni-id> [profile]"
    exit 1
fi

echo "=========================================="
echo "Elastic IP Allocation for Hitachi SDS"
echo "=========================================="
echo "Region: $REGION"
echo "Management ENI ID: $MANAGEMENT_ENI_ID"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if ENI already has an EIP attached
echo "[1/4] Checking if ENI already has an Elastic IP..."
EXISTING_EIP=$(aws ec2 describe-addresses \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --filters "Name=network-interface-id,Values=$MANAGEMENT_ENI_ID" \
    --query 'Addresses[*].[AllocationId,PublicIp]' \
    --output text 2>/dev/null)

if [ -n "$EXISTING_EIP" ]; then
    ALLOC_ID=$(echo "$EXISTING_EIP" | awk '{print $1}')
    PUBLIC_IP=$(echo "$EXISTING_EIP" | awk '{print $2}')
    echo "✓ EIP already attached to this ENI"
    echo "  Allocation ID: $ALLOC_ID"
    echo "  Public IP: $PUBLIC_IP"
    echo ""
    echo "Management Console Access:"
    echo "  https://$PUBLIC_IP:8443"
    exit 0
fi

# Step 1: Allocate new Elastic IP
echo "[2/4] Allocating new Elastic IP..."
EIP_ALLOCATION=$(aws ec2 allocate-address \
    --domain vpc \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query '[AllocationId,PublicIp]' \
    --output text 2>/dev/null)

ALLOC_ID=$(echo "$EIP_ALLOCATION" | awk '{print $1}')
PUBLIC_IP=$(echo "$EIP_ALLOCATION" | awk '{print $2}')

if [ -z "$ALLOC_ID" ] || [ -z "$PUBLIC_IP" ]; then
    echo "✗ Failed to allocate Elastic IP"
    exit 1
fi

echo "✓ Elastic IP allocated"
echo "  Allocation ID: $ALLOC_ID"
echo "  Public IP: $PUBLIC_IP"
echo ""

# Step 2: Get account ID for owner-id parameter
echo "[3/4] Getting AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query 'Account' \
    --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo "✗ Failed to get AWS account ID"
    # Release the allocated EIP
    aws ec2 release-address \
        --allocation-id "$ALLOC_ID" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" 2>/dev/null
    exit 1
fi

echo "✓ Account ID: $ACCOUNT_ID"
echo ""

# Step 3: Associate EIP with management ENI
echo "[4/4] Associating Elastic IP to management ENI..."
ASSOC_RESULT=$(aws ec2 associate-address \
    --allocation-id "$ALLOC_ID" \
    --network-interface-id "$MANAGEMENT_ENI_ID" \
    --network-interface-owner-id "$ACCOUNT_ID" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query '[AssociationId,NetworkInterfaceOwnerId]' \
    --output text 2>/dev/null)

if [ -z "$ASSOC_RESULT" ]; then
    echo "✗ Failed to associate Elastic IP"
    # Release the allocated EIP
    aws ec2 release-address \
        --allocation-id "$ALLOC_ID" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" 2>/dev/null
    exit 1
fi

echo "✓ Elastic IP associated successfully"
echo ""

echo "=========================================="
echo "✓ SUCCESS"
echo "=========================================="
echo ""
echo "Management Console Access:"
echo "  URL: https://$PUBLIC_IP:8443"
echo "  Public IP: $PUBLIC_IP"
echo "  Allocation ID: $ALLOC_ID"
echo ""
echo "Credentials stored in:"
echo "  ~/.aws-gpfs-playground/ocp_install_files/sds-block-credentials.env"
echo ""
