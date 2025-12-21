#!/bin/bash
#
# cleanup-target-groups.sh
#
# Purpose: Clean up orphaned Target Groups from failed OCP deployments
# These ELBv2 resources may remain even after load balancers are deleted
# and can accumulate quota if not cleaned up properly
#
# Usage: ./scripts/cleanup-target-groups.sh [region]
#
# Examples:
#   ./scripts/cleanup-target-groups.sh eu-north-1
#   AWS_REGION=eu-north-1 ./scripts/cleanup-target-groups.sh
#
# Requirements:
#   - AWS CLI v2 with jq
#   - AWS credentials configured (via AWS_PROFILE or default)
#   - Appropriate IAM permissions
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="${1:-${AWS_REGION:-eu-north-1}}"
LOGS_DIR="Logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOGS_DIR}/cleanup-target-groups-${TIMESTAMP}.log"

# Ensure logs directory exists
mkdir -p "${LOGS_DIR}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_header() {
    echo "" | tee -a "${LOG_FILE}"
    echo "════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
    echo "$1" | tee -a "${LOG_FILE}"
    echo "════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
}

# Functions
check_dependencies() {
    local missing=0
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}✗ AWS CLI not found${NC}"
        missing=1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ jq not found${NC}"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        echo -e "${RED}Please install AWS CLI and jq${NC}"
        exit 1
    fi
}

is_target_group_empty() {
    local tg_arn="$1"
    
    local lb_count=$(aws elbv2 describe-target-groups \
        --region "$REGION" \
        --target-group-arns "$tg_arn" \
        --query 'TargetGroups[0].LoadBalancerArns | length' \
        --output json 2>/dev/null || echo 0)
    
    if [ "$lb_count" -eq 0 ]; then
        return 0  # True - target group is not associated
    else
        return 1  # False - target group is associated
    fi
}

delete_target_group() {
    local tg_arn="$1"
    local tg_name=$(echo "$tg_arn" | awk -F'/' '{print $NF}')
    
    log "INFO" "Deleting Target Group: $tg_name"
    
    if aws elbv2 delete-target-group \
        --region "$REGION" \
        --target-group-arn "$tg_arn" \
        --output json >> "${LOG_FILE}" 2>&1; then
        log "INFO" "✓ Target Group deleted: $tg_name"
        return 0
    else
        log "WARN" "✗ Failed to delete Target Group: $tg_name"
        return 1
    fi
}

cleanup_orphaned_target_groups_in_vpc() {
    local vpc_id="$1"
    
    log "INFO" "Cleaning up Target Groups in VPC: $vpc_id"
    
    # Get all target groups in VPC
    local target_groups=$(aws elbv2 describe-target-groups \
        --region "$REGION" \
        --query "TargetGroups[?VpcId=='$vpc_id'].{Arn:TargetGroupArn,Name:TargetGroupName,Type:TargetType}" \
        --output json)
    
    local count=$(echo "$target_groups" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        log "INFO" "No Target Groups found in VPC: $vpc_id"
        return 0
    fi
    
    log "INFO" "Found $count Target Group(s) in VPC"
    
    local deleted_count=0
    local associated_count=0
    local failed_count=0
    
    echo "$target_groups" | jq -r '.[] | @base64' | while read -r encoded_item; do
        local item=$(echo "$encoded_item" | base64 -d)
        local tg_arn=$(echo "$item" | jq -r '.Arn')
        local tg_name=$(echo "$item" | jq -r '.Name')
        local tg_type=$(echo "$item" | jq -r '.Type')
        
        log "INFO" ""
        log "INFO" "Processing Target Group: $tg_name (Type: $tg_type)"
        
        # Check if target group is associated with any load balancer
        if is_target_group_empty "$tg_arn"; then
            log "INFO" "  Target Group is not associated with any Load Balancer"
            if delete_target_group "$tg_arn"; then
                deleted_count=$((deleted_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        else
            log "INFO" "  ⚠ Target Group is associated with a Load Balancer - skipping"
            associated_count=$((associated_count + 1))
        fi
    done
    
    log "INFO" "Target Group cleanup summary for VPC $vpc_id:"
    log "INFO" "  ✓ Successfully deleted: $deleted_count"
    log "INFO" "  ⚠ Associated (skipped): $associated_count"
    log "INFO" "  ✗ Failed: $failed_count"
    
    return 0
}

cleanup_all_target_groups() {
    log_header "TARGET GROUP CLEANUP"
    log "INFO" "Region: $REGION"
    log "INFO" "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Get all VPCs (excluding default)
    local vpcs=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=isDefault,Values=false" \
        --query 'Vpcs[*].VpcId' \
        --output json)
    
    local vpc_count=$(echo "$vpcs" | jq 'length')
    
    log "INFO" "Found $vpc_count non-default VPC(s)"
    
    if [ "$vpc_count" -eq 0 ]; then
        log "INFO" "No VPCs to clean up"
        return 0
    fi
    
    echo "$vpcs" | jq -r '.[]' | while read -r vpc_id; do
        local tg_count=$(aws elbv2 describe-target-groups \
            --region "$REGION" \
            --query "TargetGroups[?VpcId=='$vpc_id'] | length" \
            --output json)
        
        if [ "$tg_count" -gt 0 ]; then
            log "INFO" ""
            log "INFO" "VPC: $vpc_id (has $tg_count Target Group(s))"
            cleanup_orphaned_target_groups_in_vpc "$vpc_id"
        fi
    done
}

# Main execution
main() {
    log "INFO" "Target Group Cleanup Script Started"
    log "INFO" "Region: $REGION"
    log "INFO" "Log file: $LOG_FILE"
    
    check_dependencies
    
    cleanup_all_target_groups
    
    log_header "CLEANUP COMPLETE"
    log "INFO" "Target Group cleanup finished at $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${GREEN}✓ Target Group cleanup complete${NC}"
    echo "Log file: ${LOG_FILE}"
}

main "$@"
