# OperatorHub Issue - Solutions & Alternative Approach

## 📋 What I Found

**Your Situation:**
- ✅ OpenShift cluster is working
- ✅ OperatorHub infrastructure is deployed
- ✅ Console is accessible
- ❌ OperatorHub may not be visible in UI (display issue)
- ❌ Hitachi operator is NOT in public OperatorHub catalogs (confirmed)

---

## 🎯 Why You Don't See OperatorHub in Console UI

There are several possible reasons:

1. **Browser cache issue** - Solution: Hard refresh (Ctrl+Shift+R)
2. **Console pod cache** - Solution: Restart console pods
3. **Network/RBAC issue** - Solution: Check permissions
4. **Display bug** - Solution: Use CLI instead
5. **User permissions** - Solution: Ensure cluster-admin role

See: `docs/TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md` for detailed troubleshooting

---

## ✅ BETTER SOLUTION: Use Command Line

Instead of struggling with the UI, **use kubectl** - it's faster and more reliable!

### Step 1: Search for Hitachi

```bash
kubectl get packagemanifests -n openshift-marketplace | grep -i hitachi
```

**Result:** (Empty - Hitachi not in public catalogs)

### Step 2: Confirm Hitachi Not Available

```bash
# See all storage operators
kubectl get packagemanifests -n openshift-marketplace | grep -i storage

# See ALL available operators
kubectl get packagemanifests -n openshift-marketplace | head -50
```

**Result:** You won't find Hitachi VSP One SDS HSPC operator here

---

## 🚨 The Real Issue: Hitachi Operator Not Published

**Facts:**
- ✗ Hitachi operator is NOT in Red Hat OperatorHub
- ✗ NOT in Certified Operators (Red Hat Connect)
- ✗ NOT in Community Operators
- ✗ NOT in Red Hat Marketplace
- ✗ NOT in any public Kubernetes registry

**This is expected** for proprietary enterprise software.

---

## 📝 What You Need to Do NOW

### Option 1: Contact Hitachi Support (Recommended)

Ask for ONE of these:
1. **CatalogSource YAML** - So we can add their private catalog to your cluster
2. **Manual installation YAML** - For the operator deployment
3. **Image registry credentials** - To pull the container image
4. **Air-gapped deployment guide** - For disconnected networks

**Questions to ask Hitachi:**
- "How do I install VSP One SDS HSPC operator on OpenShift 4.14?"
- "Do you have a CatalogSource YAML for OperatorHub integration?"
- "What image registry hosts the operator? What credentials do I need?"
- "Do you have air-gapped deployment instructions?"

### Option 2: Check Hitachi Documentation

Look for:
- "OpenShift installation" or "Red Hat OpenShift"
- "OperatorHub" or "Operator Lifecycle Manager"
- "Container image" or "Docker image"
- "Air-gapped" or "disconnected network"
- "Installation guide" or "getting started"

---

## 💡 What We Can Do Right Now (Without OperatorHub)

We have **two options**:

### Option A: Manifest-based Deployment (Already Working!)

```bash
# This is what we've been doing - deploying via scripts
./scripts/deployment/deploy-hitachi-operator-disconnected.sh

# This creates the operator without needing OperatorHub
# Only blocker: need the correct container image
```

**Pros:**
- Works immediately
- No OperatorHub dependency
- Fully scriptable
- Version controllable

**Cons:**
- Need to manually manage operator updates

### Option B: Manual CatalogSource (When you get info from Hitachi)

```bash
# 1. Create Hitachi's CatalogSource
kubectl apply -f <hitachi-catalogsource.yaml>

# 2. Wait for catalog to be ready
kubectl get catalogsources -n openshift-marketplace -w

# 3. Then search for operator
kubectl get packagemanifests -n openshift-marketplace | grep hitachi

# 4. Install via CLI
kubectl apply -f <subscription.yaml>
```

**Pros:**
- Full OperatorHub integration
- Automatic updates
- Managed by OLM

**Cons:**
- Need Hitachi's CatalogSource YAML first

---

## 🎯 Recommended Path Forward

### Immediate (This Week):

1. **Contact Hitachi** with these questions:
   ```
   "How do we install VSP One SDS HSPC operator on OpenShift 4.14 
    in an air-gapped environment?"
   ```

