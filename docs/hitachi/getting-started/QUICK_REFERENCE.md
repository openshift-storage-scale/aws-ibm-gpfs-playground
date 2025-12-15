# Quick Reference - Deployment Commands

## 🚀 Quick Start

```bash
# Check network first
make hitachi-check-network

# Deploy operator (uses local charts if available)
make hitachi-deploy-operator

# Monitor logs in real-time
tail -f Logs/deploy-hitachi-operator-*.log
```

## 📥 Download Charts (Offline Preparation)

```bash
# On machine with internet access
./scripts/download-hitachi-charts.sh ./charts 3.14.0

# Create transfer archive
tar -czf hitachi-charts.tar.gz charts/vsp-one-sds-hspc/

# Transfer to cluster machine (via SCP, USB, etc.)
scp hitachi-charts.tar.gz user@cluster:/tmp/
```

## 🔗 Deploy with Pre-downloaded Charts

```bash
# On cluster machine
mkdir -p charts/
tar -xzf /tmp/hitachi-charts.tar.gz

# Deploy
make hitachi-deploy-operator

# Monitor
tail -f Logs/deploy-hitachi-operator-*.log
```

## 🌐 For Disconnected Environments

```bash
# Deploy using manifests (no Helm repo needed)
make hitachi-deploy-operator-disconnected

# Monitor
tail -f Logs/deploy-hitachi-operator-disconnected-*.log
```

## 📊 Check Network Status

```bash
make hitachi-check-network
cat Logs/check-network-connectivity-*.log
```

## 📝 View Logs

```bash
# Latest logs
ls -lh Logs/

# Monitor deployment
tail -f Logs/deploy-hitachi-operator-*.log

# Search for errors
grep ERROR Logs/*.log

# Full diagnostic
cat Logs/check-network-connectivity-*.log
```

## 🛠️ Makefile Targets

| Command | Purpose | Log File |
|---------|---------|----------|
| `make hitachi-check-network` | Diagnose network issues | `check-network-connectivity-*.log` |
| `make hitachi-download-charts` | Download charts for offline | `download-hitachi-charts-*.log` |
| `make hitachi-deploy-operator` | Deploy with local/online charts | `deploy-hitachi-operator-*.log` |
| `make hitachi-deploy-operator-disconnected` | Deploy for disconnected env | `deploy-hitachi-operator-disconnected-*.log` |
| `make hitachi-help` | Show all Hitachi targets | - |

## 🔧 Environment Variables

```bash
# Optional overrides (all optional)
export LOCAL_CHART_PATH=/custom/path/to/vsp-one-sds-hspc
export HELM_VERSION=3.14.0
export NAMESPACE=hitachi-system
export REGISTRY_URL=docker.io
export KUBECONFIG=/path/to/kubeconfig
```

## 📁 File Locations

```
Project Root/
├── Logs/                          # All log files (auto-created, gitignored)
├── charts/                        # Pre-downloaded charts (user-created)
│   └── vsp-one-sds-hspc/
├── scripts/
│   ├── download-hitachi-charts.sh
│   ├── check-network-connectivity.sh
│   └── deployment/
│       ├── deploy-hitachi-operator.sh
│       └── deploy-hitachi-operator-disconnected.sh
└── docs/
    └── DEPLOYMENT_LOGGING_AND_CHARTS.md
```

## 🎯 Deployment Scenarios

### Scenario 1: Connected Network
```bash
make hitachi-check-network
make hitachi-deploy-operator
```

### Scenario 2: Two Machines (Internet → Disconnected)
```bash
# Machine 1 (internet)
make hitachi-download-charts
tar -czf charts.tar.gz charts/vsp-one-sds-hspc/
scp charts.tar.gz user@cluster:/tmp/

# Machine 2 (cluster)
tar -xzf /tmp/charts.tar.gz
make hitachi-deploy-operator
```

### Scenario 3: Fully Air-gapped
```bash
# Machine 1: Transfer pre-built artifacts via USB/secure transfer
# Machine 2: Extract and deploy
tar -xzf /media/usb/charts.tar.gz
make hitachi-deploy-operator-disconnected
```

## ✅ Verification

```bash
# Check operator pods
kubectl get pods -n hitachi-system

# Check deployment status
kubectl get deployment -n hitachi-system vsp-one-sds-hspc

# View operator logs
kubectl logs -n hitachi-system -l app=vsp-one-sds-hspc

# Watch deployment
kubectl rollout status deployment/vsp-one-sds-hspc -n hitachi-system
```

## ⚠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| Cannot reach CDN | Use `make hitachi-deploy-operator` (pre-download charts first) |
| No logs created | Check `Logs/` directory exists; verify script permissions |
| Chart not found | Run `make hitachi-download-charts` first |
| Deployment fails | Check logs: `tail -f Logs/deploy-hitachi-operator-*.log` |
| Network issues | Run `make hitachi-check-network` for diagnostics |

## 📚 Documentation

- **Complete Guide:** `docs/DEPLOYMENT_LOGGING_AND_CHARTS.md`
- **Quick Reference:** `QUICK_START_DEPLOYMENT.sh`
- **Summary:** `DEPLOYMENT_UPDATES.md`
- **Network Troubleshooting:** `docs/HITACHI_NETWORK_TROUBLESHOOTING.md`

## 🔑 Key Features

✓ **Logging** - All output to `Logs/` with timestamps  
✓ **Offline Support** - Pre-download charts for disconnected environments  
✓ **Smart Fallback** - Tries local charts, then repo, then manifests  
✓ **Diagnostics** - Network connectivity check built-in  
✓ **Clean Repo** - Logs in `.gitignore`, no clutter  
✓ **Backward Compatible** - All existing scripts still work  

---

**Last Updated:** December 10, 2025
