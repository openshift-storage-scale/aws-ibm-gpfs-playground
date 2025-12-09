# Hitachi VSP One SDS Playground - Quick Start

## Overview

The Hitachi VSP One SDS Playground provides a complete setup for testing Hitachi VSP One SDS (Software Defined Storage) on AWS infrastructure integrated with OpenShift Container Platform.

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- Ansible >= 2.10
- kubectl configured to access OpenShift cluster
- AWS CLI configured with credentials
- Helm 3.x installed

## Quick Start

### 1. Configure Environment

Edit `hitachi.overrides.yml` with your preferences:

```yaml
aws_region: us-east-1
hitachi_node_count: 3
hitachi_sds_version: "5.3.0"
```

### 2. Check Prerequisites

```bash
make hitachi-check-prereqs
```

### 3. Deploy Infrastructure

```bash
make hitachi-aws-setup
```

This will:
- Create VPC and subnets
- Launch 3 EC2 instances
- Attach data and journal volumes
- Generate Ansible inventory

### 4. Install Hitachi SDS

```bash
make hitachi-sds-install
```

This will:
- Download Hitachi SDS software
- Initialize cluster
- Configure management network
- Start SDS services

### 5. Configure Storage Pools

```bash
make hitachi-pool-setup
```

### 6. Install CSI Driver

```bash
make hitachi-csi-install
```

### 7. Setup OpenShift Integration

```bash
make hitachi-ocp-setup
```

Creates:
- Storage Classes
- Volume Replication Classes
- RBAC roles

### 8. Validate Installation

```bash
make hitachi-validate
```

### 9. Deploy Example Workload

```bash
make hitachi-deploy-example
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make hitachi-info` | Show Hitachi playground information |
| `make hitachi-help` | List all Hitachi targets |
| `make hitachi-check-prereqs` | Verify prerequisites |
| `make hitachi-plan` | Show infrastructure plan |
| `make hitachi-aws-setup` | Create AWS infrastructure |
| `make hitachi-sds-install` | Install Hitachi SDS |
| `make hitachi-pool-setup` | Configure storage pools |
| `make hitachi-csi-install` | Install CSI driver |
| `make hitachi-ocp-setup` | Setup OCP integration |
| `make hitachi-validate` | Validate installation |
| `make hitachi-deploy-example` | Deploy example |
| `make hitachi-test` | Run tests |
| `make hitachi-status` | Show status |
| `make hitachi-setup-all` | Complete setup |
| `make hitachi-cleanup` | Clean up all resources |

## Architecture

```
AWS Infrastructure
├── VPC (10.1.0.0/16)
├── Subnet (10.1.0.0/24)
├── Security Group
└── 3x EC2 Instances (m5.2xlarge)
    ├── Root volume (100GB)
    ├── Data volume (500GB)
    └── Journal volume (50GB)

Hitachi SDS
├── Cluster (3 nodes)
├── Replication Pool (500GB)
├── Journal Pool (50GB)
└── CSI Driver Integration

OpenShift
├── StorageClass (hitachi-storage)
├── VolumeReplicationClass (async/sync)
└── Example Application
```

## Storage Classes

### hitachi-storage
- High protection level
- Supports replication
- Recommended for production workloads

### hitachi-storage-standard
- Standard protection level
- Cost-optimized
- For non-critical workloads

## Volume Replication

Two replication modes available:

### Asynchronous
- RPO: 60 seconds
- Lower latency, eventual consistency
- Suitable for disaster recovery

### Synchronous
- RPO: 0 seconds
- Higher latency, strict consistency
- Suitable for critical applications

## Monitoring

### Check Hitachi Status

```bash
make hitachi-status
```

### Monitor Volumes

```bash
kubectl get pvc -A -l storage=hitachi
```

### Watch Replication

```bash
kubectl get volumereplication -w
```

## Cleanup

To remove all resources:

```bash
make hitachi-cleanup
```

This will:
- Delete test volumes
- Uninstall CSI driver
- Stop SDS services
- Clean up configuration

Then remove AWS infrastructure:

```bash
terraform -chdir=terraform destroy -auto-approve
```

## Troubleshooting

### Instances not ready

```bash
aws ec2 describe-instances --filters Name=tag:Type,Values=hitachi-sds
```

### Check CSI Driver logs

```bash
kubectl logs -n hitachi-system -l app=hitachi-csi -f
```

### Verify storage pools

```bash
# SSH to Hitachi node
ssh -i ~/.ssh/aws-key.pem ubuntu@<node-ip>
# Check pool status
sudo hitachi-admin show pools
```

## Support

For issues and feature requests, see HITACHI_TROUBLESHOOTING.md

## Next Steps

1. Deploy example workload: `make hitachi-deploy-example`
2. Test replication: `make hitachi-test`
3. Review example configuration in `config/hitachi/examples/`
4. Customize for your use case
