# Hitachi Operator Deployment - Logging & Pre-downloaded Charts

## Overview

The deployment scripts have been updated to:
1. **Log all operations** to the `Logs/` directory (automatically created, in `.gitignore`)
2. **Support pre-downloaded Helm charts** for disconnected environments
3. **Provide automatic fallback** between online and offline deployment methods

## Log Files

All deployment and diagnostic scripts now output logs to the `Logs/` directory:

```bash
Logs/
├── deploy-hitachi-operator-20251210_120530.log
├── deploy-hitachi-operator-disconnected-20251210_120430.log
├── check-network-connectivity-20251210_120330.log
└── download-hitachi-charts-20251210_120230.log
```

**Logs are in `.gitignore`** - they won't be committed to the repository.

### Viewing Logs

```bash
# View latest deployment logs
tail -f Logs/deploy-hitachi-operator-*.log

# View all connectivity diagnostics
cat Logs/check-network-connectivity-*.log

# Search logs for errors
grep ERROR Logs/*.log
```

## Pre-downloaded Helm Charts

### Step 1: Download Charts (On Machine with Internet)

From a machine that has internet access:

```bash
# Navigate to project directory
cd /path/to/aws-ibm-gpfs-playground

# Download charts using the helper script
./scripts/download-hitachi-charts.sh

# Or download manually
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi
helm pull hitachi/vsp-one-sds-hspc --version 3.14.0 --untar
mkdir -p charts/
mv vsp-one-sds-hspc charts/
```

This creates:
```bash
charts/
└── vsp-one-sds-hspc/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── ...
```

### Step 2: Transfer to Cluster Machine

Transfer the downloaded charts:

```bash
# Create tarball for easy transfer
tar -czf vsp-one-sds-hspc-3.14.0.tar.gz -C charts/ vsp-one-sds-hspc/

# Transfer to cluster machine via SCP
scp vsp-one-sds-hspc-3.14.0.tar.gz user@cluster-machine:/tmp/

# Or copy via USB, Git, etc.
```

### Step 3: Extract on Cluster Machine

```bash
# On cluster machine
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

# Extract charts
mkdir -p charts/
tar -xzf /tmp/vsp-one-sds-hspc-3.14.0.tar.gz -C charts/

# Verify
ls -la charts/vsp-one-sds-hspc/
```

## Deployment Methods

### Method 1: Standard Deployment (With Internet)

Uses Helm repository directly:

```bash
make hitachi-deploy-operator

# Or with specific kubeconfig
./scripts/deployment/deploy-hitachi-operator.sh \
    ~/.kube/config \
    hitachi-system \
    3.14.0 \
    false  # Don't require local chart
```

### Method 2: Deployment with Pre-downloaded Charts (Recommended)

Uses local charts if available, falls back to repo:

```bash
make hitachi-deploy-operator

# Or explicitly
./scripts/deployment/deploy-hitachi-operator.sh \
    ~/.kube/config \
    hitachi-system \
    3.14.0 \
    true   # Prefer local chart
```

**Script logic:**
1. Checks if `charts/vsp-one-sds-hspc/` exists
2. If yes → uses local chart
3. If no → attempts to download from Helm repo
4. If download fails → provides instructions for offline setup

### Method 3: Disconnected Deployment

For completely air-gapped environments:

```bash
make hitachi-deploy-operator-disconnected

# Or with custom chart path
export LOCAL_CHART_PATH=/custom/path/to/chart
./scripts/deployment/deploy-hitachi-operator-disconnected.sh
```

**Features:**
- Creates operator directly using manifests (no Helm repo needed)
- Falls back to manifest deployment if chart unavailable
- Full support for local container images

## Debugging

### Check Network Connectivity First

```bash
make hitachi-check-network

# Outputs to: Logs/check-network-connectivity-YYYYMMDD_HHMMSS.log
```

This diagnostic script checks:
- DNS resolution to cdn.hitachivantara.com
- HTTP connectivity to Docker Hub
- HTTP connectivity to Quay.io
- NetworkPolicy restrictions
- Egress rules

### View Deployment Logs

```bash
# Real-time monitoring
tail -f Logs/deploy-hitachi-operator-*.log

# Full log analysis
cat Logs/deploy-hitachi-operator-*.log | grep -E "ERROR|FAILED|✗"
```

### Troubleshoot Chart Issues

```bash
# Verify chart is in place
ls -la charts/vsp-one-sds-hspc/

# Check chart syntax
helm lint charts/vsp-one-sds-hspc/

# Dry-run deployment
helm install --dry-run vsp-one-sds-hspc charts/vsp-one-sds-hspc/ \
    --namespace hitachi-system \
    --create-namespace
```

## Complete Workflow Example

### For Air-Gapped Environment

