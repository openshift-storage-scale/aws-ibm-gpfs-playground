# Hitachi SDS Deployment Scripts

This directory contains scripts for deploying and monitoring Hitachi VSP One SDS Block infrastructure on AWS and operators on OpenShift.

## Directory Structure

```
scripts/
├── deployment/          # Deployment automation scripts
│   ├── hitachi-complete-setup.sh        # ⭐ Complete end-to-end setup (recommended)
│   ├── allocate-eip.sh                  # Allocate Elastic IP for console access
│   ├── deploy-hitachi-operator.sh       # Deploy HSPC operator via Helm
│   ├── deploy-sds-block.sh              # Deploy SDS Block EC2 infrastructure
│   ├── prepare-namespaces.sh            # Prepare Kubernetes namespaces
│   └── prepare-hitachi-namespace.sh     # [deprecated] Use prepare-namespaces.sh
└── monitoring/          # Monitoring and diagnostics scripts
    ├── monitor-hitachi-deployment.sh    # One-time status check
    └── watch-hitachi-deployment.sh      # Continuous monitoring
```

## Quick Start

### Complete Setup (Recommended - All Phases at Once)

```bash
./scripts/deployment/hitachi-complete-setup.sh eu-north-1 gpfs-levanon-c4qpp default
```

This orchestrator script runs all phases sequentially:
1. **Verify Infrastructure** - Check CloudFormation stack status
2. **Verify OCP Cluster** - Test Kubernetes connectivity  
3. **Prepare Namespaces** - Create hitachi-sds and hitachi-system namespaces
4. **Deploy HSPC Operator** - Install Hitachi Storage Plug-in via Helm
5. **Allocate Elastic IP** - Get public access to management console

**Expected time:** ~5-10 minutes

---

### Phase-by-Phase Setup

If you need more control, run each phase separately:

#### Phase 1: Deploy SDS Block Infrastructure

Deploy the Hitachi SDS Block EC2 instance on AWS:

```bash
./scripts/deployment/deploy-sds-block.sh eu-north-1 gpfs-levanon-c4qpp
```

**What it does:**
- Verifies AWS credentials and Kubernetes connectivity
- Creates EC2 key pair if needed
- Deploys CloudFormation stack with:
  - EC2 instance (m5.2xlarge)
  - Network interfaces (management + data)
  - Security groups (ports 8443, 3260)
  - EBS volumes (100GB root + 500GB data)
  - IAM role and CloudWatch monitoring

**Expected output:** New CloudFormation stack with running EC2 instance

#### Phase 2: Prepare Kubernetes Namespaces

```bash
./scripts/deployment/prepare-namespaces.sh ~/.kube/config hitachi-system
```

**What it does:**
- Creates hitachi-sds and hitachi-system namespaces
- Labels namespaces for operator deployment
- Verifies namespace creation

#### Phase 3: Deploy Hitachi HSPC Operator

```bash
./scripts/deployment/deploy-hitachi-operator.sh ~/.kube/config hitachi-system 3.14.0
```

**What it does:**
- Adds Hitachi Helm repository
- Deploys Storage Plug-in for Containers via Helm
- Waits for operator pods to become ready (2-3 minutes)
- Displays operator status

#### Phase 4: Allocate Elastic IP

```bash
./scripts/deployment/allocate-eip.sh eu-north-1 eni-01fb79c3038d88dcb default
```

**What it does:**
- Allocates new Elastic IP (or reuses existing)
- Associates with management ENI
- Displays console access URL

---

## 2. Monitor Infrastructure Deployment

While the deployment is running or after it completes, check the status:

```bash
# One-time status check
./scripts/monitoring/monitor-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp

# Continuous monitoring (updates every 30 seconds)
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```

**What it shows:**
- ✓ CloudFormation stack status
- ✓ EC2 instance details (IP addresses, state)
- ✓ Kubernetes cluster connectivity
- ✓ Hitachi namespaces and pod status
- ✓ Operator deployments
- ✓ Web console accessibility (port 8443)

---

## Make Targets

For convenience, Makefile targets are also available:

```bash
# Quick start - complete setup
make hitachi-complete-setup

# Individual phases
make hitachi-prepare-ns
make hitachi-deploy-operator
make hitachi-allocate-eip

# Info
make hitachi-info
make hitachi-help
make hitachi-check-prereqs
```

## Usage Examples

### Complete deployment workflow:

