#!/bin/bash
#
# cleanup-nat-gateways.sh
#
# Purpose: Clean up orphaned NAT Gateways from failed OCP deployments
# These resources block VPC deletion and must be cleaned up before VPC removal
#
# Usage: ./scripts/cleanup-nat-gateways.sh [region]
#
# Examples:
#   ./scripts/cleanup-nat-gateways.sh eu-north-1
#   AWS_REGION=eu-north-1 ./scripts/cleanup-nat-gateways.sh
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
LOG_FILE="${LOGS_DIR}/cleanup-nat-gateways-${TIMESTAMP}.log"

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

release_elastic_ips() {
    local nat_gateway_id="$1"
    local allocation_id="$2"
    
    if [ -z "$allocation_id" ]; then
        return 0
    fi
    
    log "INFO" "  Releasing Elastic IP allocation: $allocation_id"
    
    if aws ec2 release-address \
        --region "$REGION" \
        --allocation-id "$allocation_id" \
        --output json >> "${LOG_FILE}" 2>&1; then
        log "INFO" "  ✓ Elastic IP released: $allocation_id"
        return 0
    else
        log "WARN" "  ✗ Failed to release Elastic IP: $allocation_id"
        return 1
    fi
}

delete_nat_gateway() {
    local nat_gateway_id="$1"
    local max_retries=3
    local retry_count=0
    local wait_time=10
    
    log "INFO" "Deleting NAT Gateway: $nat_gateway_id"
    
    # Delete NAT Gateway
    if ! aws ec2 delete-nat-gateway \
        --region "$REGION" \
        --nat-gateway-id "$nat_gateway_id" \
        --output json >> "${LOG_FILE}" 2>&1; then
        log "WARN" "Failed to initiate delete for NAT Gateway: $nat_gateway_id"
        return 1
    fi
    
    log "INFO" "  Waiting for NAT Gateway to be deleted (max ${max_retries} retries)..."
    
    # Poll for deletion completion
    while [ $retry_count -lt $max_retries ]; do
        sleep "$wait_time"
        
        local state=$(aws ec2 describe-nat-gateways \
            --region "$REGION" \
            --nat-gateway-ids "$nat_gateway_id" \
            --query 'NatGateways[0].State' \
            --output text 2>/dev/null || echo "deleted")
        
        if [ "$state" = "deleted" ]; then
            log "INFO" "✓ NAT Gateway deleted successfully: $nat_gateway_id"
            return 0
        fi
        
        log "INFO" "  Waiting... (State: $state, attempt $((retry_count+1))/$max_retries)"
        retry_count=$((retry_count + 1))
        wait_time=$((wait_time + 10))  # Increase wait time
    done
    
    log "WARN" "NAT Gateway still exists after $max_retries retries: $nat_gateway_id (State: $state)"
    return 1
}

cleanup_nat_gateways_in_vpc() {
    local vpc_id="$1"
    
    log "INFO" "Cleaning up NAT Gateways in VPC: $vpc_id"
    
    # Get all NAT Gateways in VPC
    local nat_gateways=$(aws ec2 describe-nat-gateways \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" \
        --query 'NatGateways[*].[NatGatewayId,NatGatewayAddresses[0].AllocationId]' \
        --output json)
    
    local count=$(echo "$nat_gateways" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        log "INFO" "No NAT Gateways found in VPC: $vpc_id"
        return 0
    fi
    
    log "INFO" "Found $count NAT Gateway(s) to clean up"
    
    local failed_count=0
    local success_count=0
    
    echo "$nat_gateways" | jq -r '.[] | @base64' | while read -r encoded_item; do
        local item=$(echo "$encoded_item" | base64 -d)
        local nat_gateway_id=$(echo "$item" | jq -r '.[0]')
        local allocation_id=$(echo "$item" | jq -r '.[1]')
        
        log "INFO" ""
        log "INFO" "Processing NAT Gateway: $nat_gateway_id"
        
        # Release associated Elastic IP
        if [ "$allocation_id" != "null" ]; then
            release_elastic_ips "$nat_gateway_id" "$allocation_id"
        fi
        
        # Delete NAT Gateway
        if delete_nat_gateway "$nat_gateway_id"; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done
    
    log "INFO" "NAT Gateway cleanup summary for VPC $vpc_id:"
    log "INFO" "  ✓ Successfully deleted: $success_count"
    log "INFO" "  ✗ Failed: $failed_count"
    
    return 0
}

cleanup_all_nat_gateways() {
    log_header "NAT GATEWAY CLEANUP"
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
    
    local total_nat_gws=0
    
    echo "$vpcs" | jq -r '.[]' | while read -r vpc_id; do
        local nat_gw_count=$(aws ec2 describe-nat-gateways \
            --region "$REGION" \
            --filters "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" \
            --query 'NatGateways | length' \
            --output json)
        
        if [ "$nat_gw_count" -gt 0 ]; then
            log "INFO" ""
            log "INFO" "VPC: $vpc_id (has $nat_gw_count NAT Gateway(s))"
            cleanup_nat_gateways_in_vpc "$vpc_id"
        fi
    done
}

# Main execution
main() {
    log "INFO" "NAT Gateway Cleanup Script Started"
    log "INFO" "Region: $REGION"
    log "INFO" "Log file: $LOG_FILE"
    
    check_dependencies
    
    cleanup_all_nat_gateways
    
    log_header "CLEANUP COMPLETE"
    log "INFO" "NAT Gateway cleanup finished at $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Log file: $LOG_FILE"
    
    echo -e "${GREEN}✓ NAT Gateway cleanup complete${NC}"
    echo "Log file: ${LOG_FILE}"
}

main "$@"
