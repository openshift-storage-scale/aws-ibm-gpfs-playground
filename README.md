# Scripts to deploy AWS OCP cluster + GPFS

## 📚 Documentation

**New to this project?** Start with [Documentation Index](./docs/INDEX.md)

For Hitachi SDS specific work, see [Hitachi Documentation](./docs/HITACHI_README.md)

---

## Overview

This repository automates the deployment of an OpenShift cluster on AWS with IBM Spectrum Scale (GPFS) storage using the openshift-fusion-access operator. The setup uses the **FileSystemClaim** controller to automatically create LocalDisk, Filesystem, and StorageClass resources.

## Tear up

Here are the steps to deploy OCP with your choice of storage backend.

### Available Deployment Options

| Command | What It Installs | Instance Type | KVM Support | Duration |
|---------|-----------------|---------------|-------------|----------|
| `make install` | OCP + IBM GPFS (Spectrum Scale) | m5.2xlarge | ❌ No | ~40-45 min |
| `make install-with-virtualization` | OCP + IBM GPFS + KVM | m5zn.metal | ✅ Yes | ~40-45 min |
| `make install-hitachi` | OCP + Hitachi HSPC Operator | m5.2xlarge | ❌ No | ~40-45 min |
| `make install-hitachi-with-sds` | OCP + Hitachi SDS Block + HSPC | m5.2xlarge | ❌ No | ~40-45 min |
| `make install-hitachi-with-virtualization` | OCP + Hitachi + KVM | m5zn.metal | ✅ Yes | ~40-45 min |

> **💡 Tip:** Use `-with-virtualization` targets when running CSI certification tests (Tests 8-17 require VM/KVM support).

### Prerequisites

1. **Ansible dependencies**: 
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```
   
2. **HTTP tools** (for htpasswd):
   - **Fedora**: `dnf install httpd-tools`
   - **macOS**: `brew install httpd`

3. **AWS credentials and CLI**: Ensure AWS credentials are configured and working
   
   The playbooks assume AWS credentials are configured in `~/.aws/`. Two files are required:
   
   **~/.aws/credentials** - Contains AWS access keys:
   ```ini
   [default]
   aws_access_key_id = AKIAIOSFODNN7EXAMPLE
   aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   
   [other-profile]
   aws_access_key_id = AKIAIOSFODNN7EXAMPLE2
   aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY2
   ```
   
   **~/.aws/config** - Contains AWS region configuration:
   ```ini
   [default]
   region = eu-north-1
   output = json
   
   [profile other-profile]
   region = us-east-1
   output = json
   ```
   
   Then test your credentials:
   ```bash
   aws sts get-caller-identity  # Test your credentials
   ```
   
   The scripts use the "default" profile by default. To use a different profile, set `aws_profile: "your-profile-name"` in `overrides.yml`.

4. **RedHat pull secret**: Download from https://console.redhat.com/openshift/downloads
   - Copy to `~/.pullsecret.json`
   - Format should match the example below

5. **Pull Secret File Format**:
   ```json
   {
     "auths": {
       "cloud.openshift.com": {
         "auth": "YOUR_TOKEN_HERE",
         "email": "you@example.com"
       },
       "quay.io": {
         "auth": "YOUR_TOKEN_HERE",
         "email": "you@example.com"
       },
       "registry.redhat.io": {
         "auth": "YOUR_TOKEN_HERE",
         "email": "you@example.com"
       }
     }
   }
   ```

### Installation Steps

#### Step 1: Create `overrides.yml`

```bash
cat << EOF > overrides.yml
# Cluster identification
ocp_cluster_name: "gpfs-<your-user-name>"
gpfs_volume_name: "<your-user-name>-volume"

# AWS Configuration
# Note: aws_profile is REQUIRED for all deployments
# aws_ec2_key_name and aws_vpc_id are ONLY needed for Hitachi SDS deployments
aws_profile: "default"

# ONLY REQUIRED FOR HITACHI SDS BLOCK DEPLOYMENTS:
# Uncomment these only if running: make install-hitachi-with-sds
# aws_ec2_key_name: "your-actual-key-pair"      # EC2 key pair name
# aws_vpc_id: "vpc-0123456789abcdef0"          # VPC ID from AWS Console

