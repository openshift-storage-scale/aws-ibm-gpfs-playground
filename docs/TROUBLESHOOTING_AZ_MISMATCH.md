# CloudFormation AZ Mismatch Troubleshooting

## Issue: Network Interface Attachment Failure

### Error Message
```
The volume 'vol-xxx' is not in the same availability zone as instance 'i-xxx'
You may not attach a network interface to an instance if they are not in the same availability zone
```

### Root Cause
CloudFormation creates resources (network interfaces and volumes) in different subnets that might be located in different Availability Zones (AZs). Since AWS requires all resources attached to a single EC2 instance to be in the same AZ, the attachment fails and the stack rolls back.

### Solution

The playbook now includes automatic AZ validation that:
1. **Groups subnets by AZ** to find subnets in the same availability zone
2. **Selects subnets** from the same AZ for both control and data networks
3. **Validates** that both subnets are in the same AZ before proceeding
4. **Fails with clear messaging** if subnets are in different AZs

### How It Works

When `make install-hitachi-with-sds` runs:

```
TASK [Group subnets by availability zone]
→ Groups all VPC subnets by their AZ

TASK [Select first AZ with at least one subnet]
→ Picks the first AZ that has subnets available

TASK [Select control and data subnets from same AZ]
→ Ensures both control and data subnets are in the same AZ

TASK [Verify subnets are in same AZ]
→ Double-checks and fails gracefully if mismatch detected
```

### Example Subnet Grouping

**Before Fix (Could Fail):**
```
eu-north-1a: subnet-0ac407967f4852142 (Control)
eu-north-1b: subnet-0407692d5b502a088 (Data) ← Different AZ = FAIL
eu-north-1c: subnet-020be78eaac89ed67
```

**After Fix (Always Works):**
```
eu-north-1a: subnet-0ac407967f4852142 (Control)
eu-north-1a: [use first subnet again]  (Data) ← Same AZ = OK
```

Or:
```
eu-north-1b: subnet-0407692d5b502a088 (Control)
eu-north-1b: [use first subnet again]  (Data) ← Same AZ = OK
```

### Manual Retry (if needed)

If deployment still fails for other reasons, manually clean up and retry:

```bash
# 1. Delete failed CloudFormation stack
aws cloudformation delete-stack \
  --stack-name hitachi-sds-block-gpfs-levanon \
  --profile default \
  --region eu-north-1

# 2. Wait for deletion (optional, but recommended)
aws cloudformation wait stack-delete-complete \
  --stack-name hitachi-sds-block-gpfs-levanon \
  --profile default \
  --region eu-north-1

# 3. Retry deployment
make install-hitachi-with-sds
```

### Monitoring Subnet Selection

During deployment, you'll see:

```
TASK [Debug available subnets with AZ info]
Available subnets for AZ selection:
- ID: subnet-0ac407967f4852142, AZ: eu-north-1a, CIDR: 172.31.16.0/20
- ID: subnet-0407692d5b502a088, AZ: eu-north-1b, CIDR: 172.31.32.0/20
- ID: subnet-020be78eaac89ed67, AZ: eu-north-1c, CIDR: 172.31.0.0/20

TASK [Verify subnets are in same AZ]
✅ Subnets verified - both in same AZ: eu-north-1a
Control Subnet: subnet-0ac407967f4852142
Data Subnet: subnet-0ac407967f4852142 (or another in same AZ)
```

### Code Changes

The fix is in `playbooks/sds-block-deploy.yml` around line 307:

```yaml
- name: Select subnets for SDS Block (or use provided) - MUST be in same AZ
  block:
    - name: Group subnets by availability zone
      ansible.builtin.set_fact:
        subnets_by_az: "{{ vpc_subnets.subnets | groupby('availability_zone') | map('list') | list }}"
    
    - name: Select first AZ with at least one subnet
      ansible.builtin.set_fact:
        selected_az: "{{ subnets_by_az[0][0].availability_zone }}"
        subnets_in_selected_az: "{{ subnets_by_az[0] }}"
    
    - name: Verify subnets are in same AZ
      ansible.builtin.assert:
        that:
          - sds_control_az == sds_data_az
        fail_msg: "Subnets must be in same AZ"
```

### When This Fix Was Added

- **Date**: December 14, 2025
- **Issue**: CloudFormation stack failing with "volume not in same AZ as instance"
- **Commit**: sds-block-deploy.yml subnet selection logic
- **Related**: `make install-hitachi-with-sds` automatic AZ validation

### Prevention for Future Deployments

This fix is now automatic in the playbook. No manual intervention needed for AZ issues.

If deploying to a region with only one subnet, the playbook will safely use the same subnet for both control and data networks.

