# Troubleshooting: OperatorHub Not Visible in OpenShift Console

## Your Situation

- ✅ OpenShift Console is running
- ✅ OperatorHub catalog sources are deployed
- ✅ Marketplace operator is running
- ❌ But you don't see OperatorHub in the console UI

This is a common issue. Here are the solutions:

---

## 📋 Quick Diagnostics

First, let's verify what's happening:

```bash
# Check console URL
kubectl get routes -n openshift-console

# Check if OperatorHub UI is running
kubectl get pods -n openshift-marketplace | grep marketplace

# Check if there are any errors
kubectl get events -n openshift-marketplace | grep -i error

# Check console pod logs
kubectl logs -n openshift-console -l app=console | tail -50
```

---

## 🔧 Solutions (Try in Order)

### Solution 1: Hard Refresh Browser Cache

**Why:** Console UI may be cached in your browser

**Steps:**
1. Open console URL: `https://console-openshift-console.apps.gpfs-levanon.fusionaccess.devcluster.openshift.com`
2. Press: **Ctrl + Shift + R** (Windows/Linux) or **Cmd + Shift + R** (Mac)
3. This hard-refreshes and clears browser cache
4. Log out and log back in
5. Navigate: **Operators** → **OperatorHub**

---

### Solution 2: Clear Console Pod Cache

**Why:** Console pod may have stale cache

**Steps:**
```bash
# Restart console pods to clear cache
kubectl rollout restart deployment/console -n openshift-console

# Wait for pods to restart
kubectl get pods -n openshift-console -w

# Log out of console, close browser tab
# Open console URL again in new tab
```

---

### Solution 3: Check Console Configuration

**Why:** Console may have disabled OperatorHub feature flag

**Steps:**
```bash
# Check console configuration
kubectl get configmap console-config -n openshift-console -o yaml | grep -i operator

# If console-config exists, it may have feature flags
kubectl get configmap console-config -n openshift-console -o yaml
```

If you see `"hideOperatorHub": true` or similar, it's disabled.

---

### Solution 4: Verify Operator Framework is Installed

**Why:** OperatorHub requires operator framework

**Steps:**
```bash
# Check for operator framework
kubectl get pods -n openshift-operator-lifecycle-manager

# Should see olm, olm-operator, catalog-operator pods
# If missing, OLM isn't installed

# Check if OLM is available
kubectl get crd | grep clusterserviceversion
# Should show: clusterserviceversions.operators.coreos.com
```

---

### Solution 5: Check Network/RBAC

**Why:** Some security policies may block OperatorHub UI

**Steps:**
```bash
# Check your user role
kubectl auth can-i get operators.coreos.com --as=<your-username>

# Check if cluster role binding exists for OperatorHub
kubectl get clusterrolebindings | grep -i operator

# Check marketplace operator health
kubectl describe pod -n openshift-marketplace -l app=marketplace-operator
```

---

### Solution 6: Access OperatorHub via kubectl (Alternative)

**If UI doesn't work, use command line:**

```bash
# List available operators
kubectl get packagemanifests -n openshift-marketplace | head -20

# Search for Hitachi
kubectl get packagemanifests -n openshift-marketplace | grep -i hitachi

# Get details of an operator
kubectl get packagemanifest redis -n openshift-marketplace -o yaml

# Create subscription (install) via kubectl
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hitachi-operator
  namespace: hitachi-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: hitachi-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
```

---

## 🎯 Step-by-Step: What You Should See

### In OpenShift Console:

1. **Log in** with cluster-admin credentials
   - URL: `https://console-openshift-console.apps.gpfs-levanon.fusionaccess.devcluster.openshift.com`

2. **Left Sidebar** should have:
   - **Home**
   - **Operators** ← Click here
     - **OperatorHub** ← Should be here
     - **Installed Operators**
     - **Operator Catalogs**
   - **Storage**
   - **Networking**
   - etc.

3. **In OperatorHub** you should see:
   - Search bar at top
   - Filter buttons (All, Certified, Community, etc.)
   - List of operators with cards showing:
     - Operator name
     - Provider
     - Description
     - Install button

### If you don't see "Operators" in left sidebar:

This is the real issue. The Operators menu is missing.

---

## ⚠️ If Operators Menu is Missing

This means your user role doesn't have permission or the console feature is disabled.

### Fix Missing Operators Menu:

```bash
# Check your current user
kubectl whoami

# Check if you have cluster-admin role
kubectl auth can-i '*' '*' --as=<your-username>

# Should output: yes

# If no, add cluster-admin role
kubectl adm policy add-cluster-role-to-user cluster-admin <your-username>

# Then log out and log back in to console
```

---

## 🔍 Advanced Debugging

If still not seeing OperatorHub, run comprehensive diagnostics:

```bash
# 1. Check all marketplace pods
kubectl get pods -n openshift-marketplace -o wide

# 2. Check for errors
kubectl get events -n openshift-marketplace | tail -20

# 3. Check catalog operator logs
kubectl logs -n openshift-operator-lifecycle-manager deployment/catalog-operator | tail -50

# 4. Check OLM status
kubectl get clusterserviceversions -A

# 5. Check subscriptions
kubectl get subscriptions -A

# 6. Check operator groups
kubectl get operatorgroups -A
```

---

## 📋 Checklist

Before contacting support, verify:

- [ ] You can access console URL (no error page)
- [ ] You're logged in with cluster-admin credentials
- [ ] You hard-refreshed browser (Ctrl+Shift+R)
- [ ] Console pods are running: `kubectl get pods -n openshift-console`
- [ ] Marketplace pods are running: `kubectl get pods -n openshift-marketplace`
- [ ] No errors in pod logs: `kubectl logs -n openshift-marketplace -l app=marketplace-operator`
- [ ] "Operators" menu appears in left sidebar
- [ ] "OperatorHub" option appears under "Operators"

---

## 🆘 If Nothing Works

Use the **command-line method instead:**

```bash
# Instead of UI, search for operators via command line
kubectl get packagemanifests -n openshift-marketplace

# Install operator via kubectl (no UI needed)
kubectl apply -f <operator-subscription.yaml>

# Monitor installation
kubectl get subscription -A -w
kubectl get pods -n <operator-namespace> -w
```

This works just as well as the UI!

---

## Next Steps

1. **Try Solution 1** (Hard refresh) - 90% of cases fixed this way
2. **Try Solution 2** (Restart console) - If solution 1 doesn't work
3. **Try Solution 6** (CLI method) - If UI still broken
4. **Share the output** of these commands if you need help:
   - `kubectl get pods -n openshift-console`
   - `kubectl get pods -n openshift-marketplace`
   - `kubectl logs -n openshift-console -l app=console | tail -100`

---

**Let me know what you see!** I can guide you from there. 🚀