# Network Configuration (optional - uncomment to customize)
# ocp_az: "eu-north-1b"
# ocp_region: "eu-north-1"
# ocp_worker_count: 3
# ocp_worker_type: "m5.2xlarge"
# ocp_master_count: 3
# ocp_master_type: "m5.2xlarge"

# Operator configuration (stable for production, alpha for development)
# operator_catalog_tag: stable
# operator_channel: alpha
# pullsecret_extra_file: "{{ '~/.tokens/pull-secret-extra.txt' | expanduser }}"

# GPFS version (must match what the operator supports)
# gpfs_cnsa_version: "v5.2.3.1"

# SSH public key (optional)
# ssh_pubkey: "ssh-ed25519 AAAAC3... your-email@example.com"
EOF
```

#### Step 2: Download OCP Client Tools

```bash
make ocp-clients
```

This downloads the OCP and openshift-install binaries matching your configured version.  
Add the path to your `$PATH` if needed:
```bash
export PATH="$HOME/aws-gpfs-playground/<ocp_version>:$PATH"
```

#### Step 3: Review Configuration

Check `group_vars/all` and ensure all required variables are set correctly.

### Why Different Variables for Different Deployments?

Both `make install` and `make install-hitachi-with-sds` create EC2 instances and infrastructure on AWS. However, they differ in how they create them:

| Variable | GPFS | Hitachi HSPC | Hitachi SDS Block | Purpose |
|----------|------|--------------|-------------------|---------|
| `aws_profile` | ✅ Required | ✅ Required | ✅ Required | AWS CLI profile for authentication |
| `aws_ec2_key_name` | ❌ Not needed | ❌ Not needed | ✅ **Required** | EC2 key pair to SSH into the additional SDS Block instance |
| `aws_vpc_id` | ❌ Not needed | ❌ Not needed | ✅ **Required** | VPC ID to place the additional SDS Block instance in same network as OCP |

**Why?**

- **`make install` (OCP + GPFS)**:
  - Creates 3 master EC2 instances + 3 worker EC2 instances (configurable)
  - Uses **OpenShift Installer**, which automatically creates all infrastructure via CloudFormation
  - OpenShift installer reads VPC/subnet info from AWS account
  - Only needs `aws_profile` - the installer handles everything else
  
- **`make install-hitachi` (OCP + Hitachi HSPC only)**:
  - Creates same 3 master + 3 worker EC2 instances
  - Uses OpenShift Installer (same as above)
  - Only needs `aws_profile` - same as `make install`
  
- **`make install-hitachi-with-sds` (OCP + Hitachi SDS Block)**:
  - Creates 3 master + 3 worker EC2 instances (via OpenShift Installer, using `aws_profile` only)
  - **ADDITIONALLY** creates a 4th EC2 instance for Hitachi SDS Block appliance
  - SDS Block instance needs: `aws_ec2_key_name` (to SSH and configure it) and `aws_vpc_id` (to place it in same VPC)
  - SDS Block CloudFormation template must be deployed separately after OCP cluster creation

#### Step 4: Deploy Your Chosen Stack

**For OCP + IBM GPFS:**
```bash
make install
```

**For OCP + Hitachi HSPC Operator (without SDS Block):**
```bash
make install-hitachi
```

#### Automatic AWS Resource Creation for Hitachi SDS Block

The `make install-hitachi-with-sds` command **automatically creates or discovers** the required AWS resources. You don't need to manually configure them!

**What the automation does:**

1. **EC2 Key Pair (`aws_ec2_key_name`)**:
   - If you don't provide one, it will:
     - Check if you have existing key pairs in your region
     - Use the first available key pair, OR
     - Create a new one automatically named: `<cluster-name>-sds-key`
     - Save the private key to `~/.ssh/<cluster-name>-sds-key.pem`

2. **VPC ID (`aws_vpc_id`)**:
   - If you don't provide one, it will:
     - Automatically detect and use your default VPC, OR
     - Fail with helpful instructions if no default VPC exists

**Quick Start (Recommended):**

Simply run (no configuration needed!):
```bash
make install-hitachi-with-sds
```

The playbook will:
- ✅ Auto-create EC2 key pair if needed
- ✅ Auto-detect default VPC
- ✅ Print the resources it's using
- ✅ Proceed with deployment

**Override Defaults (Optional):**

If you want to specify custom resources instead of letting automation handle it, you can configure them in `overrides.yml`:

```yaml
# Optional: Specify specific EC2 key pair (must exist)
aws_ec2_key_name: "my-existing-key"

