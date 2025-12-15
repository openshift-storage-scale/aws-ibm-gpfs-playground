#!/bin/bash
##############################################################################
# QUICK START GUIDE - Hitachi Deployment with Logging & Charts
##############################################################################

# ============================================================================
# 1. QUICK START - For Connected Environments
# ============================================================================

# Step 1: Check network connectivity
make hitachi-check-network

# Step 2: Deploy operator (uses local charts if available)
make hitachi-deploy-operator

# Step 3: Monitor logs
tail -f Logs/deploy-hitachi-operator-*.log


# ============================================================================
# 2. FOR DISCONNECTED/AIR-GAPPED ENVIRONMENTS
# ============================================================================

# ON INTERNET-CONNECTED MACHINE:
# ================================

# Step 1: Download charts
./scripts/download-hitachi-charts.sh ./charts 3.14.0

# Step 2: Create tarball for transfer
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground
tar -czf hitachi-charts.tar.gz charts/vsp-one-sds-hspc/

# Step 3: Transfer to cluster machine (via SCP, USB, etc.)
# scp hitachi-charts.tar.gz user@cluster-machine:/tmp/


# ON CLUSTER MACHINE (NO INTERNET):
# ===================================

# Step 1: Extract transferred charts
cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground
mkdir -p charts/
tar -xzf /tmp/hitachi-charts.tar.gz

# Step 2: Deploy operator
make hitachi-deploy-operator
# OR (for fully disconnected)
make hitachi-deploy-operator-disconnected

# Step 3: Monitor deployment
tail -f Logs/deploy-hitachi-operator-*.log

# Step 4: Verify deployment
kubectl get pods -n hitachi-system


# ============================================================================
# 3. LOG MANAGEMENT
# ============================================================================

# View latest logs
tail -f Logs/deploy-hitachi-operator-*.log

# Search for errors
grep ERROR Logs/*.log

# View full diagnostic
cat Logs/check-network-connectivity-*.log

# Archive logs
tar -czf logs-backup.tar.gz Logs/


# ============================================================================
# 4. MAKEFILE TARGETS
# ============================================================================

# Download charts for offline use
make hitachi-download-charts
# Log: Logs/download-hitachi-charts-YYYYMMDD_HHMMSS.log

# Deploy with local chart support
make hitachi-deploy-operator
# Log: Logs/deploy-hitachi-operator-YYYYMMDD_HHMMSS.log

# Deploy for disconnected environments
make hitachi-deploy-operator-disconnected
# Log: Logs/deploy-hitachi-operator-disconnected-YYYYMMDD_HHMMSS.log

# Check network connectivity
make hitachi-check-network
# Log: Logs/check-network-connectivity-YYYYMMDD_HHMMSS.log

# Show all Hitachi targets
make hitachi-help


# ============================================================================
# 5. TROUBLESHOOTING
# ============================================================================

# Cannot reach CDN?
# → Use pre-downloaded charts: make hitachi-download-charts
# → Deploy with local charts: make hitachi-deploy-operator
# → Use disconnected mode: make hitachi-deploy-operator-disconnected

# Logs not created?
# → Check logs directory: ls -la Logs/
# → Check script permissions: ls -la scripts/deployment/
# → Check project root: pwd

# Need to restart deployment?
# → Previous logs are in Logs/ with timestamps
# → New logs will be created on next run
# → No conflicts - each run has unique timestamp

# Docker Hub or Quay unreachable?
# → Fallback to disconnected deployment
# → Use local container images if available


# ============================================================================
# 6. FILE STRUCTURE
# ============================================================================

# Before deployment:
# .
# ├── .gitignore (Logs/ and *.log added)
# ├── Makefile.hitachi (updated with new targets)
# ├── docs/
# │   └── DEPLOYMENT_LOGGING_AND_CHARTS.md
# └── scripts/
#     ├── check-network-connectivity.sh
#     ├── download-hitachi-charts.sh
#     └── deployment/
#         ├── deploy-hitachi-operator.sh
#         └── deploy-hitachi-operator-disconnected.sh

# After first deployment:
# .
# ├── Logs/
# │   ├── check-network-connectivity-20251210_130228.log
# │   ├── download-hitachi-charts-20251210_140000.log
# │   ├── deploy-hitachi-operator-20251210_140530.log
# │   └── deploy-hitachi-operator-disconnected-20251210_150000.log
# └── charts/
#     └── vsp-one-sds-hspc/
#         ├── Chart.yaml
#         ├── values.yaml
#         └── templates/


# ============================================================================
# 7. ENVIRONMENT VARIABLES
# ============================================================================

# Optional: Override defaults
export LOCAL_CHART_PATH=/custom/path/to/vsp-one-sds-hspc
export HELM_VERSION=3.14.0
export NAMESPACE=hitachi-system
export REGISTRY_URL=docker.io
export KUBECONFIG=/path/to/kubeconfig

# Then run:
./scripts/deployment/deploy-hitachi-operator.sh


# ============================================================================
# 8. VERIFICATION
# ============================================================================

# After deployment, verify with:
kubectl get pods -n hitachi-system
kubectl get deployment -n hitachi-system
kubectl describe deployment -n hitachi-system vsp-one-sds-hspc
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc

# Or use the diagnostic script:
make hitachi-check-network


# ============================================================================
# 9. KEY FEATURES
# ============================================================================

# ✓ All output automatically logged to Logs/ directory
# ✓ Logs not committed (in .gitignore)
# ✓ Pre-downloaded charts support for offline environments
# ✓ Automatic fallback between online and offline modes
# ✓ Helper script to download charts for transfer
# ✓ Manifest-based fallback for fully disconnected environments
# ✓ Timestamps on all log files for easy tracking
# ✓ Detailed network diagnostics built-in


# ============================================================================
# COMPLETE EXAMPLE - FULL DEPLOYMENT
# ============================================================================

#!/bin/bash
set -e

cd /home/nlevanon/workspace/openshift-storage-scale/aws-ibm-gpfs-playground

echo "Step 1: Check network"
make hitachi-check-network

echo "Step 2: Download charts (if internet available)"
make hitachi-download-charts || echo "⚠ Could not download charts - will use pre-existing or manifests"

echo "Step 3: Prepare namespaces"
make hitachi-prepare-ns

echo "Step 4: Deploy operator"
make hitachi-deploy-operator

echo "Step 5: Wait for operator"
kubectl wait --for=condition=available --timeout=300s deployment/vsp-one-sds-hspc -n hitachi-system || true

echo "Step 6: Allocate EIP"
# make hitachi-allocate-eip  # Uncomment if needed

echo "✓ Complete! Check logs in Logs/ directory"
ls -lh Logs/*.log | tail -5
