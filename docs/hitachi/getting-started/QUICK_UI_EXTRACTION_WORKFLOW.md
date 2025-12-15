# Quick Guide: UI Install → Extract → Update Scripts

## 🎯 The Complete Workflow

### Phase 1: Find & Install (UI)
```bash
# 1. Get console URL
kubectl cluster-info | grep console

# 2. Log in → Operators → OperatorHub
# 3. Search for "Hitachi" or "VSP One SDS"
# 4. Click Install → Select hitachi-system namespace → Approve

# 5. Wait for installation
kubectl get pods -n hitachi-system -w
```

### Phase 2: Extract YAML (Script)
```bash
# Once operator is running:
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

./scripts/extract-hitachi-yaml.sh

# This creates: manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml
```

### Phase 3: Review Extracted Configuration
```bash
# See complete operator configuration
cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml

# Extract just the image
grep "image:" manifests/hitachi-extracted/deployments/*-LATEST.yaml

# Extract environment variables
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml | grep -A 20 "env:"

# Extract resource limits
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml | grep -A 10 "resources:"
```

### Phase 4: Update Your Deployment Scripts
```bash
# Copy extracted manifest to templates
cp manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml \
   templates/hitachi-operator-ui-deployed.yaml

# Edit your deployment script to use exact image:
vim scripts/deployment/deploy-hitachi-operator-disconnected.sh

# Update this line with actual image from extraction:
image: <INSERT-IMAGE-FROM-EXTRACTION>

# Update environment variables if needed
# Update resource requests/limits if needed
```

### Phase 5: Test Updated Script
```bash
# Delete current deployment
kubectl delete deployment vsp-one-sds-hspc -n hitachi-system

# Test updated script
./scripts/deployment/deploy-hitachi-operator-disconnected.sh

# Verify it matches UI deployment
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml
```

### Phase 6: Version Control
```bash
git add manifests/hitachi-extracted/
git add docs/
git add scripts/extract-hitachi-yaml.sh
git commit -m "Add Hitachi UI extraction and deployment via script"
git push
```

---

## 🔍 Key Commands During Each Phase

### Installation Check
```bash
# Check if operator is in OperatorHub
kubectl get packagemanifests -n openshift-marketplace | grep -i hitachi

# If not found, Hitachi may not be available in public catalogs
# → Contact Hitachi support for CatalogSource YAML
```

### Image Identification
```bash
# Get exact image after UI install
kubectl get deployment vsp-one-sds-hspc -n hitachi-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Example output:
# registry.hitachivantara.com/vsp-one-sds-hspc:3.14.0
# quay.io/hitachi/vsp-one-sds-hspc:3.14.0
# docker.io/hitachivantara/vsp-one-sds-hspc:3.14.0
```

### Full Configuration Dump
```bash
# Get everything needed for scripted deployment
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml > /tmp/deployment.yaml
cat /tmp/deployment.yaml

# Get just containers section
kubectl get deployment vsp-one-sds-hspc -n hitachi-system -o yaml | sed -n '/containers:/,/^\s*-\s\|^[a-z]/p'
```

### Subscription Details (if installed via OLM)
```bash
# Check if operator was installed via Subscription
kubectl get subscription -n hitachi-system

# View subscription details
kubectl describe subscription -n hitachi-system

# Check CSV (ClusterServiceVersion)
kubectl get csv -n hitachi-system
```

---

## 📋 Checklist

- [ ] Access OpenShift Console
- [ ] Search for Hitachi in OperatorHub
- [ ] Install operator to `hitachi-system` namespace
- [ ] Wait for operator pod to be Ready
- [ ] Run: `./scripts/extract-hitachi-yaml.sh`
- [ ] Review: `cat manifests/hitachi-extracted/hitachi-operator-consolidated-LATEST.yaml`
- [ ] Identify image: `grep "image:" manifests/hitachi-extracted/deployments/*-LATEST.yaml`
- [ ] Update `scripts/deployment/deploy-hitachi-operator-disconnected.sh` with exact image
- [ ] Test updated script against cluster
- [ ] Verify deployment matches UI installation
- [ ] Commit changes: `git add . && git commit -m "..."`

---

## 🚨 Troubleshooting

### Hitachi Not Found in OperatorHub

**Status:** Hitachi operator is NOT in public Red Hat catalogs (as of this test)

**Solutions:**
1. **Check with Hitachi:**
   - Ask if operator is published on Red Hat Connect
   - Request CatalogSource YAML for air-gapped environments
   - Request manual deployment manifests

2. **Check Alternative Sources:**
   - Certified Operators (more likely)
   - Community Operators (less likely)
   - Red Hat Marketplace (enterprise apps)

3. **Fallback to Manual:**
   ```bash
   # Use script-based deployment (which we already have)
   ./scripts/deployment/deploy-hitachi-operator-disconnected.sh
   
   # Then extract from running deployment
   ./scripts/extract-hitachi-yaml.sh
   ```

### Image Pull Error After UI Install

```bash
# Check the error
kubectl get events -n hitachi-system
kubectl describe pod -n hitachi-system

# If access denied:
# → Image requires credentials
# → Create secret and patch service account

kubectl create secret docker-registry hitachi-registry-secret \
  --docker-server=registry.hitachivantara.com \
  --docker-username=<username> \
  --docker-password=<password> \
  -n hitachi-system

kubectl patch serviceaccount vsp-one-sds-hspc \
  -p '{"imagePullSecrets": [{"name": "hitachi-registry-secret"}]}' \
  -n hitachi-system

# Restart pod
kubectl delete pod -n hitachi-system -l app=vsp-one-sds-hspc
```

### Extraction Script Issues

```bash
# Check if script is executable
ls -la scripts/extract-hitachi-yaml.sh

# Make executable if needed
chmod +x scripts/extract-hitachi-yaml.sh

# Run with verbose output
bash -x scripts/extract-hitachi-yaml.sh 2>&1 | tee extraction.log

# Check extracted files
ls -la manifests/hitachi-extracted/
```

---

## 📂 Files You'll Use

| File | Purpose | Source |
|------|---------|--------|
| `scripts/extract-hitachi-yaml.sh` | Extraction tool | Created ✓ |
| `docs/INSTALL_VIA_UI_AND_EXTRACT_YAML.md` | Complete guide | Created ✓ |
| `manifests/hitachi-extracted/` | Extracted YAML files | Will be created by script |
| `templates/hitachi-operator-ui-deployed.yaml` | For version control | You'll copy extracted here |
| `scripts/deployment/deploy-hitachi-operator-disconnected.sh` | Updated script | You'll update this |

---

## 🎓 What You'll Learn

After completing this workflow, you'll have:

1. ✅ Exact Hitachi operator image location
2. ✅ Exact configuration (resources, environment, ports)
3. ✅ Version-controlled deployment manifests
4. ✅ Repeatable scripted deployment process
5. ✅ Documentation for your team

---

## 🚀 Next Step

```bash
# 1. Get console URL
kubectl cluster-info | grep console

# 2. Open in browser and try to find Hitachi operator in OperatorHub
# 3. If found, install it
# 4. If not found, we'll contact Hitachi support for CatalogSource

# 5. Once installed, run:
./scripts/extract-hitachi-yaml.sh
```

Good luck! 🎯
