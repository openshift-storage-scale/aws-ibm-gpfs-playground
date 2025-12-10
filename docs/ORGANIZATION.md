# Documentation Organization

This document explains the repository structure and documentation organization.

## Repository Structure

```
aws-ibm-gpfs-playground/
├── README.md                    # Main project README
├── Makefile                     # Main build targets
├── Makefile.hitachi             # Hitachi-specific targets
├── ansible.cfg                  # Ansible configuration
├── hosts                        # Ansible inventory
├── requirements.txt             # Python dependencies
├── requirements.yml             # Ansible dependencies
├── overrides.yml                # Configuration overrides
├── hitachi.overrides.yml        # Hitachi-specific overrides
│
├── docs/                        # ⭐ Documentation (ORGANIZED)
│   ├── INDEX.md                 # Documentation index
│   ├── HITACHI_README.md        # Hitachi reference
│   ├── HITACHI_QUICKSTART.md    # Getting started
│   ├── deployment/              # Deployment guides
│   │   ├── DEPLOYMENT_SUCCESS.md
│   │   ├── DEPLOYMENT_STATUS.md
│   │   ├── HITACHI_SDS_INSTALLATION_GUIDE.md
│   │   ├── HITACHI_HELM_SETUP_GUIDE.md
│   │   ├── HITACHI_IMPLEMENTATION_SUMMARY.md
│   │   ├── HITACHI_DEPLOYMENT_SUMMARY.md
│   │   ├── CLOUDFORMATION_FIXES.md
│   │   └── SCRIPTS_CODIFICATION.md
│   ├── architecture/            # Architecture documentation
│   │   └── PLAYBOOK_ARCHITECTURE.md
│   └── troubleshooting/         # Troubleshooting guides
│
├── scripts/                     # ⭐ Automation scripts
│   ├── README.md                # Scripts documentation
│   ├── deployment/              # Deployment scripts
│   │   ├── hitachi-complete-setup.sh
│   │   ├── allocate-eip.sh
│   │   ├── deploy-hitachi-operator.sh
│   │   ├── prepare-namespaces.sh
│   │   ├── deploy-sds-block.sh
│   │   └── prepare-hitachi-namespace.sh
│   └── monitoring/              # Monitoring scripts
│       ├── monitor-hitachi-deployment.sh
│       └── watch-hitachi-deployment.sh
│
├── playbooks/                   # Ansible playbooks
│   ├── install.yml
│   ├── install-hitachi.yml
│   ├── sds-block-deploy.yml
│   ├── _ocp-install-common.yml
│   └── ... (other playbooks)
│
├── templates/                   # Jinja2 templates
│   ├── catalogsource.j2.yaml
│   ├── cluster.yaml
│   └── ... (other templates)
│
├── group_vars/                  # Ansible group variables
│   └── all
│
├── vars/                        # Variable files
│   └── baremetal.yaml
│
├── generated/                   # Generated files (not committed)
│   └── mco-kdump-butaned.yaml
│
├── ocp_install_files/           # OCP installation files
│   ├── auth/
│   ├── .openshift_install.log
│   └── sds-block-credentials.env
│
├── config/                      # Configuration files
│   └── (application-specific configs)
│
└── .gitignore                   # Git exclusions
```

## Documentation Categories

### 📖 Getting Started
- **[Documentation Index](./INDEX.md)** - Start here for all documentation
- **[Hitachi Quick Start](./HITACHI_QUICKSTART.md)** - First-time setup guide

### 🚀 Deployment
Located in `docs/deployment/`:
- **[Deployment Success](./deployment/DEPLOYMENT_SUCCESS.md)** - Infrastructure deployment status
- **[SDS Installation Guide](./deployment/HITACHI_SDS_INSTALLATION_GUIDE.md)** - Installation steps
- **[Helm Setup Guide](./deployment/HITACHI_HELM_SETUP_GUIDE.md)** - Helm configuration
- **[Scripts Codification](./deployment/SCRIPTS_CODIFICATION.md)** - Script documentation
- **[CloudFormation Fixes](./deployment/CLOUDFORMATION_FIXES.md)** - Template solutions