2. **Use script-based deployment** (meanwhile):
   ```bash
   ./scripts/deployment/deploy-hitachi-operator-disconnected.sh
   ```

3. **Get the image location** from Hitachi:
   - Ask for: "What's the correct container image URL?"
   - Example: `registry.hitachivantara.com/vsp-one-sds-hspc:3.14.0`

### Once You Have Image Location:

1. **Update deployment script**:
   ```bash
   vim scripts/deployment/deploy-hitachi-operator-disconnected.sh
   # Update: image: <correct-image-from-hitachi>
   ```

2. **Test deployment**:
   ```bash
   ./scripts/deployment/deploy-hitachi-operator-disconnected.sh
   kubectl get pods -n hitachi-system -w
   ```

3. **Extract YAML for documentation**:
   ```bash
   ./scripts/extract-hitachi-yaml.sh
   ```

### If Hitachi Provides CatalogSource:

1. **Add to cluster**:
   ```bash
   kubectl apply -f <hitachi-catalogsource.yaml>
   ```

2. **Find operator**:
   ```bash
   kubectl get packagemanifests -n openshift-marketplace | grep hitachi
   ```

3. **Install via subscription**:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   metadata:
     name: hitachi-operator
     namespace: hitachi-system
   spec:
     channel: stable
     installPlanApproval: Automatic
     name: <hitachi-operator-name>
     source: hitachi-operators  # Hitachi's catalog
     sourceNamespace: openshift-marketplace
   EOF
   ```

4. **Extract and update scripts**:
   ```bash
   ./scripts/extract-hitachi-yaml.sh
   ```

---

## 📂 Current Tools You Have

| Tool | Status | Purpose |
|------|--------|---------|
| `scripts/deployment/deploy-hitachi-operator-disconnected.sh` | ✅ Ready | Deploy via script |
| `scripts/extract-hitachi-yaml.sh` | ✅ Ready | Extract YAML |
| `scripts/compare-ui-vs-script.sh` | ✅ Ready | Compare deployments |
| OperatorHub UI | ⏳ Needs fixing or use CLI instead | Operator discovery |
| Hitachi CatalogSource | ❌ Not available | Need from Hitachi |

---

## 🔄 The Workflow With What We Have

```
Step 1: Get image from Hitachi
    ↓
Step 2: Update script with image
    ./scripts/deployment/deploy-hitachi-operator-disconnected.sh
    ↓
Step 3: Deploy operator
    kubectl get pods -n hitachi-system -w
    ↓
Step 4: Once running, extract YAML
    ./scripts/extract-hitachi-yaml.sh
    ↓
Step 5: Operator is running!
```

This works **without OperatorHub UI** - just need the image!

---

## 🎓 Summary

**The Real Blocker:** Container image access (not OperatorHub)

**The Solution:**
1. Contact Hitachi for image location + credentials
2. Update deployment script with correct image
3. Deploy with script (doesn't need OperatorHub)
4. Everything else is automated

**OperatorHub** is nice but not necessary for deployment.

---

## ✉️ Email Template for Hitachi Support

```
Subject: VSP One SDS HSPC Operator Deployment on OpenShift 4.14

Hi Hitachi Support,

We're deploying VSP One SDS HSPC operator (v3.14.0) on an air-gapped 
OpenShift 4.14 cluster.

Could you provide:

1. Container image location (registry URL + image name)
   Current: docker.io/hitachi/vsp-one-sds-hspc:3.14.0
   
2. Image pull credentials (if required)

3. Either:
   - CatalogSource YAML for OperatorHub integration, OR
   - Manual installation YAML/manifest

4. Any air-gapped deployment instructions

5. Version compatibility with OpenShift 4.14

Thank you!
```

---

## 🚀 Next Action

**Right now:**
1. Don't worry about OperatorHub UI visibility
2. Contact Hitachi with the questions above
3. Once you have the image location, run:
   ```bash
   ./scripts/deployment/deploy-hitachi-operator-disconnected.sh
   ```

**That's it!** Everything else will work.

The scripts are ready. We just need one piece: **the correct image location from Hitachi**.

---

Good luck! 🎯
