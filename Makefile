TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ocp-versions
ocp-versions: ## Prints latest minor versions for ocp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/print-ocp-versions.yml

.PHONY: ocp-clients
ocp-clients: ## Reads ocp_versions list and makes sure client tools are downloaded and uncompressed
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/ocp-clients.yml

.PHONY: install
install: ## Install an OCP cluster on AWS using the openshift-fusion-access operator
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/install.yml

.PHONY: gpfs-cleanup
gpfs-cleanup: ## Deletes all the GPFS objects (https://www.ibm.com/docs/en/scalecontainernative/5.2.2?topic=cleanup-red-hat-openshift-nodes)
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/gpfs-cleanup.yml

.PHONY: gpfs-health
gpfs-health: ## Prints some GPFS healthcheck commands
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/gpfs-health.yml

.PHONY: destroy
destroy: ## Destroy installed AWS cluster
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/destroy.yml

.PHONY: list-tags
list-tags: ## Lists all tags in the install playbook
	ansible-playbook --list-tags playbooks/install.yml

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
