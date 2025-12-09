# Playbook Architecture - OCP + Storage Integration

## Overview

This document describes the refactored playbook architecture that enables deploying OCP clusters with different storage backends (GPFS or Hitachi SDS) without code duplication.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│           Common OCP Provisioning Layer                      │
│    (_ocp-install-common.yml - 156 lines)                    │
│                                                              │
│  • AWS identity retrieval and owner tagging                 │
│  • Prerequisite verification (htpasswd, IBM entitlement)    │
│  • OCP cluster installation (openshift-install)            │
│  • kubeconfig validation                                    │
│  • kubeadmin password setup                                 │
└─────────────────────────────────────────────────────────────┘
                        ▲ (included by both)
       ┌────────────────┴────────────────┐
       │                                  │
 ┌─────▼──────────┐            ┌────────▼──────────┐
 │  install.yml   │            │install-hitachi.yml│
 │   (GPFS Path)  │            │ (Hitachi Path)    │
 │                │            │                   │
 │ • Include OCP  │            │ • Include OCP     │
 │ • GPFS sec     │            │ • Hitachi sec     │
 │   groups       │            │   groups          │
 │ • EBS volumes  │            │ • Helm deploy     │
 │ • GPFS op      │            │ • StorageClass    │
 │                │            │ • VRC setup       │
 └────────────────┘            └───────────────────┘
```

## File Structure

### Layer 1: Common OCP Installation
**File:** `playbooks/_ocp-install-common.yml` (156 lines)

Provides all OCP provisioning logic shared by both GPFS and Hitachi deployment paths:

- AWS identity retrieval and owner tagging
- Prerequisite verification (htpasswd, IBM entitlement)
- OCP cluster folder creation
- install-config.yaml template generation
- openshift-install execution with error handling
- kubeconfig validation
- kubeadmin password setup

**Key Feature:** Single source of truth for OCP provisioning. Changes here automatically apply to both GPFS and Hitachi paths.

### Layer 2: GPFS Path
**File:** `playbooks/install.yml` (180 lines)

Deploys OCP cluster with IBM GPFS storage:

```
Phase 1: Common OCP Installation
  ├─ Include: _ocp-install-common.yml
  └─ Result: Ready OCP cluster with kubeconfig

Phase 2: AWS Infrastructure (GPFS-Specific)
  ├─ Retrieve worker security group
  ├─ Add GPFS ports: 12345, 1191, 60000-61000
  └─ Result: GPFS-ready network configuration

Phase 3: EBS Storage (GPFS-Specific)
  ├─ Discover EC2 worker instances
  ├─ Create primary EBS volume (io2, multi-attach)
  ├─ Create secondary EBS volume (if baremetal)
  ├─ Attach volumes to workers
  └─ Result: Storage volumes ready for GPFS

Phase 4: GPFS Installation
  ├─ Include: operator-install.yml
  └─ Result: GPFS operator deployed

Phase 5: GPFS Configuration
  ├─ Include: gpfs-setup.yml
  └─ Result: GPFS filesystem configured and ready
```

**Backward Compatibility:** No changes to existing behavior. All GPFS functionality preserved.

### Layer 3: Hitachi SDS Path
**File:** `playbooks/install-hitachi.yml` (240 lines)

Deploys OCP cluster with Hitachi VSP One SDS storage (replaces Terraform approach):

```
Phase 1: Common OCP Installation
  ├─ Include: _ocp-install-common.yml
  └─ Result: Ready OCP cluster with kubeconfig

Phase 2: AWS Infrastructure (Hitachi-Specific)
  ├─ Retrieve worker security group
  ├─ Add Hitachi ports: 443, 3260, 5696, 5697, etc.
  └─ Result: Hitachi-ready network configuration

Phase 3: Hitachi Operator Installation
  ├─ Wait for OCP API readiness
  ├─ Create hitachi-sds namespace
  ├─ Add Hitachi Helm repository
  ├─ Deploy Hitachi operator via Helm
  ├─ Wait for operator readiness
  └─ Result: Hitachi operator deployed and ready

Phase 4: Hitachi Configuration
  ├─ Create storage pool CRD
  ├─ Deploy StorageClass (high protection variant)
  ├─ Deploy VolumeReplicationClass (async)
  ├─ Configure RBAC
  └─ Result: Hitachi storage configured and ready

Phase 5: Completion Summary
  └─ Display next steps and documentation
