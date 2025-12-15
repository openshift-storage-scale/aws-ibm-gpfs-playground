# Complete Deployment Guide: OCP + Hitachi SDS Block

## Quick Start

**Option 1: Fresh Deployment (Recommended)**
```bash
make install-hitachi-with-sds
```

This automatically:
- ✅ Detects and cleans up any failed stacks
- ✅ Auto-creates/detects EC2 key pair
- ✅ Auto-detects default VPC
- ✅ Deploys complete OCP cluster
- ✅ Deploys Hitachi SDS Block appliance
- ✅ Installs Hitachi HSPC Operator

**Time Required:** ~40-45 minutes

## If Previous Deployment Failed

The playbook now **automatically cleans up failed stacks** before deployment, but you can also manually clean up:

### Manual Cleanup (optional)

```bash
# 1. Remove local OCP metadata (forces fresh deployment)
rm -f ~/aws-gpfs-playground/ocp_install_files/metadata.json

# 2. Delete failed CloudFormation stack in AWS
aws cloudformation delete-stack \
  --stack-name hitachi-sds-block-gpfs-levanon \
  --profile default \
  --region eu-north-1

# 3. Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name hitachi-sds-block-gpfs-levanon \
  --profile default \
  --region eu-north-1

# 4. Then start deployment
make install-hitachi-with-sds
```

## Automated Cleanup Explanation

When you run `make install-hitachi-with-sds`, the playbook now:

1. **Detects failed stacks** in CloudFormation
2. **Identifies stack status** (ROLLBACK_COMPLETE, CREATE_FAILED, etc.)
3. **Automatically deletes** failed stacks
4. **Waits for deletion** before proceeding
5. **Creates new stack** with clean state

Failed stacks can't be updated - they must be deleted first. This automation saves you manual cleanup steps!

## What Gets Deployed

| Component | Count | Type |
|-----------|-------|------|
| OCP Master Nodes | 3 | EC2 (m5.2xlarge by default) |
| OCP Worker Nodes | 3 | EC2 (m5.2xlarge by default) |
| Hitachi SDS Block | 1 | EC2 (m5.2xlarge) |
| **Total EC2 Instances** | **7** | Auto-created by playbook |
| VPC | 1 | Auto-detected (default) |
| Security Groups | 2+ | Auto-created with proper rules |
| CloudFormation Stacks | 2 | OCP stack + SDS Block stack |

## Monitoring Deployment Progress

As deployment runs, you'll see:

```
✅ aws_profile is configured: default
✅ Created EC2 key pair: gpfs-levanon-sds-key
✅ AWS Resources Ready:
  EC2 Key Pair: gpfs-levanon-sds-key
  VPC ID: vpc-0bc361745c9767872
  Region: eu-north-1

[OCP Installation...]
Waiting for OCP API (attempt 1/60)...
Waiting for OCP API (attempt 2/60)...
...

[Hitachi SDS Block Deployment...]
Creating or updating SDS Block CloudFormation stack...

[Hitachi Operator Installation...]
Installing Hitachi HSPC Operator...
```

## After Deployment

Once complete (check `make install-hitachi-with-sds` output for final status):

```bash
# Set kubeconfig
export KUBECONFIG=~/aws-gpfs-playground/ocp_install_files/auth/kubeconfig

# Login to cluster
oc login -u kubeadmin https://api.gpfs-levanon.fusionaccess.devcluster.openshift.com:6443

# Check Hitachi SDS is running
oc get pods -n hitachi-sds

# Check SDS Block instance in AWS
aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=*sds*" \
  --profile default \
  --region eu-north-1
```

## Troubleshooting

### CloudFormation Stack Stuck in ROLLBACK_COMPLETE
**Error:** "Stack is in ROLLBACK_COMPLETE state and can not be updated"

**Fix:** Playbook now automatically deletes and recreates. If it still fails:
```bash
aws cloudformation delete-stack --stack-name hitachi-sds-block-gpfs-levanon --profile default --region eu-north-1
aws cloudformation wait stack-delete-complete --stack-name hitachi-sds-block-gpfs-levanon --profile default --region eu-north-1
make install-hitachi-with-sds
```

### OCP API Not Becoming Ready
**Error:** "OCP API did not become ready"

**Causes:**
- Cluster is still bootstrapping (normal - takes 30+ minutes)
- Cluster was destroyed in AWS but metadata still exists
- EC2 instances failed to launch

**Fix:**
```bash
# Check cluster status in AWS
aws ec2 describe-instances \
  --filter "Name=tag:Name,Values=gpfs-levanon*" \
  --profile default \
  --region eu-north-1 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime]'

# If stuck: force restart
rm -f ~/aws-gpfs-playground/ocp_install_files/metadata.json
make install-hitachi-with-sds
```

## Cost Estimate

For eu-north-1 region with default sizing:
- 3x m5.2xlarge (master): ~€500/month
- 3x m5.2xlarge (worker): ~€500/month  
- 1x m5.2xlarge (SDS Block): ~€167/month
- Storage/data transfer: ~€100/month
- **Total:** ~€1,200/month while running

⚠️ **Remember to run `make destroy` to clean up and stop costs!**
