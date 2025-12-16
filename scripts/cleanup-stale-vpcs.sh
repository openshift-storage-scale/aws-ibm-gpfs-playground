#!/bin/bash
# Clean up stale VPCs that are not in use
# Keeps VPCs that have instances or are otherwise important
#
# NOTE: This script may fail on VPCs with orphaned AWS infrastructure (ELB attachments)
# See VPC_CLEANUP_ISSUE.md for details on unresolvable permission issues

REGION="eu-north-1"
MAX_RETRIES=3

echo "⚠️  WARNING: This script attempts to clean up stale VPCs."
echo "   Some VPCs may have orphaned AWS infrastructure (ELB attachments)"
echo "   that cannot be deleted due to permission restrictions."
echo "   See VPC_CLEANUP_ISSUE.md for more information."
echo ""

# Get all VPCs
all_vpcs=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs[*].VpcId' --output text)

for vpc_id in $all_vpcs; do
  # Check if VPC has any instances
  instance_count=$(aws ec2 describe-instances --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null | wc -w)
  
  if [ "$instance_count" -eq 0 ]; then
    # No instances, this VPC is stale
    vpc_name=$(aws ec2 describe-vpcs --region $REGION --vpc-ids $vpc_id --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null || echo "no-name")
    
    # Skip the default VPC
    if [[ "$vpc_name" == "default" ]] || [[ "$vpc_id" == "vpc-0bc361745c9767872" ]]; then
      continue
    fi
    
    echo "🗑️  Found stale VPC: $vpc_id ($vpc_name) - cleaning up..."
    
    # Force-detach orphaned network interfaces (may have dangling EIP associations)
    echo "  🔄 Force-detaching orphaned network interfaces..."
    eni_ids=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null)
    for eni_id in $eni_ids; do
      if [ -n "$eni_id" ]; then
        # Get attachment ID for this ENI
        attachment_id=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-ids "$eni_id" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null)
        
        if [ -n "$attachment_id" ] && [ "$attachment_id" != "None" ]; then
          # Try to force-detach
          result=$(aws ec2 detach-network-interface --attachment-id "$attachment_id" --region $REGION --force 2>&1)
          if [ $? -eq 0 ]; then
            echo "    ✓ Force-detached ENI $eni_id (attachment $attachment_id)"
            sleep 2
          else
            echo "    ℹ️  Could not force-detach ENI $eni_id: $result"
          fi
        fi
        
        # Try to delete the detached ENI
        result=$(aws ec2 delete-network-interface --network-interface-id "$eni_id" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Deleted ENI $eni_id"
        else
          echo "    ℹ️  ENI $eni_id still in use: $result"
        fi
      fi
    done
    sleep 3
    
    # Release unassociated Elastic IPs in this VPC (those without AssociationId)
    echo "  🔄 Releasing unassociated Elastic IPs..."
    alloc_ids=$(aws ec2 describe-addresses --region $REGION --output json 2>/dev/null | jq -r '.Addresses[] | select(.AssociationId == null) | .AllocationId')
    for alloc_id in $alloc_ids; do
      if [ -n "$alloc_id" ] && [ "$alloc_id" != "null" ]; then
        result=$(aws ec2 release-address --allocation-id "$alloc_id" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Released unassociated EIP $alloc_id"
        else
          echo "    ℹ️  EIP $alloc_id already released: $result"
        fi
      fi
    done
    sleep 2
    
    # Delete security groups (except default)
    echo "  🔄 Deleting security groups..."
    sgs=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null)
    for sg in $sgs; do
      if [ -n "$sg" ]; then
        result=$(aws ec2 delete-security-group --group-id "$sg" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Deleted security group $sg"
        else
          echo "    ✗ Failed to delete security group $sg: $result"
        fi
      fi
    done
    sleep 2
    
    # Delete subnets with retry
    echo "  🔄 Deleting subnets..."
    subnets=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text 2>/dev/null)
    for subnet in $subnets; do
      if [ -n "$subnet" ]; then
        for ((i=1; i<=MAX_RETRIES; i++)); do
          result=$(aws ec2 delete-subnet --subnet-id "$subnet" --region $REGION 2>&1)
          if [ $? -eq 0 ]; then
            echo "    ✓ Deleted subnet $subnet"
            break
          else
            if [ $i -lt $MAX_RETRIES ]; then
              echo "    ⏳ Subnet $subnet deletion failed: $result"
              echo "      Retrying (attempt $i/$MAX_RETRIES)..."
              sleep 3
            else
              echo "    ✗ Could not delete subnet $subnet after $MAX_RETRIES attempts: $result"
            fi
          fi
        done
      fi
    done
    sleep 2
    
    # Detach and delete internet gateways
    echo "  🔄 Deleting internet gateways..."
    igws=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text 2>/dev/null)
    for igw in $igws; do
      if [ -n "$igw" ]; then
        result=$(aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc_id" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Detached IGW $igw"
        else
          echo "    ✗ Failed to detach IGW $igw: $result"
        fi
        result=$(aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Deleted IGW $igw"
        else
          echo "    ✗ Failed to delete IGW $igw: $result"
        fi
      fi
    done
    sleep 2
    
    # Delete route tables (except main)
    echo "  🔄 Deleting route tables..."
    route_tables=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main != true].RouteTableId' --output text 2>/dev/null)
    for rt in $route_tables; do
      if [ -n "$rt" ]; then
        result=$(aws ec2 delete-route-table --route-table-id "$rt" --region $REGION 2>&1)
        if [ $? -eq 0 ]; then
          echo "    ✓ Deleted route table $rt"
        else
          echo "    ✗ Failed to delete route table $rt: $result"
        fi
      fi
    done
    sleep 2
    
    # Finally delete the VPC with retry
    echo "  🔄 Deleting VPC..."
    for ((i=1; i<=MAX_RETRIES; i++)); do
      result=$(aws ec2 delete-vpc --vpc-id "$vpc_id" --region $REGION 2>&1)
      if [ $? -eq 0 ]; then
        echo "  ✓ Deleted VPC $vpc_id"
        break
      else
        if [ $i -lt $MAX_RETRIES ]; then
          echo "    ✗ VPC deletion failed: $result"
          echo "    ⏳ Retrying (attempt $i/$MAX_RETRIES)..."
          sleep 3
        else
          echo "  ✗ Could not delete VPC $vpc_id after $MAX_RETRIES attempts"
          echo "  Error: $result"
        fi
      fi
    done
  fi
done

echo ""
echo "✅ VPC cleanup attempt complete"
echo ""
echo "⚠️  NOTE: Some VPCs may have failed to delete due to:"
echo "   - Orphaned AWS infrastructure (ELB attachments, EIPs with permission issues)"
echo "   - Resources owned by AWS services that you don't have permission to manage"
echo ""
echo "   If you see DependencyViolation or AuthFailure errors, see:"
echo "   VPC_CLEANUP_ISSUE.md"
echo ""