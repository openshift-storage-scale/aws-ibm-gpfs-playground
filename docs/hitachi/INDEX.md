# Hitachi VSP One SDS Documentation Index

Complete documentation for Hitachi VSP One SDS Block deployment on OpenShift.

---

## 📋 Getting Started

Start here if you're new to Hitachi SDS deployment.

| Document | Purpose |
|----------|---------|
| **[HITACHI_README.md](HITACHI_README.md)** | Overview and key concepts |
| **[HITACHI_QUICKSTART.md](getting-started/HITACHI_QUICKSTART.md)** | 5-minute quick start guide |
| **[QUICK_REFERENCE.md](getting-started/QUICK_REFERENCE.md)** | Common commands and workflows |

---

## 🚀 Installation & Deployment

Complete guides for installing and deploying Hitachi SDS.

### Installation Methods

| Document | Purpose |
|----------|---------|
| **[HITACHI_SDS_INSTALLATION_GUIDE.md](installation/HITACHI_SDS_INSTALLATION_GUIDE.md)** | Step-by-step installation guide |
| **[HITACHI_IMPLEMENTATION_SUMMARY.md](installation/HITACHI_IMPLEMENTATION_SUMMARY.md)** | Complete implementation summary |
| **[HITACHI_DEPLOYMENT_SUMMARY.md](installation/HITACHI_DEPLOYMENT_SUMMARY.md)** | Deployment process overview |

### UI-Based Installation

| Document | Purpose |
|----------|---------|
| **[INSTALL_VIA_UI_AND_EXTRACT_YAML.md](getting-started/INSTALL_VIA_UI_AND_EXTRACT_YAML.md)** | Complete UI installation workflow |
| **[QUICK_UI_EXTRACTION_WORKFLOW.md](getting-started/QUICK_UI_EXTRACTION_WORKFLOW.md)** | Quick UI extraction process |
| **[UI_INSTALLATION_AND_EXTRACTION_INDEX.md](getting-started/UI_INSTALLATION_AND_EXTRACTION_INDEX.md)** | UI installation index and navigation |
| **[UI_INSTALLATION_STRATEGY.md](getting-started/UI_INSTALLATION_STRATEGY.md)** | Strategic approach to UI installation |

### Helm Configuration

| Document | Purpose |
|----------|---------|
| **[HITACHI_HELM_SETUP_GUIDE.md](installation/HITACHI_HELM_SETUP_GUIDE.md)** | Helm chart configuration and deployment |

---

## 🏗️ Architecture & Design

Understanding the system architecture and design decisions.

| Document | Purpose |
|----------|---------|
| **[PLAYBOOK_ARCHITECTURE.md](architecture/PLAYBOOK_ARCHITECTURE.md)** | Ansible playbook architecture and structure |
| **[SCRIPTS_CODIFICATION.md](architecture/SCRIPTS_CODIFICATION.md)** | Script organization and codification approach |
| **[CLOUDFORMATION_FIXES.md](architecture/CLOUDFORMATION_FIXES.md)** | CloudFormation template fixes and improvements |
| **[DEPLOYMENT_LOGGING_AND_CHARTS.md](architecture/DEPLOYMENT_LOGGING_AND_CHARTS.md)** | Logging strategy and chart management |

---

## ✅ Deployment Verification & Testing

Verifying and testing deployment success.

| Document | Purpose |
|----------|---------|
| **[VERIFICATION_SUMMARY.md](deployment/VERIFICATION_SUMMARY.md)** | Verification checklist and summary |
| **[DEPLOYMENT_TESTING_FINAL.md](deployment/DEPLOYMENT_TESTING_FINAL.md)** | Complete deployment testing results |
| **[DEPLOYMENT_TEST_RESULTS.md](deployment/DEPLOYMENT_TEST_RESULTS.md)** | Detailed test results |
| **[DEPLOYMENT_UPDATES.md](deployment/DEPLOYMENT_UPDATES.md)** | Deployment updates and changelog |

---

## 🔧 Operations & Maintenance

Managing deployed systems.

| Document | Purpose |
|----------|---------|
| **[AUTOMATIC_SDS_CLEANUP_INTEGRATION.md](operations/AUTOMATIC_SDS_CLEANUP_INTEGRATION.md)** | Automatic SDS cleanup with `make destroy` |
| **[FIX_MAKE_DESTROY_STUCK_WITH_SDS.md](operations/FIX_MAKE_DESTROY_STUCK_WITH_SDS.md)** | Fixing stuck `make destroy` processes |

---

## 🐛 Troubleshooting & Debugging

Solving common issues and problems.

| Document | Purpose |
|----------|---------|
| **[TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md](troubleshooting/TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md)** | OperatorHub visibility issues and solutions |
| **[OPERATORHUB_ISSUE_AND_SOLUTIONS.md](troubleshooting/OPERATORHUB_ISSUE_AND_SOLUTIONS.md)** | OperatorHub problems and comprehensive solutions |
| **[HITACHI_NETWORK_TROUBLESHOOTING.md](troubleshooting/HITACHI_NETWORK_TROUBLESHOOTING.md)** | Network connectivity issues and diagnostics |

---

## 📂 Documentation Structure

