# CSI Certification Testing Guide

This guide explains how to set up an AWS OpenShift cluster with storage (GPFS or Hitachi SDS), install OpenShift CNV (KubeVirt), and run the [KubeVirt Storage Checkup](https://github.com/nadavleva/kubevirt-storage-checkup/blob/csireplicpg/docs/csi-tests.md) CSI certification tests.

## Prerequisites

### 1. Local Environment Requirements

```bash
# Required tools
- AWS CLI configured with credentials
- Ansible 2.14+
- Python 3.9+
- oc (OpenShift CLI) - will be downloaded automatically
- helm (for Hitachi SDS)

# Install Ansible dependencies
make ansible-deps
```

### 2. Configuration Files

Create/update `overrides.yml` with your settings:

```yaml
# Cluster configuration
ocp_cluster_name: "my-cluster"
ocp_region: "eu-north-1"
ocp_az: "eu-north-1b"
ocp_worker_count: 3  # Minimum 2 for live migration tests
ocp_worker_type: "m5.2xlarge"
ocp_version: "4.20.8"

# AWS configuration
aws_profile: "default"

# Pull secret from Red Hat Console
pullsecret: "{{ lookup('file', '~/.pullsecret.json') }}"
ssh_pubkey: "ssh-ed25519 AAAAC3..."

# Storage checkup configuration (optional overrides)
storage_checkup_storageclass: "ibm-test-sc"  # or "hitachi-sds-sc"
```

For Hitachi, also create `hitachi.overrides.yml`:

```yaml
hitachi_array_id: "your-array-id"
hitachi_array_name: "your-array-name"
hitachi_sds_version: "1.13.0"
```

### 3. Required Secrets

```bash
# Red Hat pull secret
~/.pullsecret.json

# IBM entitlement key (for GPFS)
~/.ibm-entitlement-key

# SSH public key
~/.ssh/id_rsa.pub
```

---

## Installation Paths

Choose ONE of the following installation paths based on your storage backend:

### Option A: IBM GPFS / Spectrum Scale

```bash
# Full installation: OCP + GPFS + CNV + CSI Certification
make install && make cnv-install && make storage-checkup
```

### Option B: Hitachi VSP One SDS

```bash
# Full installation: OCP + Hitachi SDS + CNV + CSI Certification
make install-hitachi-with-sds && make cnv-install && make storage-checkup
```

---

## Step-by-Step Installation

### Phase 1: Deploy AWS OpenShift Cluster + Storage

#### For IBM GPFS:

```bash
# Install OCP cluster with IBM Spectrum Scale (GPFS)
make install
```

This will:
1. Download OCP installer and clients
2. Create AWS infrastructure (VPC, subnets, etc.)
3. Deploy OpenShift cluster (~45 minutes)
4. Configure security groups for GPFS ports
5. Attach shared EBS volumes to workers
6. Install IBM Fusion Access operator
7. Create GPFS filesystem and StorageClass

#### For Hitachi SDS:

```bash
# Install OCP cluster with Hitachi VSP One SDS
make install-hitachi-with-sds
```

This will:
1. Deploy Hitachi VSP One SDS Block on AWS (optional)
2. Create AWS infrastructure
3. Deploy OpenShift cluster
4. Configure security groups for Hitachi ports (iSCSI, API)
5. Install Hitachi HSPC operator via Helm
6. Create StorageClass and VolumeReplicationClass

---

### Phase 2: Install OpenShift CNV (KubeVirt)

```bash
# Install OpenShift Virtualization operator
make cnv-install
```

This will:
1. Create `openshift-cnv` namespace
2. Deploy the CNV operator subscription
3. Wait for operator to be ready
4. Create HyperConverged CR with storage live migration feature gates
5. Download `virtctl` CLI
6. Verify installation

**Verification:**
```bash
export KUBECONFIG=~/aws-gpfs-playground/ocp_install_files/auth/kubeconfig
oc get csv -n openshift-cnv
oc get hyperconverged -n openshift-cnv
oc get storageprofiles
```

---

### Phase 3: Run CSI Certification Tests

```bash
# Run the KubeVirt Storage Checkup
make storage-checkup
```

This will:
1. Create `storage-checkup` namespace
2. Apply RBAC permissions (ServiceAccount, Role, ClusterRole)
3. Create checkup ConfigMap with test parameters
4. Deploy the checkup Job
5. Wait for completion
6. Display results

**Monitor Progress:**
```bash
# Stream logs
make storage-checkup-logs

# Or manually
oc logs -f job/storage-checkup -n storage-checkup
```

**View Results:**
```bash
# Formatted results
make storage-checkup-results

# Raw ConfigMap
oc get configmap storage-checkup-config -n storage-checkup -o yaml
```

---

## CSI Certification Test Cases

Based on [csi-tests.md](https://github.com/nadavleva/kubevirt-storage-checkup/blob/csireplicpg/docs/csi-tests.md):

| # | Test Case | CSI APIs Validated | Pass Criteria |
|---|-----------|-------------------|---------------|
| 1 | Version Detection | - | OCP/CNV versions reported |
| 2 | Default Storage Class | - | Exactly one default SC |
| 3 | PVC Creation & Binding | `CreateVolume`, `ControllerPublishVolume` | PVC binds within timeout |
| 4 | Storage Profiles - ClaimPropertySets | - | No empty ClaimPropertySets |
| 5 | Storage Profiles - Smart Clone | `CreateVolume` (clone) | CSI/snapshot clone supported |
| 6 | Storage Profiles - RWX | `MULTI_NODE_MULTI_WRITER` | RWX detected (informational) |
| 7 | VolumeSnapshotClass | `CreateSnapshot`, `DeleteSnapshot` | VSC exists for profiles |
| 8 | Golden Images - DataImportCron | - | DICs are up-to-date |
| 9 | Golden Images - DataSource | - | Valid PVC/snapshot source |
| 10 | VM Storage Class - RBD | - | VMs use optimized class |
| 11 | VM Storage Class - EFS | - | EFS has uid/gid configured |
| 12 | VM Boot from Golden Image | `CreateVolume` (from snapshot) | VM boots, agent connects |
| 13 | Volume Clone Type | `CreateVolume` (clone) | `snapshot` or `csi-clone` |
| 14 | VM Live Migration | `MULTI_NODE_MULTI_WRITER` | Migration completes (2+ nodes) |
| 15 | Volume Hotplug - Attach | `ControllerPublishVolume`, `NodeStageVolume` | Volume ready |
| 16 | Volume Hotplug - Detach | `ControllerUnpublishVolume`, `NodeUnstageVolume` | Volume removed |
| 17 | Concurrent VM Boot | Multiple `CreateVolume` | All 10 VMs boot |

---

## Cluster Requirements for Full Certification

| Requirement | Minimum | Recommended | Notes |
|-------------|---------|-------------|-------|
| **Worker Nodes** | 1 | 2+ | Live migration (Test 14) requires 2+ |
| **Storage Class** | 1 default | 1 default | With VolumeSnapshotClass |
| **CNV Installed** | Yes | Yes | Required for VM tests (8-17) |
| **RWX Support** | No | Yes | Required for live migration |

---

## Configuration Options

Edit `group_vars/all` to customize:

```yaml
# Storage Checkup Configuration
storage_checkup_namespace: "storage-checkup"
storage_checkup_storageclass: "ibm-test-sc"    # Storage class to test
storage_checkup_timeout: "15m"                  # Overall timeout
storage_checkup_vmi_timeout: "5m"               # VM operation timeout
storage_checkup_num_vms: "10"                   # Concurrent VMs for stress test
storage_checkup_skip_teardown: "never"          # Options: always, onfailure, never
storage_checkup_wait_timeout: "20m"             # Wait for completion
storage_checkup_image: "quay.io/kiagnose/kubevirt-storage-checkup:main"
```

---

## Running Checkup Against External Project

To run the e2e tests from the [kubevirt-storage-checkup](https://github.com/nadavleva/kubevirt-storage-checkup/blob/csireplicpg/Makefile) project directly:

```bash
# Clone the project
git clone https://github.com/nadavleva/kubevirt-storage-checkup.git
cd kubevirt-storage-checkup
git checkout csireplicpg

# Set environment
export KUBECONFIG=~/aws-gpfs-playground/ocp_install_files/auth/kubeconfig
export TEST_NAMESPACE=storage-checkup
export TEST_IMAGE=quay.io/kiagnose/kubevirt-storage-checkup:main

# Run e2e tests (requires podman/docker)
make e2e-test
```

---

## Quick Reference: Make Targets

```bash
# Show all available targets
make help

# ===== Full Installation Paths =====
# GPFS path
make install && make cnv-install && make storage-checkup

# Hitachi path
make install-hitachi-with-sds && make cnv-install && make storage-checkup

# ===== Individual Targets =====
# Phase 1: Cluster + Storage
make install                    # OCP + GPFS
make install-hitachi            # OCP + Hitachi operator
make install-hitachi-with-sds   # OCP + Hitachi + SDS Block

# Phase 2: CNV
make cnv-install               # Install OpenShift CNV

# Phase 3: CSI Certification
make storage-checkup           # Run checkup tests
make storage-checkup-results   # View results (formatted)
make storage-checkup-logs      # Stream job logs
make storage-checkup-cleanup   # Clean up resources

# ===== Utilities =====
make gpfs-health               # GPFS health check
make hitachi-validation        # Hitachi validation
make destroy                   # Destroy cluster
```

---

## Troubleshooting

### Checkup Fails to Start

```bash
# Check if CNV is installed
oc get csv -n openshift-cnv

# Check if storage class exists
oc get storageclass

# Check RBAC permissions
oc get clusterrolebinding | grep storage-checkup
```

### Live Migration Test Skipped

- Requires 2+ worker nodes
- Check: `oc get nodes --selector='node-role.kubernetes.io/worker'`

### Golden Images Not Ready

```bash
# Check DataImportCrons
oc get dataimportcron -n openshift-virtualization-os-images

# Check DataSources
oc get datasource -n openshift-virtualization-os-images
```

### Storage Profile Issues

```bash
# Check storage profiles
oc get storageprofiles

# Check if CSI driver supports cloning
oc get storageprofile <name> -o yaml | grep -A5 claimPropertySets
```

---

## References

- [KubeVirt Storage Checkup - CSI Tests](https://github.com/nadavleva/kubevirt-storage-checkup/blob/csireplicpg/docs/csi-tests.md)
- [Red Hat CSI Certification](http://docs.redhat.com/en/documentation/red_hat_software_certification/2025/html/red_hat_software_certification_workflow_guide/con_csi-certification_openshift-sw-cert-workflow-working-with-container-network-interface)
- [Running Storage Checkup via OpenShift Console](https://docs.openshift.com/container-platform/latest/virt/monitoring/virt-running-cluster-checkups.html)

