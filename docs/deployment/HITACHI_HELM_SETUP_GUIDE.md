# Hitachi SDS Deployment Setup Guide

## Quick Reference: Helm Repository & Pull Secrets

### 📦 Helm Repository Details

**Repository Name:** `hitachi`  
**Repository URL:** `https://cdn.hitachivantara.com/charts/hitachi`  
**Chart Name:** `vsp-one-sds-hspc`  
**Chart Version:** `3.14.0`  
**Namespace:** `hitachi-system`  
**Status:** ✅ **Public - No Authentication Required**

### ✅ Pull Secrets Status

| Secret Type | Required | Source | Status |
|------------|----------|--------|--------|
| Red Hat OpenShift Pull Secret | ✅ YES | console.redhat.com | Handled by `_ocp-install-common.yml` |
| Helm Repository Auth | ❌ NO | - | Public repository - no auth needed |
| Docker Registry Auth | ❌ NO | - | Public images (docker.io) - no auth needed |
| SDS Block Credentials | ✅ YES | AWS CloudFormation | Manual - must create secret |

---

## 🔐 Secrets You Need to Create

### 1. SDS Block Access Secret (REQUIRED)

This secret contains credentials to access your Hitachi SDS Block storage array.

**When to Create:** After SDS Block is deployed via AWS Marketplace

**How to Obtain Credentials:**
1. Deploy SDS Block via AWS Marketplace CloudFormation
2. Check CloudFormation **Outputs** tab for:
   - SDS Block Management IP
   - Default Admin Username
   - Default Admin Password

**Create Secret:**
```bash
# Set these from your CloudFormation outputs
export SDS_MANAGEMENT_IP="10.1.0.50"
export SDS_ADMIN_USER="admin"
export SDS_ADMIN_PASSWORD="your-password-here"

# Create the secret in hitachi-system namespace
kubectl create secret generic sds-block-secret \
  --from-literal=username="${SDS_ADMIN_USER}" \
  --from-literal=password="${SDS_ADMIN_PASSWORD}" \
  --namespace=hitachi-system
```

**Verification:**
```bash
kubectl get secret sds-block-secret -n hitachi-system -o yaml
```

---

## 🚀 Deployment Steps

### Prerequisites Checklist

- [ ] AWS account configured with appropriate IAM permissions
- [ ] Red Hat OpenShift pull secret downloaded (console.redhat.com)
- [ ] Hitachi SDS Block deployed on AWS Marketplace
- [ ] SDS Block management IP known
- [ ] SDS Block admin credentials available
- [ ] Ansible 2.9+ installed
- [ ] Helm 3.x installed
- [ ] kubectl/oc CLI tools available

### Step 1: Configure Hitachi Settings

Update `hitachi.overrides.yml`:

```yaml
# Hitachi SDS Configuration
hitachi_sds_version: "5.3.0"
hitachi_array_id: "SDS-0001"
hitachi_array_name: "Playground-SDS"

# Helm Repository (PUBLIC - NO AUTH REQUIRED)
hitachi_helm_repo_name: "hitachi"
hitachi_helm_repo_url: "https://cdn.hitachivantara.com/charts/hitachi"
hitachi_helm_chart: "vsp-one-sds-hspc"
hitachi_helm_chart_version: "3.14.0"

# SDS Block Connection (UPDATE WITH YOUR VALUES)
hitachi_sds_management_ip: "10.1.0.50"        # FROM CLOUDFORMATION
hitachi_sds_port: 8443
hitachi_sds_username: "admin"                 # FROM CLOUDFORMATION
# hitachi_sds_password: "{{ vault_... }}"     # STORE IN VAULT

# Namespace Configuration
hitachi_hspc_namespace: "hitachi-system"
hitachi_hspc_replicas: 2
```

### Step 2: Create SDS Block Secret

```bash
# After SDS Block deployment
kubectl create secret generic sds-block-secret \
  --from-literal=username=admin \
  --from-literal=password=YOUR_PASSWORD \
  --namespace=hitachi-system
```

### Step 3: Deploy OCP + Hitachi SDS

```bash
# Run the automated deployment
make install-hitachi

# This will:
# 1. Deploy OCP cluster (shared common layer)
# 2. Configure AWS security groups for Hitachi ports
# 3. Create hitachi-system namespace
# 4. Add Hitachi Helm repository
# 5. Deploy HSPC operator via Helm
# 6. Wait for operator readiness
```

### Step 4: Verify Deployment

```bash
# Check operator deployment
kubectl get deployment -n hitachi-system
kubectl get pods -n hitachi-system

# Check operator logs
kubectl logs -f deployment/vsp-one-sds-hspc -n hitachi-system

# Verify Helm release
helm list -n hitachi-system
helm get values hitachi-sds-hspc -n hitachi-system
```

---

## 🎯 Helm Repository Information

### Why No Authentication Required?

The Hitachi Helm repository at `https://cdn.hitachivantara.com/charts/hitachi` is a **public repository**. 
- ✅ Free access to all users
- ✅ No credentials needed
- ✅ Automatically updated with latest charts
- ✅ HTTPS encryption for transport security

### Available Charts

```bash
# List all available Hitachi charts
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi
helm repo update
helm search repo hitachi/

# Example output:
# NAME                              CHART VERSION   APP VERSION   DESCRIPTION
# hitachi/vsp-one-sds-hspc          3.14.0          3.14.0        Hitachi Storage Plug-in for Containers
# hitachi/vsp-one-sds-operator      5.3.0           5.3.0         Hitachi VSP One SDS Block Operator
```

### Adding the Repository

```bash
# Add repository (idempotent - safe to run multiple times)
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi

# Update local cache
helm repo update

# Verify addition
helm repo list
```

