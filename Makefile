TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

# Logging setup
LOGS_DIR := Logs
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
LOG_FILE := $(LOGS_DIR)/install-$(TIMESTAMP).log

# When true we set the default to a BM instance for Power90
BAREMETAL ?= false
ifeq ($(BAREMETAL), true)
	EXTRA_ARGS = -e @./vars/baremetal.yaml -e @./overrides.yml 
endif

# Setup logs directory
$(LOGS_DIR):
	@mkdir -p $(LOGS_DIR)


##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ocp-versions
ocp-versions: ## Prints latest minor versions for ocp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/print-ocp-versions.yml

.PHONY: ocp-clients
ocp-clients: ## Reads ocp_versions list and makes sure client tools are downloaded and uncompressed
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/ocp-clients.yml

.PHONY: install
install: $(LOGS_DIR) ## Install an OCP cluster on AWS using the ibm-fusion-access operator and configures gpfs on top
	@echo "📝 Logging to: $(LOGS_DIR)/install-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/install.yml 2>&1 | tee $(LOGS_DIR)/install-$(TIMESTAMP).log
	-@notify.sh "AWS install finished"

.PHONY: install-hitachi
install-hitachi: $(LOGS_DIR) ## Install an OCP cluster on AWS and deploy Hitachi VSP One SDS on top
	@echo "📝 Logging to: $(LOGS_DIR)/install-hitachi-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/install-hitachi.yml 2>&1 | tee $(LOGS_DIR)/install-hitachi-$(TIMESTAMP).log
	-@notify.sh "AWS OCP + Hitachi SDS install finished"

.PHONY: sds-deploy
sds-deploy: $(LOGS_DIR) ## Deploy Hitachi VSP One SDS Block on AWS (standalone)
	@echo "📝 Logging to: $(LOGS_DIR)/sds-deploy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/sds-block-deploy.yml 2>&1 | tee $(LOGS_DIR)/sds-deploy-$(TIMESTAMP).log
	-@notify.sh "Hitachi SDS Block deployment finished"

.PHONY: install-hitachi-with-sds
install-hitachi-with-sds: $(LOGS_DIR) ## Install OCP cluster and automatically deploy Hitachi SDS Block (complete stack)
	@echo "📝 Logging to: $(LOGS_DIR)/install-hitachi-with-sds-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) -e "deploy_sds_block=true" $(EXTRA_VARS) playbooks/install-hitachi.yml 2>&1 | tee $(LOGS_DIR)/install-hitachi-with-sds-$(TIMESTAMP).log
	-@notify.sh "AWS OCP + Hitachi SDS Block deployment finished"

.PHONY: virt
virt: ## Configures the virt bits (only for BAREMETAL)
	@if [ "$(BAREMETAL)" = "false" ]; then echo "Error, virt is only for baremetal environments"; exit 1; fi
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/virt.yml

.PHONY: oadp
oadp: ## Configures oadp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/oadp.yml

.PHONY: pvc-snapshot-perf
pvc-snapshot-perf: ## Runs a perf pvc -> snapshot -> pvc test
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/pvc-snapshot-perf.yml

.PHONY: ceph
ceph: ## Configures ceph
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/ceph.yml

.PHONY: iib
iib: ## Install an iib on an OCP cluster on AWS
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/iib.yml

.PHONY: grafana
grafana: ## Configures the grafana bits
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/grafana.yml

.PHONY: gpfs-cleanup
gpfs-cleanup: ## Deletes all the GPFS objects (https://www.ibm.com/docs/en/scalecontainernative/5.2.2?topic=cleanup-red-hat-openshift-nodes)
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/gpfs-cleanup.yml

.PHONY: gpfs-health
gpfs-health: ## Prints some GPFS healthcheck commands
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/gpfs-health.yml

.PHONY: destroy
destroy: $(LOGS_DIR) ## Destroy installed AWS cluster
	@echo "📝 Logging to: $(LOGS_DIR)/destroy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/destroy.yml 2>&1 | tee $(LOGS_DIR)/destroy-$(TIMESTAMP).log
	-@notify.sh "AWS destroy finished"

.PHONY: sds-block-destroy
sds-block-destroy: $(LOGS_DIR) ## Destroy Hitachi SDS Block infrastructure only (keeps OCP cluster)
	@echo "📝 Logging to: $(LOGS_DIR)/sds-block-destroy-$(TIMESTAMP).log"
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/sds-block-destroy.yml 2>&1 | tee $(LOGS_DIR)/sds-block-destroy-$(TIMESTAMP).log
	-@notify.sh "SDS Block destruction finished"

.PHONY: iscsi
iscsi: ## Creates iscsi ec2 target and connects it to worker nodes
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/iscsi.yml

.PHONY: iscsi-cleanup
iscsi-cleanup: ## Removes iscsi ec2 resources
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/iscsi-cleanup.yml

.PHONY: list-tags
list-tags: ## Lists all tags in the install playbook
	ansible-playbook --list-tags playbooks/install.yml

.PHONY: ansible-deps
ansible-deps: ## Install Ansible dependencies
	ansible-galaxy collection install -r requirements.yml

.PHONY: ebs-add
ebs-add: ## Adds a new EBS volume via ebs-add.yml.
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/ebs-add.yml

.PHONY: ebs-remove
ebs-remove: ## Removes an existing EBS volume via ebs-remove.yml.
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/ebs-remove.yml

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
	@echo "✅ Full OCP bootstrap cleanup complete"
	@echo "⚠️  WARNING: All OCP credentials and auth files have been removed"
	@echo "📝 You can now run: make install-hitachi or make install-hitachi-with-sds for a fresh deployment"

##@ Hitachi SDS Targets
-include Makefile.hitachi

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