# Optional: Specify specific VPC (must exist)
aws_vpc_id: "vpc-0123456789abcdef0"
```

#### Manual AWS Resource Discovery (for reference)

If you want to manually find or create these resources instead of letting automation handle it:

##### Finding Your `aws_vpc_id`

**Option A: Use your existing default VPC**
```bash
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --profile default \
  --output text
```

**Option B: List all VPCs and choose one**
```bash
aws ec2 describe-vpcs \
  --profile default \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

##### Finding or Creating Your `aws_ec2_key_name`

**Option A: List existing key pairs**
```bash
aws ec2 describe-key-pairs \
  --profile default \
  --region eu-north-1 \
  --query 'KeyPairs[*].KeyName' \
  --output table
```

**Option B: Create a new key pair**
```bash
aws ec2 create-key-pair \
  --key-name my-new-sds-key \
  --profile default \
  --region eu-north-1 \
  --query 'KeyMaterial' \
  --output text > ~/my-new-sds-key.pem

chmod 600 ~/my-new-sds-key.pem
```

Then add these to `overrides.yml`:
```yaml
aws_ec2_key_name: "my-new-sds-key"
aws_vpc_id: "vpc-0123456789abcdef0"
```

> **⏱️ Execution Time:** Installation takes approximately **40-45 minutes** to complete.  
> This includes AWS infrastructure provisioning, OpenShift bootstrapping, and cluster configuration.

9. **Retrieve Cluster Access Information**

Once the installation is complete, find your cluster credentials:
```bash
# View the installation log
cat ~/aws-gpfs-playground/ocp_install_files/.openshift_install.log | grep -A 20 "Install complete!"
```

The log will contain:
````
- **KUBECONFIG** path: `auth/kubeconfig`
- **Web Console URL**: `https://console-openshift-console.apps.<cluster>.<domain>`
- **Login credentials**: `kubeadmin` username with password from log

10. **Login to Your Cluster**

```bash
export KUBECONFIG=~/aws-gpfs-playground/ocp_install_files/auth/kubeconfig
oc login -u kubeadmin -p <password> https://api.<cluster>.<domain>:6443
```

## Virtualization Support (CNV/KVM Testing)

The default worker instance type (`m5.2xlarge`) does **not support KVM virtualization**. This causes VM-based workloads (OpenShift Virtualization, KubeVirt, CSI certification VM tests) to fail with:

```
0/6 nodes are available: 3 Insufficient devices.kubevirt.io/kvm
```

### Enabling Virtualization Support

To run workloads that require KVM virtualization, use one of these approaches:

#### Option 1: Use the Virtualization-Enabled Make Targets (Recommended)

```bash
# For GPFS with virtualization
make install-with-virtualization

# For Hitachi with virtualization
make install-hitachi-with-virtualization
```

#### Option 2: Set in overrides.yml

```yaml
enable_virtualization: true
```

Then run your normal install command:
```bash
make install
# or
make install-hitachi
```

#### Option 3: Direct Instance Type Override

```yaml
ocp_worker_type: "m5zn.metal"
```

### Metal Instance Comparison

| Instance Type | vCPUs | Memory | Network | Cost/hr (approx) | Best For |
|---------------|-------|--------|---------|------------------|----------|
| m5.2xlarge | 8 | 32 GiB | Up to 10 Gbps | ~$0.38 | Storage testing only |
| **m5zn.metal** | 48 | 192 GiB | 100 Gbps | ~$3.96 | **Recommended** - best cost/performance for KVM |
| c5.metal | 96 | 192 GiB | 25 Gbps | ~$4.08 | Compute-intensive workloads |
| m5.metal | 96 | 384 GiB | 25 Gbps | ~$4.60 | Large memory workloads |

