# Scripts Organization

Comprehensive organization of all Hitachi deployment and validation scripts.

---

## 📁 Directory Structure

```
scripts/
├── QUICK_START_DEPLOYMENT.sh          ← One-command deployment starter
├── README.md                          ← This file
├── deployment/                        ← Deployment scripts
│   ├── allocate-eip.sh               ← AWS EIP allocation
│   ├── deploy-hitachi-operator.sh    ← Connected deployment
│   ├── deploy-hitachi-operator-disconnected.sh ← Air-gapped deployment
│   ├── deploy-sds-block.sh           ← SDS Block CloudFormation
│   ├── hitachi-complete-setup.sh     ← End-to-end setup
│   ├── prepare-hitachi-namespace.sh  ← Namespace preparation
│   └── prepare-namespaces.sh         ← General namespace setup
├── validation/                        ← Validation & testing scripts
│   ├── check-network-connectivity.sh ← Network diagnostics
│   ├── hitachi-prepare-nodes.sh      ← Node preparation
│   ├── hitachi-test-csi.sh           ← CSI driver testing
│   ├── hitachi-verify-install.sh     ← Installation verification
│   └── troubleshoot-hitachi-deployment.sh ← Comprehensive troubleshooting
├── monitoring/                        ← Monitoring scripts
│   ├── check-deployment-status.sh    ← Quick status check
│   ├── monitor-hitachi-deployment.sh ← Continuous monitoring
│   └── watch-hitachi-deployment.sh   ← Real-time watch
├── utilities/                         ← Utility scripts
│   ├── cleanup-hitachi-sds-force.sh  ← Force cleanup of stuck resources
│   ├── compare-ui-vs-script.sh       ← Compare UI vs CLI deployments
│   ├── download-hitachi-charts.sh    ← Pre-download Helm charts
│   ├── extract-hitachi-yaml.sh       ← Extract deployed YAML
│   └── find-hitachi-image.sh         ← Find container images
└── README.md                          ← This file
```

---

## 🚀 Quick Start

### Deploy Everything

```bash
# Complete deployment in one command
./scripts/QUICK_START_DEPLOYMENT.sh
```

### Step-by-Step Deployment

```bash
# 1. Prepare namespaces and resources
./scripts/deployment/prepare-namespaces.sh

# 2. Deploy SDS Block infrastructure
./scripts/deployment/deploy-sds-block.sh

# 3. Deploy Hitachi operator (choose one)
# For connected environments:
./scripts/deployment/deploy-hitachi-operator.sh

# For air-gapped environments:
./scripts/deployment/deploy-hitachi-operator-disconnected.sh

# 4. Run complete setup (if not done above)
./scripts/deployment/hitachi-complete-setup.sh
```

---

## 📖 Scripts by Category

### 🚀 Deployment Scripts

Used to deploy and configure Hitachi components.

#### `deployment/prepare-namespaces.sh`
**Purpose:** Create and prepare Kubernetes namespaces
**Usage:** `./scripts/deployment/prepare-namespaces.sh`
**Prerequisites:** kubectl access to cluster
**Output:** Created namespaces with RBAC

#### `deployment/deploy-sds-block.sh`
**Purpose:** Deploy Hitachi SDS Block via CloudFormation
**Usage:** `./scripts/deployment/deploy-sds-block.sh`
**Prerequisites:** AWS credentials, VPC configured
**Output:** SDS Block instance with management console
**Key Variables:**
- `OCP_CLUSTER_NAME` - OpenShift cluster name
- `OCP_REGION` - AWS region
- `AWS_PROFILE` - AWS profile to use

#### `deployment/deploy-hitachi-operator.sh`
**Purpose:** Deploy Hitachi operator (connected environment)
**Usage:** `./scripts/deployment/deploy-hitachi-operator.sh`
**Prerequisites:** Internet access to registries
**Output:** Hitachi HSPC operator deployed
**For:** Environments with Docker Hub access

#### `deployment/deploy-hitachi-operator-disconnected.sh`
**Purpose:** Deploy Hitachi operator (air-gapped environment)
**Usage:** `./scripts/deployment/deploy-hitachi-operator-disconnected.sh`
**Prerequisites:** Pre-downloaded charts in local directory
**Output:** Hitachi HSPC operator deployed from manifests
**For:** Disconnected/air-gapped environments

#### `deployment/hitachi-complete-setup.sh`
**Purpose:** Execute all deployment steps in sequence
**Usage:** `./scripts/deployment/hitachi-complete-setup.sh`
**Prerequisites:** All dependencies installed
**Output:** Fully deployed Hitachi system
**Time:** ~30 minutes

#### `deployment/allocate-eip.sh`
**Purpose:** Allocate and configure Elastic IP for SDS Block
**Usage:** `./scripts/deployment/allocate-eip.sh`
**Prerequisites:** AWS credentials, EC2 permissions
**Output:** EIP allocated and associated to instance

---

### ✅ Validation & Testing Scripts

Verify installation and test functionality.

