# Hitachi SDS Deployment - Status & Instructions

## Current Status
✅ **Deployment in Progress** - Retried with correct AMI (ami-07d9228dc6ef5347a)
- Started: 2025-12-09 ~19:15 UTC+2
- Expected duration: 15-25 minutes

## What Was Fixed
1. **AMI Issue**: Changed invalid AMI `ami-0d71ea30463e0ff8d` to valid `ami-07d9228dc6ef5347a` (Amazon Linux 2 x86_64)
2. **CloudFormation Logic**: Fixed stack deletion condition checking for ROLLBACK_COMPLETE state
3. **Template**: Created clean CloudFormation template without deprecated parameters

## Monitoring Deployment

### Option 1: Watch Real-Time Progress (Recommended)
```bash
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```
Updates every 30 seconds, shows:
- CloudFormation stack status
- EC2 instance details
- Network connectivity
- Web console accessibility (port 8443)

### Option 2: One-Time Status Check
```bash
./scripts/monitoring/monitor-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```

### Option 3: Check CloudFormation Events
```bash
aws cloudformation describe-stack-events \
  --stack-name hitachi-sds-block-gpfs-levanon-c4qpp \
  --region eu-north-1 \
  --query 'StackEvents[0:20]' \
  --output table
```

### Option 4: View Raw Logs
```bash
# Check latest deployment log
ls -ltrh Temp/sds-deploy-*.log | tail -1

# Tail the log
tail -f Temp/sds-deploy-*.log
```

## Expected Outcomes

### When Successful (20-30 minutes)
1. CloudFormation stack status: **CREATE_COMPLETE**
2. EC2 instance is running with:
   - Public IP assigned
   - Security groups configured
   - Both network interfaces active
3. Output from monitoring script shows:
   ```
   ✓ Stack deployment complete
   ✓ Instance is running
   ✓ Port 8443 (Web Console) is accessible
   ```

### Next Steps After Successful Deployment
1. **Prepare Kubernetes Namespaces**
   ```bash
   ./scripts/deployment/prepare-hitachi-namespace.sh
   ```

2. **Install Hitachi Operators**
   ```bash
   make install-hitachi
   ```

3. **Continue Monitoring**
   ```bash
   ./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1
   ```

## Key Files & Information

### Deployment Artifacts
- **Playbook**: `playbooks/sds-block-deploy.yml`
- **CloudFormation Template**: `Temp/Hitachi/sds-block-cf-clean.yaml`
- **Logs**: `Temp/sds-deploy-20251209_*.log`
- **Credentials**: `~/aws-gpfs-playground/ocp_install_files/sds-block-credentials.env`

### AWS Resources
- **Stack Name**: `hitachi-sds-block-gpfs-levanon-c4qpp`
- **Region**: `eu-north-1`
- **VPC**: `vpc-08578f51d2cfc6cf8`
- **Subnets**: 
  - Management: `subnet-0542f29be5976ccb0` (10.0.0.0/18)
  - Data: `subnet-02de81c4430a09d25` (10.0.64.0/18)
- **Instance Type**: `m5.2xlarge`
- **AMI**: `ami-07d9228dc6ef5347a` (Amazon Linux 2)
- **EC2 Key**: `nlevanon-key`

### Kubernetes Configuration
- **KUBECONFIG**: `/home/nlevanon/aws-gpfs-playground/ocp_install_files/auth/kubeconfig`
- **Cluster**: `gpfs-levanon-c4qpp`
- **Hitachi Namespace**: `hitachi-sds`
- **System Namespace**: `hitachi-system`

## Troubleshooting

### If Deployment Fails Again
1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name hitachi-sds-block-gpfs-levanon-c4qpp \
     --region eu-north-1 \
     --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
   ```

2. Check Ansible logs:
   ```bash
   tail -100 Temp/sds-deploy-*.log | grep -i error
   ```

3. Delete failed stack and retry:
   ```bash
   aws cloudformation delete-stack --stack-name hitachi-sds-block-gpfs-levanon-c4qpp --region eu-north-1
   sleep 10
   ./scripts/deployment/deploy-sds-block.sh eu-north-1 gpfs-levanon-c4qpp
   ```

### If EC2 Instance Won't Boot
Check instance system logs:
```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=hitachi-sds-block" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ec2 get-console-output --instance-id $INSTANCE_ID --region eu-north-1
```

### If Port 8443 Not Accessible
1. Verify security group rules
2. Check instance IP connectivity
3. Instance may still be initializing (check for 5-10 minutes)

## Scripts Directory

All helper scripts are in `scripts/`:
```
scripts/
├── README.md                           # Full documentation
├── monitoring/
│   ├── monitor-hitachi-deployment.sh   # Single status check
│   └── watch-hitachi-deployment.sh     # Continuous monitoring
└── deployment/
    ├── deploy-sds-block.sh             # Run full deployment
    └── prepare-hitachi-namespace.sh    # Prepare K8s namespaces
```

## Commands Quick Reference

```bash
# Monitor deployment
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp

# Check AWS resources
aws ec2 describe-instances --region eu-north-1 --filters "Name=tag:Name,Values=hitachi-sds-block" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table

# Check K8s resources
kubectl get pods -n hitachi-sds
kubectl get pods -n hitachi-system

# View deployment credentials
cat ~/aws-gpfs-playground/ocp_install_files/sds-block-credentials.env

# Clean up (if needed)
aws cloudformation delete-stack --stack-name hitachi-sds-block-gpfs-levanon-c4qpp --region eu-north-1
```

---
**Generated**: 2025-12-09 19:15 UTC+2
**Status**: Deployment in progress with fixed AMI