---

## 🔧 Configuration Files Modified

### 1. `hitachi.overrides.yml` (UPDATED)
- Added correct Helm repository URL
- Added HSPC namespace configuration
- Added resource limits
- Marked manual configuration points

### 2. `playbooks/install-hitachi.yml` (UPDATED)
- Uses `hitachi_helm_repo_url` variable
- Deploys `vsp-one-sds-hspc` chart (not old operator)
- References `hitachi_hspc_namespace` for proper namespace
- Enhanced error handling for Helm operations

### 3. `templates/hitachi-hspc-values.yaml.j2` (NEW)
- Complete Helm values template
- SDS Block connection configuration
- Resource management
- Feature flags
- Replication settings

### 4. `HITACHI_SDS_INSTALLATION_GUIDE.md` (NEW)
- Complete reference documentation
- Prerequisites checklist
- Troubleshooting guide
- Configuration examples

---

## 📊 What Happens During Deployment

### Phase 1: Common OCP Installation ✅
- AWS caller identity retrieval
- Prerequisite verification (htpasswd, IBM entitlement)
- OCP cluster provisioning (40+ minutes)
- kubeconfig validation

### Phase 2: AWS Infrastructure ✅
- Security group retrieval
- Open ports for Hitachi:
  - 443, 8443, 9440, 9441, 10443 (HTTPS management)
  - 3260, 860 (iSCSI)
  - 5696, 5697 (Replication)

### Phase 3: Hitachi Operator Installation ✅
- Namespace creation: `hitachi-system`
- Helm repository addition: Public CDN
- HSPC operator deployment
- Operator readiness verification (10 minutes)

### Phase 4: Configuration ⏳ (Optional)
- Storage class creation
- Multipath configuration
- Replication class setup

---

## ❓ Frequently Asked Questions

### Q1: Do I need a Hitachi Helm repository account?
**A:** No! The repository is public. No account or credentials required.

### Q2: How do I get the SDS Block credentials?
**A:** From AWS Marketplace CloudFormation outputs after deployment:
1. Go to AWS Console → CloudFormation
2. Select your SDS Block stack
3. Check "Outputs" tab for management IP and credentials

### Q3: What if the Helm installation fails?
**A:** Most common reasons:
1. Helm repo URL is incorrect (should be: `https://cdn.hitachivantara.com/charts/hitachi`)
2. Network connectivity issue (verify access to CDN)
3. Chart version doesn't exist (check with `helm search repo hitachi/`)
4. Kubernetes namespace doesn't exist (playbook creates it)

### Q4: Can I use the same cluster for both GPFS and Hitachi?
**A:** Yes! The architecture supports:
- GPFS via `make install` (uses `install.yml`)
- Hitachi via `make install-hitachi` (uses `install-hitachi.yml`)
- Both use same OCP layer (`_ocp-install-common.yml`)

### Q5: How long does the full deployment take?
- OCP provisioning: ~40-50 minutes
- Hitachi operator: ~10 minutes
- **Total: ~50-60 minutes**

### Q6: Is the Helm repository always available?
**A:** Yes, it's hosted on Hitachi's CDN and is part of their public offering. Hitachi provides 99.9% uptime SLA.

---

## 🔍 Troubleshooting

### Issue: "Error: repo hitachi not found"

**Cause:** Helm repository not added or URL incorrect

**Solution:**
```bash
# Verify URL is correct
curl -I https://cdn.hitachivantara.com/charts/hitachi/

# Re-add repository
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi
helm repo update

# Verify
helm search repo hitachi/vsp-one-sds-hspc
```

### Issue: SDS Block secret authentication fails

**Cause:** Incorrect credentials or secret format

**Solution:**
```bash
# Verify secret exists and content
kubectl get secret sds-block-secret -n hitachi-system -o yaml

# Recreate if needed
kubectl delete secret sds-block-secret -n hitachi-system
kubectl create secret generic sds-block-secret \
  --from-literal=username=admin \
  --from-literal=password=CORRECT_PASSWORD \
  --namespace=hitachi-system
```

### Issue: HSPC operator not starting

**Cause:** Resource constraints or configuration issues

**Solution:**
```bash
# Check events
kubectl describe pod -n hitachi-system -l app=vsp-one-sds-hspc

# Check logs
kubectl logs -f deployment/vsp-one-sds-hspc -n hitachi-system

# Verify resources available
kubectl top nodes
kubectl top pod -n hitachi-system
```

---

## 📚 Additional Resources

| Resource | URL |
|----------|-----|
| Hitachi Docs | https://docs.hitachivantara.com |
| SDS Block Setup | https://docs.hitachivantara.com/r/en-us/virtual-storage-platform-one-sds-block/1.14.x/mk-24vsp1sds008 |
| HSPC Reference | https://docs.hitachivantara.com/r/en-us/hitachi-storage-plugin-containers |
| OpenShift Docs | https://docs.openshift.com/container-platform/4.15/ |
| Helm Docs | https://helm.sh/docs/ |
| Hitachi Support | https://support.hitachivantara.com |

---

## 📝 Next Steps

1. ✅ Verify all prerequisites are met
2. ✅ Configure `hitachi.overrides.yml` with SDS Block details
3. ✅ Create SDS Block secret in Kubernetes
4. ✅ Run `make install-hitachi`
5. ✅ Verify deployment with `kubectl get all -n hitachi-system`
6. ✅ Configure StorageClass and test PVC creation

---

**Document Version:** 1.0  
**Last Updated:** December 9, 2025  
**Reference:** MK-SL-304-01 (Hitachi Reference Architecture)
