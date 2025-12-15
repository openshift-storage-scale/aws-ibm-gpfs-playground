# Fixing "make destroy" Getting Stuck with Hitachi SDS Block

## The Problem

When you run `make destroy` after deploying Hitachi SDS Block, it gets stuck because:

1. **CloudFormation stack failed** and is in `ROLLBACK_COMPLETE` state
2. **Resources weren't fully cleaned up** (EC2 instances, volumes, security groups still exist)
3. **The destroy playbook doesn't handle SDS cleanup** (it only handles OCP resources)

**Result:** `make destroy` tries to destroy the OCP cluster but gets stuck waiting for CloudFormation.

---

## Solution: Force Cleanup SDS Resources First

### Step 1: Dry Run (See What Will Be Deleted)

```bash
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

# See what will be deleted (no changes made)
./scripts/cleanup-hitachi-sds-force.sh --dry-run

# Or with specific cluster/region:
./scripts/cleanup-hitachi-sds-force.sh --cluster-name gpfs-levanon-c4qpp --region eu-north-1 --dry-run
```

**Output will show:**
- CloudFormation stack to delete
- EC2 instances to terminate
- EBS volumes to delete
- Security groups to remove
- Network interfaces to delete

### Step 2: Run Actual Cleanup

```bash
# Delete all Hitachi SDS resources
./scripts/cleanup-hitachi-sds-force.sh

# Or with AWS profile:
AWS_PROFILE=myprofile ./scripts/cleanup-hitachi-sds-force.sh
```

**What it does:**
- ✅ Deletes CloudFormation stack
- ✅ Terminates EC2 instances
- ✅ Deletes EBS volumes
- ✅ Removes security groups
- ✅ Cleans up network interfaces

### Step 3: Now Run make destroy

```bash
# Now this should work without hanging
make destroy
```

---

## Complete Cleanup Sequence

If `make destroy` is still stuck, use this sequence:

```bash
# 1. Kill the stuck destroy process
# Ctrl+C in terminal running make destroy

# 2. Force cleanup Hitachi SDS
./scripts/cleanup-hitachi-sds-force.sh

# 3. Verify resources are gone (check AWS console)
#    - Look for CloudFormation stacks
#    - Check for EC2 instances (hitachi-sds-block-*)
#    - Verify EBS volumes are deleted

# 4. Wait 30 seconds for AWS to settle

# 5. Try destroy again
make destroy

# 6. If still stuck, manually delete stacks via AWS CLI:
aws cloudformation delete-stack --stack-name hitachi-sds-block-gpfs-levanon-c4qpp --region eu-north-1
```

---

## Useful AWS CLI Commands

Check what's still running:

```bash
# List Hitachi SDS CloudFormation stacks
aws cloudformation list-stacks \
  --region eu-north-1 \
  --stack-status-filter CREATE_COMPLETE ROLLBACK_COMPLETE ROLLBACK_IN_PROGRESS \
  --query 'StackSummaries[?contains(StackName, `hitachi-sds`)]'

# List Hitachi SDS EC2 instances
aws ec2 describe-instances \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=hitachi-sds-block*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value]'

# List Hitachi SDS volumes
aws ec2 describe-volumes \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=*hitachi-sds*" \
  --query 'Volumes[*].[VolumeId,State,Size,Tags[?Key==`Name`].Value]'
```

---

## Manual Cleanup (If Script Fails)

If the script doesn't work, manually clean up in this order:

### 1. Delete CloudFormation Stack

```bash
aws cloudformation delete-stack \
  --region eu-north-1 \
  --stack-name hitachi-sds-block-gpfs-levanon-c4qpp

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --region eu-north-1 \
  --stack-name hitachi-sds-block-gpfs-levanon-c4qpp
```

### 2. Terminate EC2 Instances

```bash
# Find instance IDs
aws ec2 describe-instances \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=hitachi-sds-block*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text

# Terminate
aws ec2 terminate-instances \
  --region eu-north-1 \
  --instance-ids <INSTANCE-IDS>

# Wait for termination
aws ec2 wait instance-terminated \
  --region eu-north-1 \
  --instance-ids <INSTANCE-IDS>
```

### 3. Delete Volumes

```bash
# Find volume IDs
aws ec2 describe-volumes \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=*hitachi-sds*" \
  --query 'Volumes[*].VolumeId' \
  --output text

# Delete (use -v option in script to detach first if attached)
aws ec2 delete-volume \
  --region eu-north-1 \
  --volume-id <VOLUME-ID>
```

### 4. Delete Security Groups

```bash
# Find SG IDs
aws ec2 describe-security-groups \
  --region eu-north-1 \
  --filters "Name=tag:Name,Values=*hitachi-sds-block*" \
  --query 'SecurityGroups[*].GroupId' \
  --output text

# Delete
aws ec2 delete-security-group \
  --region eu-north-1 \
  --group-id <SG-ID>
```

---

## Prevention: Better Destroy Integration

To prevent this in the future, the `destroy.yml` playbook should be updated to clean up SDS resources before OCP destruction.

**Recommended change** (for Makefile or playbook):

```makefile
# In Makefile.hitachi
.PHONY: destroy-sds
destroy-sds:  ## Cleanup Hitachi SDS resources before destroying cluster
	./scripts/cleanup-hitachi-sds-force.sh

# Then modify main destroy target
# destroy: destroy-sds ...
```

Or add to `destroy.yml` playbook:
```yaml
- name: Cleanup Hitachi SDS Block resources first
  block:
    - name: Delete Hitachi CloudFormation stack
      amazon.aws.cloudformation:
        stack_name: "hitachi-sds-block-{{ ocp_cluster_name }}"
        state: absent
        region: "{{ ocp_region }}"
```

---

## Quick Reference

```bash
# Dry run (see what will be deleted)
./scripts/cleanup-hitachi-sds-force.sh --dry-run

# Actual cleanup
./scripts/cleanup-hitachi-sds-force.sh

# Then destroy OCP cluster
make destroy

# Monitor progress
watch 'aws cloudformation list-stacks --region eu-north-1 --query "StackSummaries[?contains(StackName, \`hitachi-sds\`)]"'
```

---

## Troubleshooting

**Script says "access denied":**
```bash
# Set AWS profile
AWS_PROFILE=your-profile ./scripts/cleanup-hitachi-sds-force.sh
```

**Network interface deletion fails:**
```bash
# Manually detach first
aws ec2 detach-network-interface \
  --attachment-id eni-attach-xxxxx \
  --region eu-north-1

# Then delete
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxxx \
  --region eu-north-1
```

**Still seeing resources after cleanup:**
```bash
# Wait for AWS to fully process deletions
sleep 60

# Then check again
./scripts/cleanup-hitachi-sds-force.sh --dry-run
```

---

**Summary:** Run `./scripts/cleanup-hitachi-sds-force.sh` before `make destroy` to prevent it from hanging.
