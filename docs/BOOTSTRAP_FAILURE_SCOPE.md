# Bootstrap Failure & Stale Resources: Scope Analysis

## Key Question
**Is the failed bootstrap relevant ONLY to Hitachi Block infrastructure OR to ANY errors during `make install`?**

## Answer: **ANY failure during OCP bootstrap creates stale resources**

The circular dependency issue is **NOT specific to Hitachi SDS Block** - it affects **any failure during cluster deployment**.

---

## Deployment Stages & Failure Points

### Stage 1: OCP Cluster Creation (Shared - Affects All)
```
make install-hitachi / make install / make install-iscsi / etc
  ↓
playbooks/_ocp-install-common.yml (SHARED BY ALL)
  ↓
openshift-install create cluster
  ↓
AWS Cluster API creates infrastructure:
  • VPC
  • Security groups with cross-references ← CREATED HERE
  • Subnets
  • EC2 instances (bootstrap, master, worker nodes)
  • Load balancers
  • ENI attachments
```

**Failure can occur at ANY point during this 40-45 minute bootstrap process**

### Stage 2: OCP Operator Installation (Specific Operators)
```
IF Hitachi Block deployment enabled:
  → playbooks/install-hitachi.yml
    → sds-block-deploy.yml
    → Hitachi-specific operators
    → Can fail here ← Creates Hitachi-specific orphans

IF GPFS setup enabled:
  → playbooks/install.yml
    → gpfs-setup.yml
    → GPFS operators
    → Can fail here ← Creates GPFS-specific orphans

IF iSCSI setup enabled:
  → playbooks/iscsi.yml
    → iSCSI configuration
    → Can fail here
```

---

## Where Circular Dependencies Come From

### Root Cause: OpenShift Cluster API
When `openshift-install create cluster` runs, it:
1. Creates security groups for:
   - **worker** nodes
   - **master** (control plane) nodes
   - **API server** load balancer
2. Adds rules to these SGs that **cross-reference each other**:
   ```
   Worker SG: Allow traffic from Master SG
   Master SG: Allow traffic from Worker SG
   API LB SG: Allow traffic from both Worker & Master SGs
   ```

This is **normal OCP design** - it's not Hitachi-specific!

### When It Becomes a Problem

If bootstrap **fails partway through** (at any stage):
- Security groups are created ✓
- VPC is created ✓
- EC2 instances may or may not be created (depends on failure point)
- Load balancers may be partially created
- **But these resources are ORPHANED** (no living cluster)

**If you try to re-run deployment:**
- New VPC is created
- New security groups are created
- Eventually hit VPC limit (5/5)
- **Deployment blocked**

---

## Failure Scenarios

### Scenario 1: OCP Bootstrap Fails (Stage 1)
```bash
make install-hitachi
  ↓
openshift-install create cluster
  ↓
[40 minutes in] Fails due to:
  • AWS API rate limiting
  • Network timeout
  • Bad install-config.yaml
  • AWS permission issue
  • Cluster resource quota exhausted
  ↓
RESULT: Orphaned VPC with security groups ← Circular dependencies
```
**Relevant to:** ✅ ALL deployment methods
- `make install`
- `make install-hitachi`
- `make install-hitachi-with-sds`
- `make install-ceph`
- `make install-iscsi`

### Scenario 2: OCP Bootstrap Succeeds, Operator Setup Fails (Stage 2)
```bash
make install-hitachi
  ↓
openshift-install create cluster → SUCCESS ✓
  ↓
[Phase 2] Deploy Hitachi SDS Block
  ↓
Fails due to:
  • Helm chart fetch failure
  • Operator CRD conflict
  • Image pull failure
  • RBAC issues
  ↓
RESULT: Cluster exists but deployment incomplete
         Hitachi resources partially created/orphaned
```
**Relevant to:** ✅ Hitachi/GPFS/iSCSI specific installations
- May not create circular SG dependencies (cluster is running)
- But does create orphaned Kubernetes resources
- Can make cluster unusable

### Scenario 3: User Interrupts Installation (Ctrl+C)
```bash
make install-hitachi
  ↓
openshift-install create cluster
  ↓
[30 minutes in] User hits Ctrl+C
  ↓
RESULT: Partial infrastructure left in AWS
         VPC, SGs, ENIs, partial EC2 instances
         ← Circular dependencies possible
```
**Relevant to:** ✅ ALL deployments
- User accidentally cancelled
- CI/CD pipeline timeout/cancellation
- Network connection lost

---

## Impact Matrix