```bash
# Terminal 1: Start deployment
./scripts/deployment/deploy-sds-block.sh eu-north-1 gpfs-levanon-c4qpp

# Terminal 2: Monitor progress in real-time
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp

# Once EC2 is running, deploy operators
./scripts/deployment/prepare-hitachi-namespace.sh
make install-hitachi

# Keep monitoring the full stack
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```

### Check specific resources:

```bash
# Just check AWS infrastructure
./scripts/monitoring/monitor-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp | head -50

# Just check Kubernetes resources
export KUBECONFIG=/path/to/kubeconfig
kubectl get pods -n hitachi-sds
kubectl get pods -n hitachi-system
kubectl describe deployments -n hitachi-sds

# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name hitachi-sds-block-gpfs-levanon-c4qpp \
  --region eu-north-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --output table
```

## Environment Variables

All scripts respect the following environment variables:

```bash
# Kubernetes configuration
export KUBECONFIG=/home/nlevanon/aws-gpfs-playground/ocp_install_files/auth/kubeconfig

# AWS configuration (uses default profile)
export AWS_PROFILE=default
export AWS_REGION=eu-north-1

# Custom configuration for monitoring scripts
export MONITOR_INTERVAL=30  # Check every 30 seconds
```

## Logs and Outputs

Deployment logs are saved to:
```
Temp/deploy-sds-20251209_HHMMSS.log
Temp/sds-deploy-20251209_HHMMSS.log
```

Credentials saved to:
```
~/aws-gpfs-playground/ocp_install_files/sds-block-credentials.env
```

CloudFormation stack details:
```bash
aws cloudformation describe-stacks \
  --stack-name hitachi-sds-block-gpfs-levanon-c4qpp \
  --region eu-north-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Troubleshooting

### Deployment fails with "Unresolved resource dependencies"
- Check the CloudFormation template for parameter mismatches
- Verify all AMI IDs exist in the target region
- Run: `aws cloudformation validate-template --template-body file://Temp/Hitachi/sds-block-cf-clean.yaml --region eu-north-1`

### EC2 instance doesn't boot
- Check instance logs: `aws ec2 get-console-output --instance-id <id> --region eu-north-1`
- Verify IAM role permissions
- Check security group rules allow outbound traffic

### No pods in hitachi-sds namespace
- Ensure EC2 instance is accessible from the cluster
- Check if operators were installed: `kubectl get pods -n hitachi-system`
- Verify network connectivity between EC2 and cluster

### Monitoring script shows no pods
- Operators may still be installing
- Check Helm release: `helm list -A`
- View deployment logs: `kubectl logs -n hitachi-system -l app=hitachi-operator`

## Related Commands

```bash
# View EC2 instances
aws ec2 describe-instances --region eu-north-1 --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress]' --output table

# Connect to EC2 instance
ssh -i /tmp/nlevanon-key.pem ec2-user@<PUBLIC_IP>

# Delete infrastructure (caution!)
aws cloudformation delete-stack --stack-name hitachi-sds-block-gpfs-levanon-c4qpp --region eu-north-1

# View Kubernetes cluster info
kubectl cluster-info
kubectl get nodes
kubectl get all -n hitachi-sds
```

## Support

For issues or questions:
1. Check the logs: `Temp/*.log`
2. Run the monitoring script for current status
3. Check AWS CloudFormation events
4. Verify Kubernetes cluster connectivity
5. Review operator deployment logs in hitachi-system namespace

---

## Complete Script-Based Workflow

All successful operations have been refactored into scripts:

### ✓ Scripts Available:
- `allocate-eip.sh` - Allocate and attach Elastic IP
- `deploy-hitachi-operator.sh` - Deploy HSPC operator via Helm  
- `deploy-sds-block.sh` - Deploy EC2 infrastructure
- `prepare-namespaces.sh` - Prepare Kubernetes namespaces
- `hitachi-complete-setup.sh` - Orchestrate all phases

### ✓ Makefile Targets:
- `make hitachi-complete-setup` - Run full setup
- `make hitachi-prepare-ns` - Prepare namespaces
- `make hitachi-deploy-operator` - Deploy operator
- `make hitachi-allocate-eip` - Allocate EIP

### Automation Benefits:
✓ Reproducible deployments
✓ Error handling and validation
✓ Progress feedback and logging
✓ Rollback capability on errors
✓ Self-contained operation documentation