### 🏗️ Architecture
Located in `docs/architecture/`:
- **[Playbook Architecture](./architecture/PLAYBOOK_ARCHITECTURE.md)** - Ansible design

### 🔧 Troubleshooting
Located in `docs/troubleshooting/`:
- (Guides added as needed)

### 📚 Reference
- **[Hitachi README](./HITACHI_README.md)** - General reference

## Key Files & Their Purpose

### Configuration Files
| File | Purpose |
|------|---------|
| `README.md` | Main project documentation |
| `overrides.yml` | Global configuration overrides |
| `hitachi.overrides.yml` | Hitachi-specific configuration |
| `ansible.cfg` | Ansible behavior configuration |
| `hosts` | Ansible inventory |

### Documentation Files
**All `.md` files now organized in `docs/` folder for cleanliness.**

### Scripts
| Directory | Purpose |
|-----------|---------|
| `scripts/deployment/` | Infrastructure and operator deployment scripts |
| `scripts/monitoring/` | Status checking and monitoring scripts |

### Ansible Content
| Directory | Purpose |
|-----------|---------|
| `playbooks/` | Ansible playbooks for deployment |
| `templates/` | Jinja2 templates for K8s/AWS resources |
| `group_vars/` | Ansible variables for host groups |
| `vars/` | Additional variable files |

### Generated & Runtime Files
| Directory | Purpose |
|-----------|---------|
| `ocp_install_files/` | OpenShift installer artifacts |
| `generated/` | Generated resource files |

## Documentation Navigation

### For Users
1. Start with [Documentation Index](./INDEX.md)
2. Quick setup? → [Hitachi Quick Start](./HITACHI_QUICKSTART.md)
3. Full details? → Browse `docs/deployment/` guides
4. Architecture? → [Playbook Architecture](./architecture/PLAYBOOK_ARCHITECTURE.md)

### For Developers
1. Script implementation? → [Scripts Codification](./deployment/SCRIPTS_CODIFICATION.md)
2. Ansible design? → [Playbook Architecture](./architecture/PLAYBOOK_ARCHITECTURE.md)
3. CloudFormation? → [CloudFormation Fixes](./deployment/CLOUDFORMATION_FIXES.md)

### For Troubleshooting
1. Check [Troubleshooting Guide](./troubleshooting/)
2. Review deployment status: [Deployment Status](./deployment/DEPLOYMENT_STATUS.md)
3. Check script logs in `scripts/README.md`

## File Organization Principles

✅ **Main project files** - Stay in root or appropriate subfolder  
✅ **Documentation files** - All go in `docs/` subfolder  
✅ **Scripts** - Organized in `scripts/{deployment,monitoring}/`  
✅ **Configuration** - Top-level YAML files with clear naming  
✅ **Generated files** - In `generated/` or specific subdirectories  

## Benefits of This Structure

| Benefit | How |
|---------|-----|
| **Clean root** | All docs moved to `docs/` |
| **Easy navigation** | Documentation index at `docs/INDEX.md` |
| **Organized scripts** | Deployment vs monitoring scripts separated |
| **Scalable** | Room to add more categories as project grows |
| **Professional** | Industry-standard documentation layout |

## Adding New Documentation

When adding new documentation:

1. Determine category (deployment, architecture, troubleshooting)
2. Save to appropriate `docs/<category>/` folder
3. Update `docs/INDEX.md` with reference
4. Link from top-level README if needed

Example:
```bash
# New deployment guide
echo "# New Guide" > docs/deployment/NEW_GUIDE.md

# Update index
# Add reference to NEW_GUIDE.md in docs/INDEX.md
```

---

**Last Updated:** December 10, 2025  
**Organization Complete:** ✓
