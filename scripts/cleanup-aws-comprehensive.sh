#!/bin/bash
#
# cleanup-aws-comprehensive.sh
#
# Purpose: Orchestrate comprehensive cleanup of ALL stale AWS resources
# This script handles cleanup in the correct dependency order to ensure
# successful removal of orphaned infrastructure from failed OCP deployments
#
# Cleanup Order:
# 1. Load Balancers (ALB/NLB)
# 2. Target Groups (ELBv2)
# 3. NAT Gateways
# 4. Security Groups (via revoke-sg-rules.sh)
# 5. VPC and associated resources (via cleanup-stale-vpcs.sh)
#
# Usage: ./scripts/cleanup-aws-comprehensive.sh [region] [--dry-run]
#
# Examples:
#   ./scripts/cleanup-aws-comprehensive.sh eu-north-1
#   ./scripts/cleanup-aws-comprehensive.sh eu-north-1 --dry-run
#   AWS_REGION=eu-north-1 ./scripts/cleanup-aws-comprehensive.sh
#
# Requirements:
#   - AWS CLI v2 with jq
#   - AWS credentials configured (via AWS_PROFILE or default)
#   - Appropriate IAM permissions
#   - Other cleanup scripts in same directory
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REGION="${1:-${AWS_REGION:-eu-north-1}}"
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

# Logging functions
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}"
}

log_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║ $1"
    echo "╚════════════════════════════════════════════════════════════╝"
}

log_step() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Functions
check_dependencies() {
    log_step "Checking dependencies"
    
    local missing=0
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        missing=1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Please install AWS CLI and jq"
        exit 1
    fi
    
    log_success "All dependencies found"
}

validate_aws_credentials() {
    log_step "Validating AWS credentials"
    
    if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
        log_error "Failed to validate AWS credentials"
        exit 1
    fi
    
    log_success "AWS credentials validated"
}

get_resource_summary() {
    log_step "Gathering resource inventory for region: $REGION"
    
    # Get VPC count
    local vpc_count=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --query 'length(Vpcs[?IsDefault==`false`])' \
        --output json)
    
    # Get LB count
    local lb_count=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --query 'LoadBalancers | length' \
        --output json)
    
    # Get TG count
    local tg_count=$(aws elbv2 describe-target-groups \
        --region "$REGION" \
        --query 'TargetGroups | length' \
        --output json)
    
    # Get NAT GW count
    local nat_gw_count=$(aws ec2 describe-nat-gateways \
        --region "$REGION" \
        --query 'length(NatGateways[?State==`available`])' \
        --output json)
    
    log "INFO" "Resource Inventory:"
    log "INFO" "  Non-default VPCs: $vpc_count"
    log "INFO" "  Load Balancers: $lb_count"
    log "INFO" "  Target Groups: $tg_count"
    log "INFO" "  NAT Gateways: $nat_gw_count"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No resources will be deleted"
    fi
}

run_cleanup_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}.sh"
    
    if [ ! -f "$script_path" ]; then
        log_warning "Script not found (skipping): $script_path"
        return 0
    fi
    
    log "INFO" "Running: $script_name"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "  (DRY RUN - would execute: bash $script_path $REGION)"
    else
        if bash "$script_path" "$REGION" >> "${LOG_FILE}" 2>&1; then
            log_success "Completed: $script_name"
            return 0
        else
            log_error "Failed: $script_name"
            return 1
        fi
    fi
}

cleanup_load_balancers() {
    log_step "PHASE 1: Cleanup Load Balancers (ALB/NLB)"
    
    run_cleanup_script "cleanup-load-balancers"
}

cleanup_target_groups() {
    log_step "PHASE 2: Cleanup Target Groups (ELBv2)"
    
    run_cleanup_script "cleanup-target-groups"
}

cleanup_nat_gateways() {
    log_step "PHASE 3: Cleanup NAT Gateways"
    
    run_cleanup_script "cleanup-nat-gateways"
}

cleanup_security_groups() {
    log_step "PHASE 4: Cleanup Security Group Rules"
    
    run_cleanup_script "revoke-sg-rules"
}

cleanup_vpcs() {
    log_step "PHASE 5: Cleanup VPCs and Associated Resources"
    
    run_cleanup_script "cleanup-stale-vpcs"
}

# Main execution
main() {
    log_header "AWS COMPREHENSIVE STALE RESOURCES CLEANUP"
    log "INFO" "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Region: $REGION"
    log "INFO" "Log file: $LOG_FILE"
    
    check_dependencies
    validate_aws_credentials
    get_resource_summary
    
    if [ "$DRY_RUN" = true ]; then
        log_header "DRY RUN MODE - PREVIEW OF CLEANUP SEQUENCE"
    else
        log_header "EXECUTING COMPREHENSIVE CLEANUP"
    fi
    
    # Execute cleanup in dependency order
    cleanup_load_balancers
    sleep 2
    
    cleanup_target_groups
    sleep 2
    
    cleanup_nat_gateways
    sleep 2
    
    cleanup_security_groups
    sleep 2
    
    cleanup_vpcs
    
    # Summary
    log_header "CLEANUP COMPLETE"
    log "INFO" "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Log file: $LOG_FILE"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}✓ DRY RUN COMPLETE - No resources were deleted${NC}"
    else
        echo -e "${GREEN}✓ Comprehensive cleanup complete${NC}"
    fi
    
    echo "Log file: ${LOG_FILE}"
}

# Display usage
usage() {
    cat << 'EOF'
Usage: cleanup-aws-comprehensive.sh [region] [--dry-run]

Orchestrates comprehensive cleanup of stale AWS resources from failed OCP deployments.

Cleanup Sequence:
  1. Load Balancers (ALB/NLB)
  2. Target Groups (ELBv2)
  3. NAT Gateways
  4. Security Groups (revoke rules)
  5. VPCs and associated resources

Arguments:
  region      AWS region (default: eu-north-1)
  --dry-run   Show what would be deleted without making changes

Environment Variables:
  AWS_REGION   Set default region
  AWS_PROFILE  Set AWS profile for credentials

Examples:
  ./cleanup-aws-comprehensive.sh eu-north-1
  ./cleanup-aws-comprehensive.sh eu-north-1 --dry-run
  AWS_REGION=us-east-1 ./cleanup-aws-comprehensive.sh --dry-run

EOF
}

# Show usage if requested
if [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
    usage
    exit 0
fi

main "$@"
