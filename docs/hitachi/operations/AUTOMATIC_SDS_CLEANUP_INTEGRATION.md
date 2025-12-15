# Automatic Hitachi SDS Cleanup Integration

## Overview

The `destroy.yml` playbook has been updated to **automatically detect and clean up Hitachi SDS Block resources** before destroying the OCP cluster.

---

## How It Works

### Detection Mechanism

The playbook uses **two detection methods**:

1. **Marker File Check**
   - Created by `sds-block-deploy.yml` when SDS deployment completes
   - Location: `{{ ocp_cluster_name }}_sds_installed` (in OCP folder)
   - Fast and reliable indicator that SDS was deployed

2. **CloudFormation Stack Check**
   - Queries AWS for CloudFormation stack: `hitachi-sds-block-{{ ocp_cluster_name }}`
   - Detects SDS installation even if marker file is missing
   - Handles cases where deployment failed partway through

### Execution Flow

When `make destroy` is run:

```
1. Check if SDS was installed (via marker file OR CloudFormation stack)
   ↓
2. If SDS detected:
   - Display: "Hitachi SDS detected - will run cleanup"
   - Execute: ./scripts/cleanup-hitachi-sds-force.sh
   - Parameters: --cluster-name and --region (auto-passed)
   - Wait for cleanup to complete (up to 10 minutes)
   - Wait 30 seconds for AWS to settle
   ↓
3. Proceed with normal OCP cluster destruction
```

---

## Changes Made

### 1. Updated: `playbooks/destroy.yml`

**Added at beginning (before metadata check):**

```yaml
- name: Check if Hitachi SDS Block was installed
  ansible.builtin.stat:
    path: "{{ ocp_cluster_name }}_sds_installed"
  register: sds_installed_marker

- name: Check for Hitachi SDS CloudFormation stack
  amazon.aws.cloudformation_info:
    profile: "{{ aws_profile }}"
    region: "{{ ocp_region }}"
    stack_name: "hitachi-sds-block-{{ ocp_cluster_name }}"
  register: sds_cf_stack
  failed_when: false

- name: Set fact if SDS was installed
  ansible.builtin.set_fact:
    sds_installed: "{{ sds_installed_marker.stat.exists or (sds_cf_stack.cloudformation | default({}) | length > 0) }}"

- name: Run Hitachi SDS force cleanup script
  ansible.builtin.shell: |
    "$SCRIPT_PATH" --cluster-name "{{ ocp_cluster_name }}" --region "{{ ocp_region }}" --profile "{{ aws_profile }}"
  when: sds_installed | bool
  register: sds_cleanup_result

- name: Wait for CloudFormation stack deletion to complete
  amazon.aws.cloudformation_info:
    ...
  retries: 60
  delay: 10
  when: sds_installed | bool
```

**Result:** SDS resources are cleaned up automatically before OCP destruction.

### 2. Updated: `playbooks/sds-block-deploy.yml`

**Added at end (after config file creation):**

```yaml
- name: Create marker file indicating SDS was installed
  ansible.builtin.copy:
    content: |
      # Marker file indicating Hitachi SDS Block was successfully deployed
      # Created by sds-block-deploy.yml playbook
      # Cluster Name: {{ ocp_cluster_name }}
      # Region: {{ ocp_region }}
      # Stack Name: {{ sds_stack_name }}
      # Deployment Time: {{ ansible_date_time.iso8601 }}
    dest: "{{ ocpfolder }}/../{{ ocp_cluster_name }}_sds_installed"
    mode: '0644'
```

**Result:** Marker file created so destroy knows SDS was installed.

---

## Usage

### Normal Workflow

```bash
# Deploy SDS Block
make sds-deploy
# → Creates marker file: gpfs-levanon-c4qpp_sds_installed

# Later, destroy cluster
make destroy
# → Automatically detects SDS installation
# → Runs cleanup-hitachi-sds-force.sh
# → Then destroys OCP cluster
```

### If SDS Deployment Failed

Even if `sds-block-deploy.yml` fails, `make destroy` will still:
1. Detect orphaned CloudFormation stack in AWS
2. Run cleanup script automatically
3. Ensure all resources are cleaned before OCP destruction

---

## Monitoring Cleanup

Watch cleanup progress:

```bash
# Monitor SDS cleanup
make destroy 2>&1 | grep -A 5 "Hitachi SDS"

# Or watch CloudFormation stack deletion
watch 'aws cloudformation list-stacks \
  --region eu-north-1 \
  --query "StackSummaries[?contains(StackName, \`hitachi-sds\`)]"'
```

---

## Cleanup Details

When cleanup runs, it:

1. **Deletes CloudFormation Stack** (hitachi-sds-block-{{ ocp_cluster_name }})
2. **Terminates EC2 Instance** (SDS management instance)
3. **Deletes EBS Volumes** (data and root volumes)
4. **Removes Security Groups** (Hitachi-related)
5. **Cleans Network Interfaces** (orphaned ENIs)
6. **Waits 30 seconds** for AWS to fully process deletions
7. **Monitors CloudFormation** for up to 10 minutes (retries: 60, delay: 10 seconds)

---

## Failure Handling

If cleanup encounters errors:

- **Non-blocking errors** are logged but don't stop destruction
- **Script execution errors** are reported but retry-able
- **Network timeouts** are handled with automatic retries
- **If cleanup fails**, you can still run cleanup manually:

```bash
# Manual cleanup if needed
./scripts/cleanup-hitachi-sds-force.sh --cluster-name gpfs-levanon-c4qpp --region eu-north-1
```

---

## Configuration Variables

The cleanup is automatically configured using:

| Variable | Source | Used For |
|----------|--------|----------|
| `ocp_cluster_name` | group_vars/all | Stack name, marker file |
| `ocp_region` | group_vars/all | AWS region for cleanup |
| `aws_profile` | group_vars/all or override | AWS profile for API calls |
| `basefolder` | setup | Path to cleanup script |

These are already defined in your Ansible setup - no additional configuration needed!

---

## Marker File Location

The marker file is created at:

```
{{ ocp_cluster_name }}_sds_installed
```

For cluster `gpfs-levanon-c4qpp`, it's located at:

```
/home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground/gpfs-levanon-c4qpp_sds_installed
```

To manually indicate SDS is installed (without deployment):

```bash
touch gpfs-levanon-c4qpp_sds_installed
```

To disable automatic SDS cleanup:

```bash
rm gpfs-levanon-c4qpp_sds_installed
```

---

## Summary

✅ **Automatic Detection** - Detects SDS via marker file or CloudFormation stack  
✅ **Automatic Cleanup** - Runs `cleanup-hitachi-sds-force.sh` automatically  
✅ **Safe Defaults** - Non-blocking errors allow destruction to proceed  
✅ **Monitoring** - Full output logged and displayed during cleanup  
✅ **Failover** - CloudFormation stack check detects partial deployments  
✅ **Zero Configuration** - Uses existing Ansible variables

Now `make destroy` will automatically handle Hitachi SDS Block cleanup! 🎉
