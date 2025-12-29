TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

# Logging setup
LOGS_DIR := Logs
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
LOG_FILE := $(LOGS_DIR)/install-$(TIMESTAMP).log

# Always load overrides.yml if it exists
OVERRIDES_FILE := $(wildcard ./overrides.yml)
ifneq ($(OVERRIDES_FILE),)
	OVERRIDES_ARGS = -e @./overrides.yml
else
	OVERRIDES_ARGS =
endif

# Default KUBECONFIG path (can be overridden by environment or overrides.yml)
KUBECONFIG_DEFAULT := $(HOME)/aws-gpfs-playground/ocp_install_files/auth/kubeconfig

# When true we set the default to a BM instance for Power90
BAREMETAL ?= false
ifeq ($(BAREMETAL), true)
	EXTRA_ARGS = -e @./vars/baremetal.yaml $(OVERRIDES_ARGS)
else
	EXTRA_ARGS = $(OVERRIDES_ARGS)
endif

# Helper function to get KUBECONFIG from overrides.yml or fall back to default
define get_kubeconfig
$(shell if [ -f overrides.yml ]; then \
	grep kubeconfig overrides.yml 2>/dev/null | head -1 | awk -F'"' '{print $$2}' | envsubst 2>/dev/null || echo "$(KUBECONFIG_DEFAULT)"; \
else \
	echo "$(KUBECONFIG_DEFAULT)"; \
fi)
endef

# Setup logs directory
$(LOGS_DIR):
	@mkdir -p $(LOGS_DIR)


# Check for overrides.yml and warn if missing (only for targets that need it)
.PHONY: check-overrides
check-overrides:
ifeq ($(OVERRIDES_FILE),)
	@echo "⚠️  WARNING: overrides.yml not found"
	@echo "   Some targets may not work correctly without configuration."
	@echo "   See README.md for instructions on creating overrides.yml"
	@echo ""
endif

##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ocp-versions
ocp-versions: ## Prints latest minor versions for ocp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/print-ocp-versions.yml

.PHONY: ocp-clients
ocp-clients: ## Reads ocp_versions list and makes sure client tools are downloaded and uncompressed
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/ocp-clients.yml

.PHONY: destroy
destroy: $(LOGS_DIR) ## Destroy installed AWS cluster
	@echo "📝 Logging to: $(LOGS_DIR)/destroy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/destroy.yml 2>&1 | tee $(LOGS_DIR)/destroy-$(TIMESTAMP).log
	-@notify.sh "AWS destroy finished"

.PHONY: oadp
oadp: ## Configures oadp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/oadp.yml

.PHONY: grafana
grafana: ## Configures the grafana bits
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/grafana.yml

.PHONY: iib
iib: ## Install an iib on an OCP cluster on AWS
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/iib.yml

.PHONY: ebs-add
ebs-add: ## Adds a new EBS volume via ebs-add.yml.
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/ebs-add.yml

.PHONY: ebs-remove
ebs-remove: ## Removes an existing EBS volume via ebs-remove.yml.
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/ebs-remove.yml

.PHONY: list-tags
list-tags: ## Lists all tags in the install playbook
	ansible-playbook --list-tags playbooks/gpfs/install.yml

.PHONY: ansible-deps
ansible-deps: ## Install Ansible dependencies
	ansible-galaxy collection install -r requirements.yml

##@ GPFS / IBM Spectrum Scale
.PHONY: install
install: $(LOGS_DIR) ## Install an OCP cluster on AWS using the ibm-fusion-access operator and configures gpfs on top
	@echo "📝 Logging to: $(LOGS_DIR)/install-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/gpfs/install.yml 2>&1 | tee $(LOGS_DIR)/install-$(TIMESTAMP).log
	-@notify.sh "AWS install finished"

.PHONY: gpfs-cleanup
gpfs-cleanup: ## Deletes all the GPFS objects (https://www.ibm.com/docs/en/scalecontainernative/5.2.2?topic=cleanup-red-hat-openshift-nodes)
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/gpfs/gpfs-cleanup.yml

.PHONY: gpfs-health
gpfs-health: ## Prints some GPFS healthcheck commands
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/gpfs/gpfs-health.yml

##@ Hitachi SDS Targets
.PHONY: install-hitachi
install-hitachi: $(LOGS_DIR) ## Install an OCP cluster on AWS and deploy Hitachi VSP One SDS on top
	@echo "📝 Logging to: $(LOGS_DIR)/install-hitachi-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/hitachi/install-hitachi.yml 2>&1 | tee $(LOGS_DIR)/install-hitachi-$(TIMESTAMP).log
	-@notify.sh "AWS OCP + Hitachi SDS install finished"