```
docs/hitachi/
├── INDEX.md                          ← You are here
├── HITACHI_README.md                 ← Main entry point
├── getting-started/                  ← Quick start and UI guides
│   ├── HITACHI_QUICKSTART.md
│   ├── QUICK_REFERENCE.md
│   ├── INSTALL_VIA_UI_AND_EXTRACT_YAML.md
│   ├── QUICK_UI_EXTRACTION_WORKFLOW.md
│   ├── UI_INSTALLATION_AND_EXTRACTION_INDEX.md
│   └── UI_INSTALLATION_STRATEGY.md
├── installation/                     ← Installation guides
│   ├── HITACHI_SDS_INSTALLATION_GUIDE.md
│   ├── HITACHI_IMPLEMENTATION_SUMMARY.md
│   ├── HITACHI_DEPLOYMENT_SUMMARY.md
│   └── HITACHI_HELM_SETUP_GUIDE.md
├── deployment/                       ← Deployment verification & testing
│   ├── VERIFICATION_SUMMARY.md
│   ├── DEPLOYMENT_TESTING_FINAL.md
│   ├── DEPLOYMENT_TEST_RESULTS.md
│   └── DEPLOYMENT_UPDATES.md
├── architecture/                     ← System design & architecture
│   ├── PLAYBOOK_ARCHITECTURE.md
│   ├── SCRIPTS_CODIFICATION.md
│   ├── CLOUDFORMATION_FIXES.md
│   └── DEPLOYMENT_LOGGING_AND_CHARTS.md
├── operations/                       ← Operations & maintenance
│   ├── AUTOMATIC_SDS_CLEANUP_INTEGRATION.md
│   └── FIX_MAKE_DESTROY_STUCK_WITH_SDS.md
└── troubleshooting/                  ← Debugging & issue resolution
    ├── TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md
    ├── OPERATORHUB_ISSUE_AND_SOLUTIONS.md
    └── HITACHI_NETWORK_TROUBLESHOOTING.md
```

---

## 🔗 Quick Navigation

### By Use Case

**I want to deploy Hitachi SDS:**
1. Start with [HITACHI_QUICKSTART.md](getting-started/HITACHI_QUICKSTART.md)
2. Follow [HITACHI_SDS_INSTALLATION_GUIDE.md](installation/HITACHI_SDS_INSTALLATION_GUIDE.md)
3. Use [HITACHI_HELM_SETUP_GUIDE.md](installation/HITACHI_HELM_SETUP_GUIDE.md) for Helm configuration

**I want to install via OCP UI:**
1. Read [INSTALL_VIA_UI_AND_EXTRACT_YAML.md](getting-started/INSTALL_VIA_UI_AND_EXTRACT_YAML.md)
2. Follow [QUICK_UI_EXTRACTION_WORKFLOW.md](getting-started/QUICK_UI_EXTRACTION_WORKFLOW.md)
3. Use [UI_INSTALLATION_STRATEGY.md](getting-started/UI_INSTALLATION_STRATEGY.md) for strategy

**Something is broken:**
1. Check [QUICK_REFERENCE.md](getting-started/QUICK_REFERENCE.md) for common issues
2. Review [TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md](troubleshooting/TROUBLESHOOT_OPERATORHUB_NOT_VISIBLE.md) if UI issues
3. Check [HITACHI_NETWORK_TROUBLESHOOTING.md](troubleshooting/HITACHI_NETWORK_TROUBLESHOOTING.md) for network problems

**I need to clean up / destroy:**
1. Read [AUTOMATIC_SDS_CLEANUP_INTEGRATION.md](operations/AUTOMATIC_SDS_CLEANUP_INTEGRATION.md)
2. If stuck, see [FIX_MAKE_DESTROY_STUCK_WITH_SDS.md](operations/FIX_MAKE_DESTROY_STUCK_WITH_SDS.md)

**I want to understand the architecture:**
1. Start with [PLAYBOOK_ARCHITECTURE.md](architecture/PLAYBOOK_ARCHITECTURE.md)
2. Review [SCRIPTS_CODIFICATION.md](architecture/SCRIPTS_CODIFICATION.md)
3. Check [DEPLOYMENT_LOGGING_AND_CHARTS.md](architecture/DEPLOYMENT_LOGGING_AND_CHARTS.md)

---

## 📚 Related Documentation

For scripts and automation:
- See `scripts/` directory for executable scripts
- See `playbooks/` directory for Ansible playbooks
- See `docs/` root for project-wide documentation

---

## ⏱️ Document Last Updated

Last organized: December 14, 2025

---

## 📝 Contributing

When adding new Hitachi documentation:

1. **Choose the right category:**
   - `getting-started/` - Quick guides, references, first-time setup
   - `installation/` - Installation procedures and guides
   - `deployment/` - Deployment testing, verification, updates
   - `architecture/` - Design, architecture, technical decisions
   - `operations/` - Maintenance, cleanup, destruction
   - `troubleshooting/` - Issues, debugging, solutions

2. **Update this INDEX.md** with the new document

3. **Use consistent naming:** Use UPPERCASE_WITH_UNDERSCORES.md

4. **Add to appropriate table** above

---

## 🤝 Support

For issues or questions:
1. Search relevant troubleshooting documents
2. Check the Quick Reference guide
3. Review the Hitachi README for overview
4. Consult playbook documentation for automation details