#### `validation/check-network-connectivity.sh`
**Purpose:** Validate network connectivity to services
**Usage:** `./scripts/validation/check-network-connectivity.sh`
**Tests:**
- Kubernetes API connectivity
- Registry reachability
- DNS resolution
- Network policies
**Output:** Network health report

#### `validation/hitachi-prepare-nodes.sh`
**Purpose:** Prepare cluster nodes for Hitachi
**Usage:** `./scripts/validation/hitachi-prepare-nodes.sh`
**Configures:**
- Node labels
- iSCSI multipath
- Required kernel modules
**Output:** Nodes ready for Hitachi workloads

#### `validation/hitachi-verify-install.sh`
**Purpose:** Verify Hitachi installation completeness
**Usage:** `./scripts/validation/hitachi-verify-install.sh`
**Checks:**
- Operator deployment status
- CustomResourceDefinitions
- Namespace configurations
- Required secrets
**Output:** Installation verification report

#### `validation/hitachi-test-csi.sh`
**Purpose:** Test Hitachi CSI driver functionality
**Usage:** `./scripts/validation/hitachi-test-csi.sh`
**Tests:**
- Volume provisioning
- PVC creation
- Pod attachment
- I/O operations
**Output:** CSI driver test results

#### `validation/troubleshoot-hitachi-deployment.sh`
**Purpose:** Comprehensive troubleshooting and diagnostics
**Usage:** `./scripts/validation/troubleshoot-hitachi-deployment.sh`
**Diagnoses:**
- Pod status and events
- Resource definitions
- Network policies
- Volume status
- Recent errors
**Output:** Detailed troubleshooting report

---

### 📊 Monitoring Scripts

Monitor deployment progress and system health.

#### `monitoring/check-deployment-status.sh`
**Purpose:** Quick status check of deployment
**Usage:** `./scripts/monitoring/check-deployment-status.sh`
**Shows:**
- Pod statuses
- Operator status
- Resource count
**Time:** ~5 seconds

#### `monitoring/monitor-hitachi-deployment.sh`
**Purpose:** Continuous monitoring of Hitachi deployment
**Usage:** `./scripts/monitoring/monitor-hitachi-deployment.sh`
**Monitors:**
- Pod lifecycle
- Event logs
- Resource usage
- Error tracking
**Refresh:** Every 10 seconds
**Exit:** Ctrl+C

#### `monitoring/watch-hitachi-deployment.sh`
**Purpose:** Real-time watch of deployment progress
**Usage:** `./scripts/monitoring/watch-hitachi-deployment.sh`
**Features:**
- Live pod status
- Event streaming
- Resource changes
- Log tailing
**Refresh:** Real-time

---

### 🔧 Utility Scripts

Helper scripts for configuration and management.

#### `utilities/download-hitachi-charts.sh`
**Purpose:** Pre-download Helm charts for offline deployment
**Usage:** `./scripts/utilities/download-hitachi-charts.sh`
**Output:** Charts in `./Temp/Hitachi/charts/`
**For:** Air-gapped deployments
**Charts Downloaded:**
- Hitachi HSPC operator chart
- Hitachi CSI driver chart
- Dependencies

#### `utilities/extract-hitachi-yaml.sh`
**Purpose:** Extract YAML from running Hitachi deployment
**Usage:** `./scripts/utilities/extract-hitachi-yaml.sh`
**Output:**
- Operator manifests
- CRDs
- Configurations
**Location:** `./extracted-yaml/`

#### `utilities/compare-ui-vs-script.sh`
**Purpose:** Compare UI-deployed vs script-deployed configurations
**Usage:** `./scripts/utilities/compare-ui-vs-script.sh`
**Compares:**
- YAML definitions
- Resource counts
- Configuration differences
**Output:** Comparison report

#### `utilities/find-hitachi-image.sh`
**Purpose:** Find and verify Hitachi container images
**Usage:** `./scripts/utilities/find-hitachi-image.sh`
**Searches:**
- Local registries
- Docker Hub
- Private registries
**Output:** Image availability report

#### `utilities/cleanup-hitachi-sds-force.sh`
**Purpose:** Force cleanup of stuck Hitachi SDS resources
**Usage:** `./scripts/utilities/cleanup-hitachi-sds-force.sh [OPTIONS]`
**Options:**
```bash
--cluster-name NAME     # OCP cluster name (required)
--region REGION         # AWS region (required)
--profile PROFILE       # AWS profile (optional)
--dry-run              # Preview without making changes
```
**Cleans:**
- CloudFormation stacks
- EC2 instances
- EBS volumes
- Security groups
- Network interfaces
**Note:** Automatically called by `make destroy`

---

## 🔑 Key Variables

Most scripts use these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `OCP_CLUSTER_NAME` | OpenShift cluster name | `gpfs-levanon-c4qpp` |
| `OCP_REGION` | AWS region | `eu-north-1` |
| `AWS_PROFILE` | AWS credential profile | `default` |
| `KUBECONFIG` | Path to kubeconfig | `./ocp_install_files/auth/kubeconfig` |
| `HITACHI_NAMESPACE` | Hitachi operator namespace | `hitachi-system` |
| `HITACHI_VERSION` | Hitachi HSPC version | `3.14.0` |