.PHONY: sds-deploy
sds-deploy: $(LOGS_DIR) ## Deploy Hitachi VSP One SDS Block on AWS (standalone)
	@echo "📝 Logging to: $(LOGS_DIR)/sds-deploy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/hitachi/sds-block-deploy.yml 2>&1 | tee $(LOGS_DIR)/sds-deploy-$(TIMESTAMP).log
	-@notify.sh "Hitachi SDS Block deployment finished"

.PHONY: install-hitachi-with-sds
install-hitachi-with-sds: $(LOGS_DIR) ## Install OCP cluster and automatically deploy Hitachi SDS Block (complete stack)
	@echo "📝 Logging to: $(LOGS_DIR)/install-hitachi-with-sds-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) -e "deploy_sds_block=true" $(EXTRA_VARS) playbooks/hitachi/install-hitachi.yml 2>&1 | tee $(LOGS_DIR)/install-hitachi-with-sds-$(TIMESTAMP).log
	-@notify.sh "AWS OCP + Hitachi SDS Block deployment finished"

.PHONY: sds-block-destroy
sds-block-destroy: $(LOGS_DIR) ## Destroy Hitachi SDS Block infrastructure only (keeps OCP cluster)
	@echo "📝 Logging to: $(LOGS_DIR)/sds-block-destroy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/hitachi/sds-block-destroy.yml 2>&1 | tee $(LOGS_DIR)/sds-block-destroy-$(TIMESTAMP).log
	-@notify.sh "SDS Block destruction finished"

.PHONY: hitachi-validation
hitachi-validation: ## Validate Hitachi SDS Block deployment
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/hitachi/hitachi-validation.yml

# Note: hitachi-cleanup target is defined in Makefile.hitachi with interactive confirmation

# Include additional Hitachi targets from Makefile.hitachi
-include Makefile.hitachi

##@ Ceph / ODF
.PHONY: ceph
ceph: ## Configures ceph
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/ceph/ceph.yml

##@ iSCSI
.PHONY: iscsi
iscsi: ## Creates iscsi ec2 target and connects it to worker nodes
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/iscsi/iscsi.yml

.PHONY: iscsi-cleanup
iscsi-cleanup: ## Removes iscsi ec2 resources
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/iscsi/iscsi-cleanup.yml

##@ Virtualization (CNV/KubeVirt)
.PHONY: virt
virt: ## Configures the virt bits (only for BAREMETAL)
	@if [ "$(BAREMETAL)" = "false" ]; then echo "Error, virt is only for baremetal environments"; exit 1; fi
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/common/virt.yml

.PHONY: cnv-install
cnv-install: $(LOGS_DIR) ## Install OpenShift CNV (KubeVirt) operator for VM workloads
	@echo "📝 Logging to: $(LOGS_DIR)/cnv-install-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/csicertification/kubevirt/cnv-install.yml 2>&1 | tee $(LOGS_DIR)/cnv-install-$(TIMESTAMP).log
	-@notify.sh "CNV installation finished"

.PHONY: install-with-virtualization
install-with-virtualization: $(LOGS_DIR) ## Install OCP + GPFS with metal instances for KVM/CNV support (required for VM-based CSI tests)
	@echo "📝 Logging to: $(LOGS_DIR)/install-virt-$(TIMESTAMP).log"
	@echo "🖥️  Using metal instances (m5zn.metal) for KVM virtualization support"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) -e "enable_virtualization=true" $(EXTRA_VARS) playbooks/gpfs/install.yml 2>&1 | tee $(LOGS_DIR)/install-virt-$(TIMESTAMP).log
	-@notify.sh "AWS install with virtualization finished"

.PHONY: install-hitachi-with-virtualization
install-hitachi-with-virtualization: $(LOGS_DIR) ## Install OCP + Hitachi with metal instances for KVM/CNV support
	@echo "📝 Logging to: $(LOGS_DIR)/install-hitachi-virt-$(TIMESTAMP).log"
	@echo "🖥️  Using metal instances (m5zn.metal) for KVM virtualization support"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) -e "enable_virtualization=true" $(EXTRA_VARS) playbooks/hitachi/install-hitachi.yml 2>&1 | tee $(LOGS_DIR)/install-hitachi-virt-$(TIMESTAMP).log
	-@notify.sh "AWS OCP + Hitachi with virtualization finished"

##@ CSI Certification / Storage Checkup
.PHONY: storage-checkup
storage-checkup: $(LOGS_DIR) ## Run KubeVirt Storage Checkup for CSI certification tests
	@echo "📝 Logging to: $(LOGS_DIR)/storage-checkup-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/csicertification/kubevirt/storage-checkup.yml 2>&1 | tee $(LOGS_DIR)/storage-checkup-$(TIMESTAMP).log

