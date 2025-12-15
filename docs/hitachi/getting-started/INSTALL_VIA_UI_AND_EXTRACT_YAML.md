# Installing Hitachi Operator via OpenShift Console UI

This guide explains how to install the Hitachi VSP One SDS HSPC operator via the OpenShift Console UI and extract the YAML configuration to use in your deployment scripts.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Install via OpenShift Console](#install-via-openshift-console)
4. [Extract YAML Configuration](#extract-yaml-configuration)
5. [Update Deployment Scripts](#update-deployment-scripts)
6. [Verify Deployment](#verify-deployment)

---

## Overview

**Why Use the UI?**
- Operator automatically handles image pulls and authentication
- UI installation creates proper OperatorGroup, Subscription, and CSV
- Can extract exact YAML and version control it
- Easier to understand operator requirements
- Automatically configures RBAC

**Workflow:**
1. Access OpenShift Console
2. Navigate to OperatorHub
3. Install Hitachi operator
4. Run extraction script to get YAML
5. Use YAML in your scripted deployments

---

## Prerequisites

- **OpenShift Cluster**: 4.x or later (your cluster: 4.14 ✓)
- **Admin Access**: Cluster admin role required for OperatorHub
- **Hitachi License/Account**: For access to private image registry
- **kubectl Access**: For extraction script

---

## Install via OpenShift Console

### Step 1: Access OpenShift Console

```bash
# Get console URL
kubectl cluster-info | grep console

# Or from your install files:
cat /home/nlevanon/aws-gpfs-playground/ocp_install_files/.openshift_install.log | grep "https://console"
```

Example URL: `https://console-openshift-console.apps.gpfs-levanon.eu-north-1.nips.io`

### Step 2: Navigate to OperatorHub

1. Log in with cluster-admin credentials
2. Left sidebar: **Operators** → **OperatorHub**
3. Search for "Hitachi" or "VSP" or "HSPC"

### Step 3: Look for Operator

You may find the operator in:
- **Certified Operators** (Red Hat Connect certified)
- **Community Operators** (community-supported)
- **Red Hat Operators** (official Red Hat)
- **Red Hat Marketplace** (enterprise apps)

**Likely location:** Certified Operators (if Hitachi is Red Hat certified)

### Step 4: Click Install

When you find the Hitachi VSP One SDS HSPC operator:

1. Click the operator card
2. Click **Install**
3. **Installation Mode:**
   - Select: **A specific namespace on the cluster**
   - Namespace: Type `hitachi-system` (or create new)
4. **Approval Strategy:**
   - Automatic (recommended for lab/dev)
   - Manual (recommended for production)
5. Click **Install**

### Step 5: Monitor Installation

```bash
# Watch installation progress
kubectl get subscription -n hitachi-system -w

# Check ClusterServiceVersion (CSV)
kubectl get csv -n hitachi-system

# Once installed, should see:
kubectl get deployment -n hitachi-system
```

---

## Extract YAML Configuration

Once the operator is installed via the UI, extract all YAML:

### Run Extraction Script

```bash
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

# Run extraction
./scripts/extract-hitachi-yaml.sh

# This creates:
# - manifests/hitachi-extracted/
# - manifests/hitachi-extracted/manifests/namespace-all-LATEST.yaml  (MOST IMPORTANT)
# - manifests/hitachi-extracted/deployments/vsp-one-sds-hspc-LATEST.yaml
# - manifests/hitachi-extracted/subscriptions/hitachi-subscription-LATEST.yaml
# - manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml (CONSOLIDATED)
```

### View Extracted Files

```bash
# See everything in one consolidated file
cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml

# Just the deployment
cat manifests/hitachi-extracted/deployments/*-LATEST.yaml

# Just the image
grep -i "image:" manifests/hitachi-extracted/deployments/*-LATEST.yaml
```

### Key Information to Extract

```bash
# Get the actual image being used
kubectl describe deployment vsp-one-sds-hspc -n hitachi-system | grep "Image:"

# Get the container image from deployment
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.spec.template.spec.containers[0].image}'

# Get environment variables
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.spec.template.spec.containers[0].env}' | jq .

# Get resource requests/limits
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .

# Get port configuration
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o jsonpath='{.spec.template.spec.containers[0].ports}' | jq .
```

---

## Update Deployment Scripts

Once you have the YAML from UI installation, update your scripts:

### Step 1: Extract Key Configuration

```bash
# This shows the exact manifest used by UI
cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml
```

### Step 2: Update `scripts/deployment/deploy-hitachi-operator-disconnected.sh`

```bash
# Open the file
vim scripts/deployment/deploy-hitachi-operator-disconnected.sh

# Update the DEPLOYMENT manifest section with:
# - Exact image name from UI extraction
# - Exact resource requests/limits
# - Exact environment variables
# - Exact port mappings
```

### Step 3: Example Updates

If extraction shows:
```yaml
spec:
  containers:
  - name: vsp-one-sds-hspc
    image: registry.hitachivantara.com/vsp-one-sds-hspc:3.14.0
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
    ports:
    - containerPort: 8080
      name: http
```

Then update the script to use those exact values.

### Step 4: Create Updated Script

```bash
# Copy extracted manifests to use in deployment
cp manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml \
   templates/hitachi-operator-from-ui.yaml

# Now you can use this in scripts:
# kubectl apply -f templates/hitachi-operator-from-ui.yaml -n hitachi-system
```

---

## Verify Deployment

### Check Subscription (if UI-installed)

```bash
# View subscription
kubectl get subscription -n hitachi-system -o yaml

# View ClusterServiceVersion
kubectl get csv -n hitachi-system -o yaml
```

### Check Deployment Details

```bash
# Verify operator is running
kubectl get deployment -n hitachi-system -o wide

# Check pod status
kubectl get pods -n hitachi-system

# View operator logs
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc -f
```

### Compare UI Installation vs Script

```bash
# Export UI-installed deployment
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml > /tmp/ui-deployment.yaml

# Export script-deployed (current)
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml > /tmp/script-deployment.yaml

# Compare differences
diff -u /tmp/ui-deployment.yaml /tmp/script-deployment.yaml
```

---

## Troubleshooting UI Installation

### Issue: Operator Not Found in OperatorHub

**Solution:**
1. Check if your cluster can access Red Hat catalog sources:
   ```bash
   kubectl get catalogsources -n openshift-marketplace
   ```

2. If catalogs are missing, they may be offline:
   ```bash
   kubectl get catalogsources -n openshift-marketplace -o yaml | grep -i status
   ```

3. Contact Hitachi support to request:
   - CatalogSource YAML for air-gapped environments
   - Operator manifest for manual installation
   - Image registry access for disconnected networks

### Issue: Image Pull Error After UI Install

**Solution:**
```bash
# Check events
kubectl get events -n hitachi-system -w

# Check pod logs
kubectl describe pod -n hitachi-system -l app=vsp-one-sds-hspc

# If image needs credentials:
kubectl create secret docker-registry hitachi-pull-secret \
  --docker-server=registry.hitachivantara.com \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  -n hitachi-system

kubectl patch serviceaccount vsp-one-sds-hspc \
  -p '{"imagePullSecrets": [{"name": "hitachi-pull-secret"}]}' \
  -n hitachi-system

kubectl rollout restart deployment vsp-one-sds-hspc -n hitachi-system
```

### Issue: OperatorHub Showing as Unhealthy

**Solution:**
```bash
# Check catalog health
kubectl get pods -n openshift-marketplace -l app.kubernetes.io/name=certified-operators

# Restart if needed
kubectl delete pod -n openshift-marketplace -l app=catalogoperator
```

---

## Best Practices

1. **Always Extract YAML After UI Install**
   - Version control the extracted manifests
   - Recreate deployments from YAML, not UI
   - Enables IaC (Infrastructure as Code)

2. **Use Extraction for Documentation**
   - Extracted YAML documents exact configuration
   - Share with team for consistency
   - Reference for troubleshooting

3. **Combine Both Approaches**
   - UI install for one-time setup
   - Script deployment for reproducibility
   - Extraction for synchronization

4. **Test Extraction Script**
   ```bash
   # Run extraction on known working deployment
   ./scripts/extract-hitachi-yaml.sh
   
   # Verify extracted files
   ls -la manifests/hitachi-extracted/
   ```

---

## Next Steps

1. **Access OpenShift Console:**
   ```bash
   kubectl cluster-info | grep console
   ```

2. **Search for Hitachi in OperatorHub**
   - Certified Operators first
   - Then Community Operators
   - Then Red Hat Marketplace

3. **If Found:**
   - Click Install
   - Select `hitachi-system` namespace
   - Wait for operator pod to start

4. **If Not Found:**
   - Contact Hitachi support for:
     - OperatorHub listing details
     - CatalogSource YAML for your version
     - Air-gapped installation guide
     - Private image registry details

5. **Once Installed:**
   ```bash
   ./scripts/extract-hitachi-yaml.sh
   cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml
   ```

6. **Update Your Scripts:**
   - Copy extracted manifests to templates/
   - Update deploy-hitachi-operator-disconnected.sh with exact image/config
   - Test deployment

---

## Quick Reference

```bash
# Access console
kubectl cluster-info | grep console

# Check OperatorHub availability
kubectl get catalogsources -n openshift-marketplace

# Search for Hitachi operators
kubectl get packagemanifests -n openshift-marketplace | grep -i hitachi

# Extract YAML after UI install
./scripts/extract-hitachi-yaml.sh

# View extracted deployment
cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml

# Get just the image
grep -A 10 "containers:" manifests/hitachi-extracted/deployments/*-LATEST.yaml | grep "image:"

# Monitor installation
kubectl get pods -n hitachi-system -w

# Check subscription status
kubectl get subscription -n hitachi-system

# View operator logs
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc -f
```

---

## Questions?

If you have questions about the UI installation or extraction process:

1. **OperatorHub Issues**: Contact Red Hat support
2. **Image Access Issues**: Contact Hitachi support
3. **Extraction Problems**: Check the extraction script logs in `Logs/` directory

Good luck! 🚀