| Failure Point | VPC Created | SGs Created | Circular Deps | Blocks Next Deploy |
|---|---|---|---|---|
| **Config validation** | ❌ No | ❌ No | ❌ No | ✅ No |
| **VPC creation** | ✅ Yes | ❌ No | ❌ No | ✅ No |
| **SG creation** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **Bootstrap nodes** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **Master nodes** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **Worker nodes** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **Bootstrap complete** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **Hitachi Phase 2 fails** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |
| **All phases succeed** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **YES** |

---

## Why This Matters for Your Case

Your specific case (4lwf4, fq84m, fd66l, gsphv clusters):
- All used `make install-hitachi` or `make install` (OCP bootstrap)
- Bootstrap failed at various points
- Each failure left behind an orphaned VPC with circular SG dependencies
- 3 VPCs accumulated (4th failure may have completed or failed differently)

**The solution applies to ALL future deployment failures**, not just Hitachi.

---

## Prevention Strategy Going Forward

After implementing the cleanup solution:

### Before Re-deployment After Any Failure
```bash
# After ANY failed deployment attempt:
make destroy              # Cleanup resources
make cleanup-stale-vpcs   # Clean orphaned infrastructure
make install-hitachi      # Retry deployment
```

### During Deployment Failure
```bash
# If deployment fails:
# 1. Let it finish (or Ctrl+C if needed)
# 2. DON'T immediately retry
# 3. Run cleanup first:
make destroy
make cleanup-stale-vpcs

# THEN retry:
make install-hitachi
```

---

## Updated Documentation Scope

The cleanup solution documentation should clarify:

### Currently in docs/STALE_RESOURCES_AND_CIRCULAR_DEPENDENCIES.md:
```markdown
## Scope
This issue affects ANY OCP deployment failure, not just Hitachi SDS Block.

Causes:
- OpenShift Cluster API creates security groups with cross-references
- These are standard security group architecture (intentional design)
- When deployment fails midway, resources are orphaned
- Circular dependencies prevent cleanup
- Accumulation hits AWS VPC hard limit (5/5)

Relevant to:
- ✅ make install (CEPH/GPFS)
- ✅ make install-hitachi (with or without SDS block)
- ✅ make install-iscsi
- ✅ make install-hitachi-with-sds
- ✅ Any custom OCP deployment

NOT specific to:
- ❌ Hitachi SDS Block (though it was the trigger in this case)
- ❌ Any particular storage backend
- ❌ Any particular OCP version
```

---

## Recommendations

### 1. Update destroy.yml Phase 0A Comment
```yaml
    # Phase 0A: Clean up orphaned security group rules (CRITICAL)
    # ====================================================
    # This phase revokes SG rules to break circular dependencies from
    # FAILED deployments of ANY type.
    #
    # Relevant to:
    #   - Failed OCP bootstrap (any reason)
    #   - Failed Hitachi/GPFS/iSCSI operator setup
    #   - User-interrupted deployments (Ctrl+C)
    #   - Network timeouts during deployment
    #
    # Not specific to any storage backend - applies to all.
```

### 2. Update cleanup documentation headers
```markdown
# Cleanup Stale Infrastructure from Failed Deployments

## Applies to:
Any failure in:
- `make install`
- `make install-hitachi`
- `make install-hitachi-with-sds`
- `make install-ceph`
- `make install-iscsi`
- Any custom deployment script
```

### 3. Add prevention guide
Create `docs/DEPLOYMENT_FAILURE_RECOVERY.md`:
```markdown
## When ANY Deployment Fails

1. Let the deployment complete or exit
2. DO NOT immediately retry
3. Run cleanup:
   ```
   make destroy
   make cleanup-stale-vpcs
   ```
4. Check VPC limit:
   ```
   aws ec2 describe-vpcs --region eu-north-1 --query 'Vpcs[*].[VpcId,IsDefault]'
   ```
5. Should show 2 VPCs (default + active)
6. Retry deployment
```

---

## Summary

| Aspect | Answer |
|--------|--------|
| **Specific to Hitachi?** | ❌ NO - affects ANY OCP deployment |
| **Specific to SDS Block?** | ❌ NO - affects ANY storage or no storage |
| **Specific to bootstrap phase?** | ⚠️ MOSTLY - can happen during operator setup too |
| **Happens on user error (Ctrl+C)?** | ✅ YES - very common scenario |
| **Solution universal?** | ✅ YES - works for all failure types |
| **Prevention applicable?** | ✅ YES - document for all deployments |

**The cleanup solution you've implemented is universally applicable** and should be presented that way in documentation.

