#!/bin/bash
# Clean up stale VPCs that are not in use
# Keeps VPCs that have instances or are otherwise important

REGION="eu-north-1"

# Get all VPCs
all_vpcs=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs[*].VpcId' --output text)

for vpc_id in $all_vpcs; do
  # Check if VPC has any instances
  instance_count=$(aws ec2 describe-instances --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Reservations[*].Instances[*].InstanceId' --output text | wc -w)
  
  if [ "$instance_count" -eq 0 ]; then
    # No instances, this VPC is stale
    vpc_name=$(aws ec2 describe-vpcs --region $REGION --vpc-ids $vpc_id --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null || echo "no-name")
    
    # Skip the default VPC
    if [[ "$vpc_name" == "default" ]] || [[ "$vpc_id" == "vpc-0bc361745c9767872" ]]; then
      continue
    fi
    
    echo "🗑️  Found stale VPC: $vpc_id ($vpc_name) - cleaning up..."
    
    # Delete subnets
    subnets=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text)
    for subnet in $subnets; do
      aws ec2 delete-subnet --subnet-id $subnet --region $REGION 2>/dev/null && echo "  ✓ Deleted subnet $subnet" || true
    done
    
    # Detach and delete internet gateways
    igws=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text)
    for igw in $igws; do
      aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc_id --region $REGION 2>/dev/null || true
      aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION 2>/dev/null && echo "  ✓ Deleted IGW $igw" || true
    done
    
    # Release elastic IPs
    alloc_ids=$(aws ec2 describe-addresses --region $REGION --filters "Name=vpc-id,Values=$vpc_id" "Name=association-id,Values=null" --query 'Addresses[*].AllocationId' --output text)
    for alloc_id in $alloc_ids; do
      aws ec2 release-address --allocation-id $alloc_id --region $REGION 2>/dev/null && echo "  ✓ Released EIP $alloc_id" || true
    done
    
    # Delete route tables (except main)
    route_tables=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main != true].RouteTableId' --output text)
    for rt in $route_tables; do
      aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>/dev/null && echo "  ✓ Deleted route table $rt" || true
    done
    
    # Finally delete the VPC
    aws ec2 delete-vpc --vpc-id $vpc_id --region $REGION 2>/dev/null && echo "  ✓ Deleted VPC $vpc_id" || echo "  ✗ Could not delete VPC $vpc_id"
  fi
done

echo "✅ VPC cleanup complete"