### Cost Impact

| Configuration | Instance Type | Workers | Estimated Cost/hr |
|---------------|---------------|---------|-------------------|
| Storage Only | m5.2xlarge | 3 | ~$1.14 |
| **With Virtualization** | m5zn.metal | 3 | **~$11.88** |

> **⚠️ Cost Warning:** Metal instances are ~10x more expensive than standard instances. Use only when virtualization testing is required.

### Verifying KVM Support

After deploying with metal instances:

```bash
# Check for KVM device on worker nodes
oc debug node/<worker-node-name> -- chroot /host ls -la /dev/kvm

# Check kubevirt node labels
oc get nodes -l kubevirt.io/schedulable=true -o wide

# Verify no KVM-related scheduling issues
oc get pods -A | grep virt-launcher
```

### Region and Availability Zone Limitations

**⚠️ Important:** Metal instances (`m5zn.metal`) are NOT available in all regions or availability zones. This affects where you can deploy clusters with virtualization support.

#### Known Supported Regions for m5zn.metal

| Region | Availability Zones with m5zn.metal |
|--------|-----------------------------------|
| eu-north-1 (Stockholm) | eu-north-1a, eu-north-1b |
| us-east-1 (N. Virginia) | us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f |
| us-west-2 (Oregon) | us-west-2a, us-west-2b, us-west-2c |
| eu-west-1 (Ireland) | eu-west-1a, eu-west-1b, eu-west-1c |

#### Check Availability in Your Region

```bash
# Check which AZs have m5zn.metal in your region
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=m5zn.metal \
  --region eu-north-1 \
  --query 'InstanceTypeOfferings[*].Location' \
  --output table

# Example output:
# ----------------------
# |    Location         |
# +---------------------+
# |  eu-north-1a        |
# |  eu-north-1b        |
# ----------------------
```

#### Configuring for Metal Instance Availability

If deploying with virtualization, ensure your `overrides.yml` uses a supported AZ:

```yaml
# Make sure the AZ supports m5zn.metal
ocp_az: "eu-north-1b"        # Must have m5zn.metal availability
ocp_region: "eu-north-1"

# This will be set automatically when using -with-virtualization targets
# enable_virtualization: true
```

> **Note:** If deployment fails with "Insufficient capacity" errors, try a different AZ within the same region.

---

## Architecture

The deployment now uses the **FileSystemClaim** controller pattern:

1. **FileSystemClaim**: A high-level resource that declares storage requirements with device paths
2. **Automatic Resource Creation**: The FileSystemClaim controller automatically creates:
   - LocalDisk resources for each device
   - Filesystem resource using those LocalDisks
   - StorageClass for application consumption
3. **Device Discovery**: The operator discovers available devices via LocalVolumeDiscoveryResult (LVDR)
4. **Test Workloads**: Writer and reader deployments validate the storage functionality

### What Gets Created

- **Operator namespace**: `ibm-fusion-access`
- **GPFS namespace**: `ibm-spectrum-scale`
- **FileSystemClaim**: `filesystemclaim-sample` (creates LocalDisk, Filesystem, StorageClass)
- **Test namespace**: `ibm-test-deployment` (with writer/reader deployments)
- **StorageClass**: `filesystemclaim-sample` (RWX persistent volumes)

## Cleanup and Tear Down

### Destroy Entire Cluster

To delete the OCP cluster and all associated AWS resources (including SDS Block if deployed):

```bash
make destroy
```

This will:
1. Automatically detect if Hitachi SDS Block was deployed
2. Clean up SDS Block resources (EC2 instances, CloudFormation stacks, volumes)
3. Destroy the OpenShift cluster
4. Remove all AWS infrastructure

### Delete GPFS Objects (without destroying cluster)

To remove only GPFS-related objects while keeping the cluster running:

```bash
make gpfs-cleanup
```