---

## �� Prerequisites

Before running scripts:

### All Scripts
- ✅ kubectl installed and configured
- ✅ Kubeconfig with cluster access
- ✅ Cluster name and region defined

### Deployment Scripts
- ✅ AWS credentials configured
- ✅ VPC and networking ready
- ✅ Required Kubernetes namespaces
- ✅ Internet access (connected) or pre-downloaded charts (disconnected)

### CloudFormation Scripts
- ✅ AWS CLI configured
- ✅ IAM permissions for CloudFormation, EC2, VPC
- ✅ VPC and subnets available

### Monitoring Scripts
- ✅ kubectl access
- ✅ View pod logs permission

---

## 📋 Common Workflows

### Complete Fresh Deployment
```bash
# 1. Check network
./scripts/validation/check-network-connectivity.sh

# 2. Deploy everything
./scripts/deployment/hitachi-complete-setup.sh

# 3. Verify installation
./scripts/validation/hitachi-verify-install.sh

# 4. Monitor progress
./scripts/monitoring/monitor-hitachi-deployment.sh

# 5. Test CSI driver
./scripts/validation/hitachi-test-csi.sh
```

### Troubleshoot Failed Deployment
```bash
# 1. Quick status check
./scripts/monitoring/check-deployment-status.sh

# 2. Comprehensive troubleshooting
./scripts/validation/troubleshoot-hitachi-deployment.sh

# 3. Check network
./scripts/validation/check-network-connectivity.sh

# 4. Watch real-time changes
./scripts/monitoring/watch-hitachi-deployment.sh
```

### Deploy in Air-Gapped Environment
```bash
# 1. Pre-download charts (on connected machine)
./scripts/utilities/download-hitachi-charts.sh

# 2. Transfer to air-gapped environment
# (sftp/rsync charts to target)

# 3. Deploy from local manifests
./scripts/deployment/deploy-hitachi-operator-disconnected.sh
```

### Clean Up Everything
```bash
# Automatic cleanup (no manual steps needed)
make destroy

# Or manual cleanup
./scripts/utilities/cleanup-hitachi-sds-force.sh \
  --cluster-name gpfs-levanon-c4qpp \
  --region eu-north-1 \
  --dry-run

./scripts/utilities/cleanup-hitachi-sds-force.sh \
  --cluster-name gpfs-levanon-c4qpp \
  --region eu-north-1
```

---

## 🐛 Debugging

### View Script Output
```bash
# Run with verbose output
bash -x ./scripts/deployment/deploy-hitachi-operator.sh

# Capture to file
./scripts/deployment/deploy-hitachi-operator.sh > deploy.log 2>&1
```

### Check Script Logs
```bash
# View Logs directory
ls -la Logs/

# Real-time log monitoring
tail -f Logs/hitachi-deployment-*.log
```

### Common Issues

**"Command not found"**
- Ensure script is executable: `chmod +x scripts/deployment/*.sh`
- Check script path is correct

**"Permission denied"**
- Check kubeconfig permissions
- Verify AWS credentials
- Ensure IAM permissions

**"Cluster not accessible"**
- Set KUBECONFIG: `export KUBECONFIG=./ocp_install_files/auth/kubeconfig`
- Verify kubectl: `kubectl cluster-info`

---

## 📝 Best Practices

1. **Always run validation first**
   ```bash
   ./scripts/validation/check-network-connectivity.sh
   ```

2. **Use dry-run mode when available**
   ```bash
   ./scripts/utilities/cleanup-hitachi-sds-force.sh --dry-run
   ```

3. **Monitor deployment progress**
   ```bash
   ./scripts/monitoring/monitor-hitachi-deployment.sh
   ```

4. **Save logs for debugging**
   ```bash
   ./scripts/deployment/deploy-hitachi-operator.sh > deploy.log 2>&1
   ```

5. **Test after deployment**
   ```bash
   ./scripts/validation/hitachi-test-csi.sh
   ```

---

## 🔗 Related Documentation

For more details, see:
- `docs/hitachi/` - Complete documentation
- `playbooks/` - Ansible playbooks
- `Makefile` - Build and deployment targets

---

## ⚙️ Script Dependencies

```
QUICK_START_DEPLOYMENT.sh
├── deployment/prepare-namespaces.sh
├── deployment/deploy-sds-block.sh
├── deployment/deploy-hitachi-operator-disconnected.sh
├── deployment/hitachi-complete-setup.sh
├── validation/hitachi-verify-install.sh
└── monitoring/check-deployment-status.sh

hitachi-complete-setup.sh
├── deployment/prepare-hitachi-namespace.sh
├── deployment/allocate-eip.sh
├── utilities/download-hitachi-charts.sh
└── deployment/deploy-hitachi-operator-disconnected.sh
```

---

## 📚 Additional Resources

- Hitachi VSP One SDS Documentation: [docs/hitachi/INDEX.md](../hitachi/INDEX.md)
- Playbook Documentation: [docs/hitachi/architecture/](../hitachi/architecture/)
- Makefile Targets: See `make help`

---

**Last Updated:** December 14, 2025
