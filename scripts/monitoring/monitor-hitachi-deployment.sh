#!/bin/bash

# Hitachi SDS Block & Operator Deployment Monitor
# Monitors both AWS infrastructure and Kubernetes operator deployment

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/aws-gpfs-playground/ocp_install_files/auth/kubeconfig}"
REGION="${1:-eu-north-1}"
STACK_NAME="${2:-hitachi-sds-block-gpfs-levanon-c4qpp}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Hitachi Deployment Monitor${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" == "OK" ]; then
        echo -e "${GREEN}✓ $message${NC}"
    elif [ "$status" == "WARN" ]; then
        echo -e "${YELLOW}⚠ $message${NC}"
    else
        echo -e "${RED}✗ $message${NC}"
    fi
}

# 1. Check CloudFormation Stack
print_section "AWS CloudFormation Stack Status"
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text)
    
    print_status "INFO" "Stack Status: $STACK_STATUS"
    
    if [[ "$STACK_STATUS" == *"COMPLETE"* ]]; then
        print_status "OK" "Stack deployment complete"
    elif [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
        print_status "WARN" "Stack deployment in progress"
    elif [[ "$STACK_STATUS" == *"FAILED"* ]] || [[ "$STACK_STATUS" == *"ROLLBACK"* ]]; then
        print_status "ERROR" "Stack deployment failed"
        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
            --output table
    fi
else
    print_status "ERROR" "CloudFormation stack not found: $STACK_NAME"
fi
echo ""

# 2. Check EC2 Instance
print_section "EC2 Instance Status"
INSTANCES=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=hitachi-sds-block" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
    --output text)

if [ -z "$INSTANCES" ]; then
    print_status "WARN" "No SDS Block EC2 instance found"
else
    while read -r instance; do
        INSTANCE_ID=$(echo $instance | awk '{print $1}')
        INSTANCE_TYPE=$(echo $instance | awk '{print $2}')
        STATE=$(echo $instance | awk '{print $3}')
        NAME=$(echo $instance | awk '{print $4}')
        PUBLIC_IP=$(echo $instance | awk '{print $5}')
        PRIVATE_IP=$(echo $instance | awk '{print $6}')
        
        print_status "INFO" "Instance: $INSTANCE_ID ($INSTANCE_TYPE)"
        print_status "INFO" "State: $STATE"
        print_status "INFO" "Name: $NAME"
        [ "$PUBLIC_IP" != "None" ] && print_status "INFO" "Public IP: $PUBLIC_IP"
        print_status "INFO" "Private IP: $PRIVATE_IP"
        
        if [ "$STATE" == "running" ]; then
            print_status "OK" "Instance is running"
            
            # Check HTTP connectivity
            if timeout 5 nc -z "$PUBLIC_IP" 8443 2>/dev/null; then
                print_status "OK" "Port 8443 (Web Console) is accessible"
            else
                print_status "WARN" "Port 8443 not yet accessible (instance may still be initializing)"
            fi
        else
            print_status "WARN" "Instance state: $STATE"
        fi
    done <<< "$INSTANCES"
fi
echo ""

# 3. Check Kubernetes Cluster
print_section "Kubernetes Cluster Status"
if ! export KUBECONFIG="$KUBECONFIG" && kubectl cluster-info &>/dev/null; then
    print_status "OK" "Kubernetes cluster is accessible"
    
    # Check API server
    if kubectl get nodes &>/dev/null; then
        NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
        print_status "OK" "API Server responding - $NODE_COUNT nodes found"
    fi
else
    print_status "ERROR" "Cannot connect to Kubernetes cluster"
    echo "KUBECONFIG: $KUBECONFIG"
fi
echo ""

# 4. Check Hitachi Namespaces
print_section "Hitachi Namespaces"
export KUBECONFIG="$KUBECONFIG"

NAMESPACES=("hitachi-sds" "hitachi-system")
for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        print_status "OK" "Namespace '$ns' exists"
        
        # Count pods
        POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ "$POD_COUNT" -gt 0 ]; then
            print_status "OK" "$ns: $POD_COUNT pods running"
            kubectl get pods -n "$ns" -o wide
        else
            print_status "WARN" "$ns: No pods found (still deploying?)"
        fi
    else
        print_status "WARN" "Namespace '$ns' not found"
    fi
    echo ""
done

# 5. Check Hitachi Operators
print_section "Hitachi Operators Status"
export KUBECONFIG="$KUBECONFIG"

# Check for deployments
DEPLOYMENTS=$(kubectl get deployments -A -l app.kubernetes.io/part-of=hitachi 2>/dev/null | grep -v NAME || true)
if [ -z "$DEPLOYMENTS" ]; then
    print_status "WARN" "No Hitachi deployments found yet"
else
    print_status "OK" "Hitachi deployments found:"
    echo "$DEPLOYMENTS"
fi
echo ""

# 6. Check Hitachi CRDs
print_section "Hitachi Custom Resource Definitions"
CRDS=$(kubectl get crd 2>/dev/null | grep hitachi || true)
if [ -z "$CRDS" ]; then
    print_status "WARN" "No Hitachi CRDs found yet"
else
    print_status "OK" "Hitachi CRDs registered:"
    echo "$CRDS"
fi
echo ""

# 7. Check Helm Release (if using Helm)
print_section "Helm Deployment Status"
if helm list -A 2>/dev/null | grep -i hitachi >/dev/null; then
    print_status "OK" "Hitachi Helm release found:"
    helm list -A | grep -i hitachi
else
    print_status "WARN" "No Hitachi Helm release found"
fi
echo ""

# 8. Summary and Next Steps
print_section "Deployment Summary"
echo ""
echo "To view detailed logs:"
echo "  - AWS: aws cloudformation describe-stack-events --stack-name $STACK_NAME --region $REGION"
echo "  - K8s: kubectl logs -n hitachi-sds -l app=hitachi-operator --all-containers=true"
echo ""
echo "To check EC2 instance logs:"
echo "  - SSH into instance and check /var/log/user-data.log"
echo ""
echo "To restart monitoring:"
echo "  - $0 $REGION $STACK_NAME"
echo ""

print_section "Completed"