**Machine 1 (with internet):**
```bash
# 1. Download charts
./scripts/download-hitachi-charts.sh
tar -czf charts.tar.gz charts/vsp-one-sds-hspc/

# 2. Transfer (via USB, secure transfer, etc.)
# Copy charts.tar.gz to secure transport
```

**Machine 2 (cluster machine, no internet):**
```bash
# 1. Extract transferred files
mkdir -p charts/
tar -xzf /transferred/path/charts.tar.gz -C charts/

# 2. Deploy operator
make hitachi-deploy-operator
# OR
make hitachi-deploy-operator-disconnected

# 3. Check logs
tail -f Logs/deploy-hitachi-operator-*.log
```

### For Network-Connected Environment

```bash
# 1. Check network
make hitachi-check-network

# 2. Download charts for offline use (optional)
make hitachi-download-charts

# 3. Deploy operator
make hitachi-deploy-operator

# 4. Monitor logs
tail -f Logs/deploy-hitachi-operator-*.log
```

## Configuration

### Environment Variables

```bash
# Chart path (defaults to ./charts/vsp-one-sds-hspc)
export LOCAL_CHART_PATH=/custom/path/to/chart

# Helm version
export HELM_VERSION=3.14.0

# Namespace
export NAMESPACE=hitachi-system

# Container registry
export REGISTRY_URL=docker.io

# Kubeconfig location
export KUBECONFIG=/path/to/kubeconfig
```

### Script Parameters

#### deploy-hitachi-operator.sh

```bash
./scripts/deployment/deploy-hitachi-operator.sh \
    [KUBECONFIG_PATH] \
    [NAMESPACE] \
    [HELM_VERSION] \
    [USE_LOCAL_CHART]

# Example
./scripts/deployment/deploy-hitachi-operator.sh \
    ~/.kube/config \
    hitachi-system \
    3.14.0 \
    true
```

#### download-hitachi-charts.sh

```bash
./scripts/download-hitachi-charts.sh \
    [OUTPUT_DIRECTORY] \
    [VERSION]

# Example
./scripts/download-hitachi-charts.sh \
    /home/user/my-charts \
    3.14.0
```

## Best Practices

1. **Always check network first:**
   ```bash
   make hitachi-check-network
   ```

2. **Pre-download charts when possible:**
   ```bash
   make hitachi-download-charts
   ```

3. **Monitor logs during deployment:**
   ```bash
   tail -f Logs/deploy-hitachi-operator-*.log
   ```

4. **Keep logs for troubleshooting:**
   - Logs are in `.gitignore` so they don't clutter repo
   - Archive logs periodically for audit trail
   - Check logs before reporting issues

5. **Use version control for charts:**
   - Once downloaded, consider versioning the charts
   - Or maintain a separate chart repository mirror

## Makefile Targets

```bash
# Download charts for offline use
make hitachi-download-charts

# Deploy with local/online chart support
make hitachi-deploy-operator

# Deploy for disconnected environments
make hitachi-deploy-operator-disconnected

# Check network connectivity
make hitachi-check-network

# View complete help
make hitachi-help
```

## Troubleshooting

### Chart Not Found Error

**Problem:** `Error: chart directory not found: ./charts/vsp-one-sds-hspc`

**Solution:**
```bash
# Download the chart first
make hitachi-download-charts

# Or manually
./scripts/download-hitachi-charts.sh ./charts 3.14.0

# Or don't require local chart
./scripts/deployment/deploy-hitachi-operator.sh ~/.kube/config hitachi-system 3.14.0 false
```

### CDN Access Error

**Problem:** `Error: Couldn't resolve CDN hostname`

**Solution:**
1. Check network: `make hitachi-check-network`
2. Use pre-downloaded charts: `make hitachi-deploy-operator`
3. Use disconnected mode: `make hitachi-deploy-operator-disconnected`

### Logs Not Generated

**Problem:** No files in `Logs/` directory

**Solution:**
```bash
# Check script permissions
ls -la scripts/deployment/deploy-hitachi-operator*.sh

# Check if Logs directory exists
ls -la Logs/

# Run deployment with explicit logging
./scripts/deployment/deploy-hitachi-operator.sh 2>&1 | tee custom.log
```

## File Structure

```bash
.
├── .gitignore                          # Added: Logs/ and *.log
├── Makefile.hitachi                    # Updated: new targets for logging/charts
├── Logs/                               # Created (auto, in gitignore)
├── charts/                             # Created by user (for pre-downloaded charts)
│   └── vsp-one-sds-hspc/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── scripts/
    ├── check-network-connectivity.sh   # Updated: adds logging
    ├── download-hitachi-charts.sh      # New: download charts for offline use
    └── deployment/
        ├── deploy-hitachi-operator.sh                  # Updated: logging + chart logic
        └── deploy-hitachi-operator-disconnected.sh     # Updated: logging + better chart handling
```

## Additional Resources

- [Hitachi Documentation](https://cdn.hitachivantara.com/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [OpenShift Documentation](https://docs.openshift.com/)
