#!/bin/bash
#
# cleanup-load-balancers.sh
#
# Purpose: Clean up orphaned Load Balancers (ALB/NLB) from failed OCP deployments
# These resources must be cleaned up before their associated target groups can be deleted
#
# Usage: ./scripts/cleanup-load-balancers.sh [region]
#
# Examples:
#   ./scripts/cleanup-load-balancers.sh eu-north-1
#   AWS_REGION=eu-north-1 ./scripts/cleanup-load-balancers.sh
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
LOG_FILE="${LOGS_DIR}/cleanup-load-balancers-${TIMESTAMP}.log"

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

delete_load_balancer() {
    local lb_arn="$1"
    local lb_name=$(echo "$lb_arn" | awk -F'/' '{print $(NF-1)"/"$NF}')
    
    log "INFO" "Deleting Load Balancer: $lb_name"
    
    if aws elbv2 delete-load-balancer \
        --region "$REGION" \
        --load-balancer-arn "$lb_arn" \
        --output json >> "${LOG_FILE}" 2>&1; then
        log "INFO" "✓ Load Balancer deleted: $lb_name"
        return 0
    else
        log "WARN" "✗ Failed to delete Load Balancer: $lb_name"
        return 1
    fi
}

cleanup_load_balancers_in_vpc() {
    local vpc_id="$1"
    
    log "INFO" "Cleaning up Load Balancers in VPC: $vpc_id"
    
    # Get all ALB/NLB load balancers in VPC
    local load_balancers=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --query "LoadBalancers[?VpcId=='$vpc_id'].{Arn:LoadBalancerArn,Name:LoadBalancerName,Scheme:Scheme}" \
        --output json)
    
    local count=$(echo "$load_balancers" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        log "INFO" "No Load Balancers found in VPC: $vpc_id"
        return 0
    fi
    
    log "INFO" "Found $count Load Balancer(s) to clean up"
    
    local failed_count=0
    local success_count=0
    
    echo "$load_balancers" | jq -r '.[] | @base64' | while read -r encoded_item; do
        local item=$(echo "$encoded_item" | base64 -d)
        local lb_arn=$(echo "$item" | jq -r '.Arn')
        local lb_name=$(echo "$item" | jq -r '.Name')
        local scheme=$(echo "$item" | jq -r '.Scheme')
        
        log "INFO" ""
        log "INFO" "Processing Load Balancer: $lb_name (Scheme: $scheme)"
        
        if delete_load_balancer "$lb_arn"; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done
    
    log "INFO" "Load Balancer cleanup summary for VPC $vpc_id:"
    log "INFO" "  ✓ Successfully deleted: $success_count"
    log "INFO" "  ✗ Failed: $failed_count"
    
    return 0
}

cleanup_all_load_balancers() {
    log_header "LOAD BALANCER CLEANUP"
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
        local lb_count=$(aws elbv2 describe-load-balancers \
            --region "$REGION" \
            --query "LoadBalancers[?VpcId=='$vpc_id'] | length" \
            --output json)
        
        if [ "$lb_count" -gt 0 ]; then
            log "INFO" ""
            log "INFO" "VPC: $vpc_id (has $lb_count Load Balancer(s))"
            cleanup_load_balancers_in_vpc "$vpc_id"
        fi
    done
}

# Main execution
main() {
    log "INFO" "Load Balancer Cleanup Script Started"
    log "INFO" "Region: $REGION"
    log "INFO" "Log file: $LOG_FILE"
    
    check_dependencies
    
    cleanup_all_load_balancers
    
    log_header "CLEANUP COMPLETE"
    log "INFO" "Load Balancer cleanup finished at $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${GREEN}✓ Load Balancer cleanup complete${NC}"
    echo "Log file: ${LOG_FILE}"
}

main "$@"
