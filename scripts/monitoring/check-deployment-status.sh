#!/bin/bash

set -e

REGION="eu-north-1"
STACK_NAME="hitachi-sds-block-gpfs-levanon-c4qpp"

echo "=== CloudFormation Stack Status ==="
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].[StackStatus,StackStatusReason]' \
  --output text

echo ""
echo "=== Latest CloudFormation Events ==="
aws cloudformation describe-stack-events \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'StackEvents[0:10].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
  --output table

echo ""
echo "=== EC2 Instances ==="
aws ec2 describe-instances \
  --filters "Name=tag:aws:cloudformation:stack-name,Values=$STACK_NAME" \
  --region "$REGION" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table

echo ""
echo "=== Deployment Playbook Status ==="
if ps aux | grep -q "[a]nsible-playbook.*sds-block-deploy"; then
  echo "✓ Ansible playbook is still running"
else
  echo "✗ Ansible playbook has completed"
fi
