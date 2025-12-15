#!/bin/bash

#############################################################################
# Force Cleanup Hitachi SDS Block AWS Resources
#
# This script forcefully removes stuck Hitachi SDS Block CloudFormation
# stacks and related AWS resources when normal deletion fails.
#
# Usage:
#   ./scripts/cleanup-hitachi-sds-force.sh [--cluster-name NAME] [--region REGION] [--dry-run]
#
# Examples:
#   ./scripts/cleanup-hitachi-sds-force.sh
#   ./scripts/cleanup-hitachi-sds-force.sh --cluster-name my-cluster --region eu-north-1
#   ./scripts/cleanup-hitachi-sds-force.sh --dry-run  # Show what would be deleted
#
#############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
CLUSTER_NAME="${CLUSTER_NAME:-gpfs-levanon-c4qpp}"
REGION="${REGION:-eu-north-1}"
DRY_RUN=false
AWS_PROFILE="${AWS_PROFILE:-default}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Force Cleanup Hitachi SDS Block AWS Resources             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo "  Dry Run: $DRY_RUN"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠️  DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

#############################################################################
# 1. Find and Delete CloudFormation Stack
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. CloudFormation Stack${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

STACK_NAME="hitachi-sds-block-${CLUSTER_NAME}"

echo "Looking for stack: $STACK_NAME"

STACK_EXISTS=$(aws cloudformation describe-stacks \
    --profile "$AWS_PROFILE" \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_EXISTS" != "DOES_NOT_EXIST" ]; then
    echo -e "${YELLOW}Found stack: $STACK_NAME (Status: $STACK_EXISTS)${NC}"
    
    if [ "$DRY_RUN" = false ]; then
        echo "Deleting CloudFormation stack..."
        aws cloudformation delete-stack \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --stack-name "$STACK_NAME"
        
        echo "Waiting for stack deletion..."
        aws cloudformation wait stack-delete-complete \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --stack-name "$STACK_NAME" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Stack deleted${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would delete: $STACK_NAME${NC}"
    fi
else
    echo -e "${GREEN}✓ Stack not found (already deleted)${NC}"
fi

echo ""

#############################################################################
# 2. Find and Terminate EC2 Instances
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. EC2 Instances${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Looking for instances: hitachi-sds-block-*"

INSTANCES=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=hitachi-sds-block*" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name}' \
    --output json)

INSTANCE_COUNT=$(echo "$INSTANCES" | jq '[.[].[] | select(.ID != null)] | length')

if [ "$INSTANCE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Found $INSTANCE_COUNT instance(s):${NC}"
    echo "$INSTANCES" | jq '.[][] | select(.ID != null)'
    
    if [ "$DRY_RUN" = false ]; then
        INSTANCE_IDS=$(echo "$INSTANCES" | jq -r '.[][] | select(.ID != null) | .ID' | tr '\n' ' ')
        
        echo "Terminating instances: $INSTANCE_IDS"
        aws ec2 terminate-instances \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --instance-ids $INSTANCE_IDS
        
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --instance-ids $INSTANCE_IDS
        
        echo -e "${GREEN}✓ Instances terminated${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would terminate these instances${NC}"
    fi
else
    echo -e "${GREEN}✓ No instances found${NC}"
fi

echo ""

#############################################################################
# 3. Find and Delete Unattached Volumes
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. EBS Volumes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Looking for volumes: hitachi-sds-block-*"

VOLUMES=$(aws ec2 describe-volumes \
    --profile "$AWS_PROFILE" \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=hitachi-sds-block*" \
    --query 'Volumes[*].{ID:VolumeId,Name:Tags[?Key==`Name`]|[0].Value,State:State,Size:Size,Attachments:Attachments}' \
    --output json)

VOLUME_COUNT=$(echo "$VOLUMES" | jq '[.[] | select(.ID != null)] | length')

if [ "$VOLUME_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Found $VOLUME_COUNT volume(s):${NC}"
    echo "$VOLUMES" | jq '.[] | select(.ID != null)'
    
    if [ "$DRY_RUN" = false ]; then
        # First, detach any attached volumes
        ATTACHED_VOLUMES=$(echo "$VOLUMES" | jq -r '.[] | select(.Attachments | length > 0) | .ID')
        
        if [ ! -z "$ATTACHED_VOLUMES" ]; then
            echo "Detaching attached volumes..."
            for VOL_ID in $ATTACHED_VOLUMES; do
                echo "  Detaching $VOL_ID..."
                aws ec2 detach-volume \
                    --profile "$AWS_PROFILE" \
                    --region "$REGION" \
                    --volume-id "$VOL_ID" || true
            done
            
            echo "Waiting for volumes to detach..."
            sleep 10
        fi
        
        # Now delete all volumes
        VOLUME_IDS=$(echo "$VOLUMES" | jq -r '.[] | select(.ID != null) | .ID')
        
        echo "Deleting volumes..."
        for VOL_ID in $VOLUME_IDS; do
            echo "  Deleting $VOL_ID..."
            aws ec2 delete-volume \
                --profile "$AWS_PROFILE" \
                --region "$REGION" \
                --volume-id "$VOL_ID" || true
        done
        
        echo -e "${GREEN}✓ Volumes deleted${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would delete these volumes${NC}"
    fi
else
    echo -e "${GREEN}✓ No volumes found${NC}"
fi

echo ""

#############################################################################
# 4. Find and Delete Security Groups
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. Security Groups${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Looking for security groups: *hitachi-sds-block* or *SDS*"

SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --profile "$AWS_PROFILE" \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=*hitachi-sds-block*,*SDS*" \
    --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName,Tags:Tags}' \
    --output json 2>/dev/null || echo "[]")

SG_COUNT=$(echo "$SECURITY_GROUPS" | jq '[.[] | select(.ID != null)] | length')

if [ "$SG_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Found $SG_COUNT security group(s):${NC}"
    echo "$SECURITY_GROUPS" | jq '.[] | select(.ID != null)'
    
    if [ "$DRY_RUN" = false ]; then
        SG_IDS=$(echo "$SECURITY_GROUPS" | jq -r '.[] | select(.ID != null) | .ID')
        
        echo "Deleting security groups..."
        for SG_ID in $SG_IDS; do
            echo "  Deleting $SG_ID..."
            aws ec2 delete-security-group \
                --profile "$AWS_PROFILE" \
                --region "$REGION" \
                --group-id "$SG_ID" || true
        done
        
        echo -e "${GREEN}✓ Security groups deleted${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would delete these security groups${NC}"
    fi
else
    echo -e "${GREEN}✓ No security groups found${NC}"
fi

echo ""

#############################################################################
# 5. Find and Delete Network Interfaces
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. Network Interfaces${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Looking for network interfaces: *hitachi-sds-block* or *SDS*"

NETWORK_INTERFACES=$(aws ec2 describe-network-interfaces \
    --profile "$AWS_PROFILE" \
    --region "$REGION" \
    --query 'NetworkInterfaces[*].{ID:NetworkInterfaceId,Description:Description,Attachment:Attachment}' \
    --output json 2>/dev/null || echo "[]")

# Filter for Hitachi SDS related
ENI_COUNT=$(echo "$NETWORK_INTERFACES" | jq '[.[] | select(.Description != null and (.Description | contains("SDSBlock") or contains("hitachi")))] | length')

if [ "$ENI_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Found $ENI_COUNT network interface(s):${NC}"
    echo "$NETWORK_INTERFACES" | jq '.[] | select(.Description != null and (.Description | contains("SDSBlock") or contains("hitachi")))'
    
    if [ "$DRY_RUN" = false ]; then
        ENI_IDS=$(echo "$NETWORK_INTERFACES" | jq -r '.[] | select(.Description != null and (.Description | contains("SDSBlock") or contains("hitachi"))) | .ID')
        
        echo "Deleting network interfaces..."
        for ENI_ID in $ENI_IDS; do
            # First detach if still attached
            if aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --profile "$AWS_PROFILE" --region "$REGION" | grep -q "ATTACHMENT"; then
                echo "  Detaching $ENI_ID..."
                ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
                    --network-interface-ids "$ENI_ID" \
                    --profile "$AWS_PROFILE" \
                    --region "$REGION" \
                    --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                    --output text)
                
                if [ ! -z "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
                    aws ec2 detach-network-interface \
                        --profile "$AWS_PROFILE" \
                        --region "$REGION" \
                        --attachment-id "$ATTACHMENT_ID" || true
                    sleep 2
                fi
            fi
            
            echo "  Deleting $ENI_ID..."
            aws ec2 delete-network-interface \
                --profile "$AWS_PROFILE" \
                --region "$REGION" \
                --network-interface-id "$ENI_ID" || true
        done
        
        echo -e "${GREEN}✓ Network interfaces deleted${NC}"
    else
        echo -e "${YELLOW}[DRY RUN] Would delete these network interfaces${NC}"
    fi
else
    echo -e "${GREEN}✓ No network interfaces found${NC}"
fi

echo ""

#############################################################################
# Summary
#############################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}CLEANUP SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
    echo ""
    echo "To actually perform the cleanup, run:"
    echo "  ./scripts/cleanup-hitachi-sds-force.sh --cluster-name $CLUSTER_NAME --region $REGION"
else
    echo -e "${GREEN}✓ Cleanup completed successfully${NC}"
    echo ""
    echo "Verification:"
    echo "  1. Check AWS console to verify resources are deleted"
    echo "  2. Monitor CloudFormation for stack deletion"
    echo "  3. Then try: make destroy"
fi

echo ""