This removes:
- FileSystemClaim resources
- GPFS filesystem configurations
- Test deployments
- FusionAccess CR

### Other Cleanup Operations

**Remove iSCSI resources** (if deployed):
```bash
make iscsi-cleanup
```

**Remove EBS volumes** (if added separately):
```bash
EXTRA_VARS="-e volume_id=vol-0123456789abcdef0" make ebs-remove
```

## Health Check

Run `make gpfs-health` to run some GPFS healthcheck commands

## Add a new EBS volume to a running OCP cluster

To add a new EBS volume to a specific set of EC2 instances in your running OpenShift cluster, you can use the `ebs-add.yml` playbook. This playbook is conveniently aliased via `make ebs-add` for ease of use.

### Usage

1. **Specify the target instances**  
   You can target specific EC2 instances by providing their instance IDs or by defining a filter to select them based on tags or other attributes.

   - **Using instance IDs**:  
     Create or edit your `overrides.yml` file and set the `instance_ids` variable with a list of EC2 instance IDs:
     ```yaml
     instance_ids:
       - "i-0123456789abcdef0"
       - "i-fedcba9876543210f"
     ```
     > **Note:** If you specify `instance_ids`, the playbook will attach the new EBS volume to these instances.

   - **Using a filter**:  
     Alternatively, you can use `instance_filter` to select instances by tag or other criteria:
     ```yaml
     instance_filter:
       "tag:Name": "my-cluster-name*worker*"
       "instance-state-name": "running"
     ```
     > If `instance_ids` is empty, the playbook will use `instance_filter` to find matching instances.

2. **Override other variables as needed**  
   The playbook supports many overridable variables, such as `volume_size`, `volume_type`, `multi_attach`, `iops`, `throughput`, and more.  
   For example, to create a 200 GiB `gp3` volume:
   ```yaml
   volume_size: 200
   volume_type: "gp3"
   throughput: 125
   ```

   > **Tip:** Check out the `playbooks/ebs-add.yml` file to see the full list of variables you can override to customize the volume and attachment behavior.

3. **Run the playbook**  
   Use the provided Makefile target to run the playbook:
   ```
   make ebs-add
   ```

   This will create and attach the EBS volume to the specified instances using your current `overrides.yml` settings.

## Remove an existing EBS volume

To remove an existing EBS volume attached to a set of EC2 instances, you can use the `ebs-remove.yml` playbook. This playbook is aliased via `make ebs-remove` for convenience.

### Usage

1. **Identify the EBS volume to remove**  
   You need the EBS volume ID (e.g., `vol-0123456789abcdef0`) that you wish to detach and delete. You can find this in the AWS Console or by using the AWS CLI.

2. **Set the `volume_id` variable**  
   Specify the volume ID in your `overrides.yml` file:
   ```yaml
   volume_id: "vol-0123456789abcdef0"
   ```
   Alternatively, you can pass it directly on the command line:
   ```
   EXTRA_VARS="-e volume_id=vol-0123456789abcdef0" make ebs-remove
   ```

3. **Run the playbook**  
   Use the provided Makefile target to execute the removal:
   ```
   make ebs-remove
   ```
   This will:
   - Validate that the volume exists.
   - Detach it from any attached instances.
   - Wait for the volume to become available.
   - Delete the volume.

    > **Caution:** Deleting an EBS volume is irreversible. Ensure you have backups or snapshots if you need to retain the data.

> **Note:** You can review and customize the removal process by editing `playbooks/ebs-remove.yml`.

## Cleanup of Stale AWS Resources

Failed OpenShift deployments may leave behind orphaned AWS resources that block new deployments by hitting AWS hard limits.

To preview and clean up stale AWS resources:

```bash
make aws-cleanup-stale-resources-dryrun    # Preview cleanup (safe - no deletion)
make aws-cleanup-stale-resources           # Run actual cleanup
```

For detailed information, troubleshooting, and usage scenarios, see the **[AWS Comprehensive Cleanup Guide](docs/AWS_COMPREHENSIVE_CLEANUP_GUIDE.md)**.


