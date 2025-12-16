TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

# When true we set the default to a BM instance for Power90
BAREMETAL ?= false
ifeq ($(BAREMETAL), true)
	EXTRA_ARGS = -e @./vars/baremetal.yaml -e @./overrides.yml 
endif

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
install: ## Install an OCP cluster on AWS using the ibm-fusion-access operator and configures gpfs on top
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/install.yml
	-@notify.sh "AWS install finished"

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
destroy: ## Destroy installed AWS cluster
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/destroy.yml
	-@notify.sh "AWS destroy finished"

##@ AWS Stale Resources Cleanup
.PHONY: aws-cleanup-stale-resources
aws-cleanup-stale-resources: ## Clean up ALL stale AWS resources (Load Balancers, Target Groups, NAT Gateways, Security Groups, VPCs)
	@bash scripts/cleanup-aws-comprehensive.sh $(OCP_REGION)

.PHONY: aws-cleanup-stale-resources-dryrun
aws-cleanup-stale-resources-dryrun: ## Preview stale resource cleanup without making changes (--dry-run mode)
	@bash scripts/cleanup-aws-comprehensive.sh $(OCP_REGION) --dry-run

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

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
