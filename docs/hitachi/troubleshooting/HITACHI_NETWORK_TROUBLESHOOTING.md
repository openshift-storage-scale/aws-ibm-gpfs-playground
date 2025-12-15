# Hitachi Operator Deployment - Network Connectivity Solutions

## Problem
The deployment failed with: `Error: Couldn't resolve CDN hostname` when trying to add the Helm repository from `https://cdn.hitachivantara.com/charts/hitachi`.

This indicates the OpenShift cluster cannot reach external registry URLs, which is common in:
- Air-gapped/disconnected environments
- Restricted networks with firewalls
- Corporate environments with proxy requirements

## Solutions

### Solution 1: Check Network Connectivity
First, verify the actual network issue:

```bash
export KUBECONFIG=/home/nlevanon/aws-gpfs-playground/ocp_install_files/auth/kubeconfig

# Test DNS resolution from cluster
kubectl debug node/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') -it --image=busybox -- nslookup cdn.hitachivantara.com

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v https://cdn.hitachivantara.com/charts/hitachi
```

### Solution 2: Configure Proxy (If Behind Corporate Proxy)

Edit your shell environment and Helm configuration:

```bash
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080
export no_proxy=localhost,127.0.0.1,.cluster.local

# For Helm
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi \
    --http-basic user:password

# For Kubernetes
kubectl create secret generic helm-proxy-secret \
    --from-literal=username=USER \
    --from-literal=password=PASS \
    -n hitachi-system
```

### Solution 3: Use Disconnected Deployment (Recommended)

Use the new deployment script that works without external network access:

```bash
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

# Make script executable
chmod +x scripts/deployment/deploy-hitachi-operator-disconnected.sh

# Option A: Deploy with local chart (if you have the chart pre-downloaded)
export LOCAL_CHART_PATH=/path/to/hitachi/chart
./scripts/deployment/deploy-hitachi-operator-disconnected.sh

# Option B: Deploy with direct manifest (no Helm chart needed)
./scripts/deployment/deploy-hitachi-operator-disconnected.sh
```

### Solution 4: Pre-download and Cache Charts

If you need to use the original Helm-based deployment:

```bash
# From a machine with internet access:
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi
helm pull hitachi/vsp-one-sds-hspc --version 3.14.0 --untar

# Transfer the chart to your cluster
scp -r vsp-one-sds-hspc user@cluster:/tmp/

# On the cluster:
helm upgrade --install vsp-one-sds-hspc /tmp/vsp-one-sds-hspc \
    --namespace hitachi-system \
    --create-namespace \
    --set image.registry=docker.io
```

### Solution 5: Use Local Container Registry Mirror

Set up an internal registry and mirror images:

```bash
# Mirror the Hitachi container images
skopeo copy docker://docker.io/hitachi/vsp-one-sds-hspc:3.14.0 \
    docker://internal-registry.company.com/hitachi/vsp-one-sds-hspc:3.14.0

# Configure cluster to use mirror
kubectl patch clusterimagepolicy default --type='json' \
    -p='[{"op": "add", "path": "/spec/repositoryMirrors/-", \
    "value": {"mirrors": ["internal-registry.company.com"], \
    "source": "docker.io/hitachi"}}]'
```

## Recommended Approach for Your Environment

Based on your AWS/OCP setup:

1. **First attempt**: Try Solution 3 (Disconnected deployment)
   - No external network required
   - Uses pre-built manifests
   - Simplest to troubleshoot

2. **If container images unavailable**: 
   - Use Solution 4 (Pre-download from external network if possible)
   - Transfer via secure channel
   - Deploy locally

3. **For production environments**:
   - Implement Solution 5 (Internal registry mirror)
   - More maintainable long-term
   - Allows for image scanning and approval workflows

## Testing the Deployment

After deployment, verify the operator:

```bash
# Check operator pods
kubectl get pods -n hitachi-system

# Check operator logs
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc -f

# Check operator status
kubectl describe deployment -n hitachi-system vsp-one-sds-hspc

# Verify RBAC
kubectl auth can-i create persistentvolumes \
    --as=system:serviceaccount:hitachi-system:vsp-one-sds-hspc
```

## Next Steps

1. Determine your network environment type
2. Choose appropriate solution
3. Run the deployment
4. Configure storage array connection
5. Create StorageClass
6. Deploy test applications

## Support

If deployment still fails after trying these solutions:

1. Collect debug information:
```bash
kubectl describe deployment -n hitachi-system vsp-one-sds-hspc
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc --all-containers=true --tail=50
kubectl get events -n hitachi-system --sort-by='.lastTimestamp'
```

2. Check image availability:
```bash
kubectl get events -n hitachi-system | grep -i "image\|pull"
```

3. Verify network policies:
```bash
kubectl get networkpolicies --all-namespaces
```
