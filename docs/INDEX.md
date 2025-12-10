# Hitachi SDS Documentation Index

Complete documentation for deploying Hitachi VSP One SDS Block on AWS with OpenShift.

## Quick Navigation

- 📂 **[Repository Organization](./ORGANIZATION.md)** - File structure and documentation layout
- 🚀 **Quick Start:** [Getting Started Guide](./HITACHI_QUICKSTART.md)
- 📖 **Scripts:** [Scripts Codification](./deployment/SCRIPTS_CODIFICATION.md)
- 🔧 **Troubleshooting:** [Troubleshooting Guide](./troubleshooting/)

---

## Quick Start

- **First time setup?** Start with [Quick Start Guide](./HITACHI_QUICKSTART.md)
- **Running scripts?** See [Scripts Codification](./deployment/SCRIPTS_CODIFICATION.md)
- **Troubleshooting issues?** Check [Troubleshooting Guide](./troubleshooting/)

## Documentation Structure

### Deployment Guides
- [Deployment Success Report](./deployment/DEPLOYMENT_SUCCESS.md) - Infrastructure deployment status
- [Hitachi SDS Installation Guide](./deployment/HITACHI_SDS_INSTALLATION_GUIDE.md) - Installation procedures
- [Hitachi Helm Setup Guide](./deployment/HITACHI_HELM_SETUP_GUIDE.md) - Helm deployment guide
- [Hitachi Implementation Summary](./deployment/HITACHI_IMPLEMENTATION_SUMMARY.md) - Overview of implementation
- [CloudFormation Fixes](./deployment/CLOUDFORMATION_FIXES.md) - Template issues and resolutions
- [Scripts Codification](./deployment/SCRIPTS_CODIFICATION.md) - Bash scripts documentation

### Architecture Documentation
- [Playbook Architecture](./architecture/PLAYBOOK_ARCHITECTURE.md) - Ansible playbook design

### Reference
- [Hitachi README](./HITACHI_README.md) - General Hitachi reference

## Getting Started

### Prerequisites
- AWS account with credentials configured
- OpenShift cluster running (or use `make install-hitachi`)
- `kubectl`, `helm`, `ansible`, and `aws` CLI tools installed

### Quick Deployment

```bash
# Complete setup (all phases)
./scripts/deployment/hitachi-complete-setup.sh eu-north-1 gpfs-levanon-c4qpp default

# Or use individual scripts
./scripts/deployment/prepare-namespaces.sh
./scripts/deployment/deploy-hitachi-operator.sh ~/.kube/config hitachi-system 3.14.0
./scripts/deployment/allocate-eip.sh eu-north-1 eni-01fb79c3038d88dcb default
```

### Make Targets

```bash
# Complete setup
make hitachi-complete-setup

# Individual phases
make hitachi-prepare-ns
make hitachi-deploy-operator
make hitachi-allocate-eip

# Information
make hitachi-info
make hitachi-help
```

## Infrastructure Overview

### AWS Resources
- **Region:** eu-north-1
- **EC2 Instance:** m5.2xlarge (Hitachi SDS Block)
- **Network:** Dual ENI (management + data)
- **Storage:** 500GB encrypted EBS volume
- **Security:** Custom security groups with Hitachi-specific ports

### Kubernetes Resources
- **Cluster:** OpenShift 4.15+
- **Namespaces:** hitachi-sds, hitachi-system
- **Operator:** Hitachi Storage Plug-in for Containers (HSPC)
- **Version:** 3.14.0

## Key Components

| Component | Purpose | Status |
|-----------|---------|--------|
| CloudFormation Stack | Infrastructure as Code | ✓ Deployed |
| EC2 Instance | Hitachi SDS Block appliance | ✓ Running |
| HSPC Operator | Container storage integration | ✓ Deployed |
| Storage Classes | PVC provisioning | ✓ Configured |
| Elastic IP | Public console access | ✓ Allocated |

## Common Tasks

### Check Deployment Status
```bash
./scripts/monitoring/monitor-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```

### Monitor in Real-Time
```bash
./scripts/monitoring/watch-hitachi-deployment.sh eu-north-1 hitachi-sds-block-gpfs-levanon-c4qpp
```

### Access Management Console
- URL: `https://<PUBLIC_IP>:8443`
- Credentials: See `ocp_install_files/sds-block-credentials.env`

### Check Operator Pods
```bash
export KUBECONFIG=./ocp_install_files/auth/kubeconfig
kubectl get pods -n hitachi-system -l app=vsp-one-sds-hspc -w
```

### View Operator Logs
```bash
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc --tail=50 -f
```

## Troubleshooting

See [Troubleshooting Guide](./troubleshooting/) for common issues and solutions.

## Support & Resources

- [Hitachi Vantara Documentation](https://docs.hitachivantara.com)
- [OpenShift Documentation](https://docs.openshift.com)
- [Project Repository](https://github.com/openshift-storage-scale/aws-ibm-gpfs-playground)

## File Organization

```
docs/
├── INDEX.md                          # This file
├── HITACHI_README.md                 # General reference
├── HITACHI_QUICKSTART.md             # First-time setup
├── deployment/                       # Deployment guides
│   ├── DEPLOYMENT_SUCCESS.md
│   ├── HITACHI_SDS_INSTALLATION_GUIDE.md
│   ├── HITACHI_HELM_SETUP_GUIDE.md
│   ├── SCRIPTS_CODIFICATION.md
│   ├── CLOUDFORMATION_FIXES.md
│   └── ...
├── architecture/                     # Architecture docs
│   └── PLAYBOOK_ARCHITECTURE.md
└── troubleshooting/                  # Troubleshooting guides
    └── (guides go here)
```

---

**Last Updated:** December 10, 2025  
**Current Version:** Hitachi VSP One SDS 3.14.0  
**Status:** ✓ Production Ready
