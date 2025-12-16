#!/bin/bash

# ==============================================================================
# Revoke All Security Group Rules - Break Circular Dependencies
# ==============================================================================
# This script revokes all ingress and egress rules from security groups in a VPC
# to break circular dependencies created by failed OCP deployments.
#
# Usage:
#   revoke-sg-rules.sh <region> [vpc_id]
#
# If vpc_id is not provided, will revoke rules from all non-default VPCs
#
# Required:
#   - AWS CLI configured with appropriate credentials
#   - Python 3 with boto3 (for efficient rule processing)
#   - AWS_PROFILE environment variable (optional, uses default if not set)
#
# Returns:
#   0 - Success (or graceful degradation if no SGs found)
#   1 - Critical error (AWS authentication failure, etc)
# ==============================================================================

set -e

REGION="${1:?Error: Region required as first argument}"
VPC_ID="${2:-}"
LOG_DIR="Logs"
LOG_FILE="${LOG_DIR}/revoke-sg-rules-$(date +%Y%m%d_%H%M%S).log"
TIMESTAMP=$(date '+%H:%M:%S')

# Create logs directory
mkdir -p "${LOG_DIR}"

# Redirect output to both log file and stdout
exec > >(tee -a "${LOG_FILE}")
exec 2>&1

echo "==========================================="
echo "Revoke Security Group Rules"
echo "==========================================="
echo "[${TIMESTAMP}] Starting SG rule revocation"
echo "Region: ${REGION}"
[ -n "${VPC_ID}" ] && echo "VPC ID: ${VPC_ID}" || echo "VPC ID: All non-default VPCs"
echo "Log: ${LOG_FILE}"
echo ""

# Python script to revoke all rules efficiently
python3 << 'PYEOF'
import boto3
import sys
import json
from botocore.exceptions import ClientError

REGION = sys.argv[1] if len(sys.argv) > 1 else None
VPC_ID = sys.argv[2] if len(sys.argv) > 2 else None

if not REGION:
    print("ERROR: Region not provided")
    sys.exit(1)

ec2 = boto3.client('ec2', region_name=REGION)

print(f"[INFO] Connecting to AWS region: {REGION}")

# Get all VPCs if VPC_ID not specified
vpcs_to_process = []
if VPC_ID:
    vpcs_to_process = [VPC_ID]
else:
    try:
        response = ec2.describe_vpcs()
        vpcs_to_process = [
            vpc['VpcId'] for vpc in response['Vpcs'] 
            if not vpc['IsDefault']
        ]
        print(f"[INFO] Found {len(vpcs_to_process)} non-default VPCs to process")
    except ClientError as e:
        print(f"ERROR: Could not describe VPCs: {e}")
        sys.exit(1)

if not vpcs_to_process:
    print("[INFO] No VPCs found to process")
    sys.exit(0)

# Process each VPC
total_rules_revoked = 0
total_sgs_processed = 0
failed_revocations = []

for vpc_id in vpcs_to_process:
    print(f"\n[VPC] Processing: {vpc_id}")
    
    try:
        # Get all security groups in the VPC
        response = ec2.describe_security_groups(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )
        security_groups = response['SecurityGroups']
        
        print(f"  Found {len(security_groups)} security groups")
        
        for sg in security_groups:
            sg_id = sg['GroupId']
            sg_name = sg['GroupName']
            total_sgs_processed += 1
            
            # Skip default security group
            if sg_name == 'default':
                print(f"  [SKIP] {sg_id} ({sg_name}) - default SG")
                continue
            
            print(f"  [SG] {sg_id} ({sg_name})")
            
            # Revoke ingress rules
            ingress_rules = sg.get('IpPermissions', [])
            if ingress_rules:
                print(f"    Ingress rules to revoke: {len(ingress_rules)}")
                for rule in ingress_rules:
                    try:
                        ec2.revoke_security_group_ingress(
                            GroupId=sg_id,
                            IpPermissions=[rule]
                        )
                        total_rules_revoked += 1
                    except ClientError as e:
                        error_code = e.response['Error']['Code']
                        # InvalidPermission.NotFound is OK - rule already gone
                        if error_code != 'InvalidPermission.NotFound':
                            msg = f"Failed to revoke ingress rule: {error_code}"
                            print(f"    ✗ {msg}")
                            failed_revocations.append((sg_id, 'ingress', str(e)))
            
            # Revoke egress rules
            egress_rules = sg.get('IpPermissionsEgress', [])
            if egress_rules:
                # Skip the default allow-all rule if it's the only one
                if len(egress_rules) == 1:
                    print(f"    Egress rules: 1 (default - keeping)")
                else:
                    print(f"    Egress rules to revoke: {len(egress_rules)}")
                    for rule in egress_rules:
                        # Skip default allow all rule
                        if (rule.get('IpRanges') and 
                            any(r.get('CidrIp') == '0.0.0.0/0' for r in rule.get('IpRanges', []))):
                            continue
                        
                        try:
                            ec2.revoke_security_group_egress(
                                GroupId=sg_id,
                                IpPermissions=[rule]
                            )
                            total_rules_revoked += 1
                        except ClientError as e:
                            error_code = e.response['Error']['Code']
                            if error_code != 'InvalidPermission.NotFound':
                                print(f"    ✗ Failed to revoke egress rule: {error_code}")
                                failed_revocations.append((sg_id, 'egress', str(e)))
    
    except ClientError as e:
        print(f"  ERROR: Could not process VPC {vpc_id}: {e}")
        sys.exit(1)

# Summary
print("\n" + "="*50)
print("SUMMARY")
print("="*50)
print(f"Security Groups Processed: {total_sgs_processed}")
print(f"Rules Revoked: {total_rules_revoked}")
print(f"Revocation Failures: {len(failed_revocations)}")

if failed_revocations:
    print("\nFailed Revocations:")
    for sg_id, rule_type, error in failed_revocations:
        print(f"  - {sg_id} ({rule_type}): {error}")

print("\n[SUCCESS] Security group rule revocation complete")
print(f"[INFO] SGs are now safe for deletion")

PYEOF

PYEOF_EXIT=$?

if [ ${PYEOF_EXIT} -ne 0 ]; then
    echo "[ERROR] Python script failed with exit code ${PYEOF_EXIT}"
    exit 1
fi

echo ""
echo "==========================================="
echo "Revocation completed at: $(date)"
echo "Log: ${LOG_FILE}"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Security groups can now be deleted"
echo "  2. VPCs can now be deleted after SGs are removed"
echo "  3. Run cleanup-stale-vpcs.sh to complete cleanup"