```

**Key Improvement:** Replaces Terraform-based approach with Ansible-orchestrated Helm deployment.

## Deployment Commands

### GPFS Deployment (Existing)
```bash
make install
```

**Flow:**
1. Executes `playbooks/install.yml`
2. Includes `_ocp-install-common.yml` for OCP provisioning
3. Deploys GPFS with EBS volumes
4. Result: OCP cluster with GPFS storage (~1.5-2 hours)

### Hitachi SDS Deployment (New)
```bash
make install-hitachi
```

**Flow:**
1. Executes `playbooks/install-hitachi.yml`
2. Includes `_ocp-install-common.yml` for OCP provisioning
3. Deploys Hitachi SDS via Helm
4. Result: OCP cluster with Hitachi SDS (~2-2.5 hours)

## Key Benefits

### 1. DRY Principle (Don't Repeat Yourself)
- OCP provisioning logic exists in one place only
- Future OCP changes automatically apply to both paths
- No risk of divergent OCP setups

### 2. Maintainability
- Clear separation of concerns
- Phase markers show execution flow
- Easier to debug and troubleshoot

### 3. Extensibility
- Easy to add new storage backends
- Just create `install-<storage>.yml`
- Include `_ocp-install-common.yml` and add storage tasks

### 4. Reliability
- Bug fixes to OCP path benefit both GPFS and Hitachi
- Single source of truth for cluster provisioning
- Consistent behavior across deployment paths

### 5. Backward Compatibility
- Existing `make install` works unchanged
- All GPFS functionality preserved
- No breaking changes for existing users

## Adding New Storage Backends

To add a new storage backend (e.g., Ceph):

1. Create `playbooks/install-ceph.yml`:
```yaml
---
- name: Playbook to set up OCP Cluster with Ceph
  hosts: localhost
  gather_facts: false
  become: false
  vars_files:
    - ../overrides.yml
    - ../ceph.overrides.yml
  tasks:
    # Phase 1: Include common OCP setup
    - name: Include common OCP installation tasks
      ansible.builtin.include_tasks: _ocp-install-common.yml
    
    # Phase 2: Configure AWS for Ceph
    - name: Configure security groups for Ceph
      # ... Ceph-specific security group rules ...
    
    # Phase 3+: Deploy Ceph
    # ... Ceph-specific deployment tasks ...
```

2. Add Makefile target:
```makefile
.PHONY: install-ceph
install-ceph: ## Install OCP cluster with Ceph storage
ansible-playbook -i hosts $(EXTRA_ARGS) playbooks/install-ceph.yml
```

3. Deploy:
```bash
make install-ceph
```

## Configuration Management

### Common Configuration (overrides.yml)
- AWS region and credentials
- OCP cluster name and domain
- Worker count and instance types
- Base folder and binary paths

### GPFS Configuration (hitachi.overrides.yml or gpfs-specific)
- EBS volume sizes and types
- GPFS filesystem configuration
- Operator versions

### Hitachi Configuration (hitachi.overrides.yml)
- Hitachi array ID and name
- SDS version
- Helm repository
- Storage pool configuration

## Validation

### Syntax Check
```bash
ansible-playbook playbooks/install.yml --syntax-check
ansible-playbook playbooks/install-hitachi.yml --syntax-check
```

### Tag-Based Execution
```bash
# Run only OCP phase
ansible-playbook playbooks/install.yml --tags "1_ocp_install"

# Run only AWS infrastructure phase
ansible-playbook playbooks/install-hitachi.yml --tags "2_aws"
```

## Troubleshooting

### If OCP installation fails
Check `_ocp-install-common.yml` for error. The issue affects both GPFS and Hitachi paths.

### If GPFS setup fails
Check `install.yml` Phase 2-5 for GPFS-specific configuration issues.

### If Hitachi setup fails
Check `install-hitachi.yml` Phase 2-4 for Hitachi-specific configuration issues.

## Code Metrics

### Before Refactoring
- `install.yml`: 352 lines
- `install-hitachi.yml`: 154 lines
- **Total**: 506 lines with ~120 lines of duplicated OCP logic

### After Refactoring
- `_ocp-install-common.yml`: 156 lines (reusable)
- `install.yml`: 180 lines (OCP + GPFS)
- `install-hitachi.yml`: 240 lines (OCP + Hitachi)
- **Total**: 576 lines with **zero duplication**

## Future Enhancements

1. **Terraform Elimination**: Complete removal of Terraform from Hitachi path (already done with Helm)
2. **Storage Backend Abstraction**: Create more generic storage provisioning layer
3. **Multi-Region Support**: Enhance `_ocp-install-common.yml` for multi-region deployments
4. **Disaster Recovery**: Add backup and recovery playbooks
5. **Monitoring Integration**: Integrate with monitoring backends (Prometheus, etc.)

## References

- Playbook Execution: `playbooks/install.yml`, `playbooks/install-hitachi.yml`
- Common Tasks: `playbooks/_ocp-install-common.yml`
- Configuration: `overrides.yml`, `hitachi.overrides.yml`
- Makefile: `Makefile` (install target)