.PHONY: storage-checkup-results
storage-checkup-results: ## Get results from the last storage checkup run
	@bash scripts/validation/check-storage-checkup-results.sh

.PHONY: storage-checkup-logs
storage-checkup-logs: ## Stream logs from the storage checkup job
	@KUBECONFIG_PATH="$(call get_kubeconfig)"; \
	if [ -z "$$KUBECONFIG_PATH" ] || [ ! -f "$$KUBECONFIG_PATH" ]; then \
		echo "❌ Error: KUBECONFIG not found at $$KUBECONFIG_PATH"; \
		echo "   Create overrides.yml with 'kubeconfig' path or set KUBECONFIG environment variable"; \
		exit 1; \
	fi; \
	export KUBECONFIG="$$KUBECONFIG_PATH"; \
	oc logs -f job/storage-checkup -n storage-checkup

.PHONY: storage-checkup-cleanup
storage-checkup-cleanup: ## Clean up storage checkup resources
	@KUBECONFIG_PATH="$(call get_kubeconfig)"; \
	if [ -z "$$KUBECONFIG_PATH" ] || [ ! -f "$$KUBECONFIG_PATH" ]; then \
		echo "❌ Error: KUBECONFIG not found at $$KUBECONFIG_PATH"; \
		echo "   Create overrides.yml with 'kubeconfig' path or set KUBECONFIG environment variable"; \
		exit 1; \
	fi; \
	export KUBECONFIG="$$KUBECONFIG_PATH"; \
	oc delete namespace storage-checkup --ignore-not-found=true && \
	oc delete clusterrolebinding kubevirt-storage-checkup-clustereader storage-checkup-cluster-rolebinding --ignore-not-found=true && \
	oc delete clusterrole storage-checkup-cluster-role --ignore-not-found=true

##@ Storage Tests
.PHONY: pvc-snapshot-perf
pvc-snapshot-perf: ## Runs a perf pvc -> snapshot -> pvc test
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/storage-tests/pvc-snapshot-perf.yml

##@ OCP Bootstrap Cleanup
.PHONY: ocp-bootstrap-cleanup
ocp-bootstrap-cleanup: ## Clean up OCP bootstrap artifacts to allow re-running openshift-install
	@echo "🧹 Cleaning up OCP bootstrap artifacts..."
	@(pkill -9 -f "cluster-api|envtest" 2>/dev/null || true) &
	@sleep 2
	@rm -f ~/aws-gpfs-playground/ocp_install_files/metadata.json
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/cluster-api
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/.clusterapi_output
	@echo "🔄 Releasing unassociated Elastic IPs..."
	@aws ec2 describe-addresses --region eu-north-1 --filters "Name=tag:DaysCount,Values=*" --query 'Addresses[*].AllocationId' --output text | xargs -r -I {} aws ec2 release-address --allocation-id {} --region eu-north-1 2>/dev/null || true
	@echo "🗑️  Cleaning up stale VPCs (keeping only those in use)..."
	@bash scripts/cleanup-stale-vpcs.sh || true
	@echo "✅ OCP bootstrap cleanup complete"
	@echo "📝 You can now run: make install-hitachi or make install-hitachi-with-sds"

.PHONY: ocp-bootstrap-full-cleanup
ocp-bootstrap-full-cleanup: ## Full OCP cleanup - removes all installation artifacts and allows fresh deployment
	@echo "🧹 Performing full OCP bootstrap cleanup..."
	@(pkill -9 -f "cluster-api|envtest" 2>/dev/null || true) &
	@sleep 2
	@rm -f ~/aws-gpfs-playground/ocp_install_files/metadata.json
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/cluster-api
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/.clusterapi_output
	@rm -f ~/aws-gpfs-playground/ocp_install_files/.openshift_install.log
	@rm -f ~/aws-gpfs-playground/ocp_install_files/.openshift_install_state.json
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/auth
	@rm -rf ~/aws-gpfs-playground/ocp_install_files/tls
	@echo "🔄 Releasing unassociated Elastic IPs..."
	@aws ec2 describe-addresses --region eu-north-1 --filters "Name=tag:DaysCount,Values=*" --query 'Addresses[*].AllocationId' --output text | xargs -r -I {} aws ec2 release-address --allocation-id {} --region eu-north-1 2>/dev/null || true
	@echo "🗑️  Cleaning up stale VPCs (keeping only those in use)..."
	@bash scripts/cleanup-stale-vpcs.sh || true
	@echo "✅ Full OCP bootstrap cleanup complete"
	@echo "⚠️  WARNING: All OCP credentials and auth files have been removed"
	@echo "📝 You can now run: make install-hitachi or make install-hitachi-with-sds for a fresh deployment"

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
