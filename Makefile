TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

# When true we set the default to a BM instance for Power90
POWER90 ?= false
ifeq ($(POWER90), true)
	EXTRA_ARGS = -e @./overrides.yml -e @./vars/power90.yaml
endif

# This section defines the test framework for the Makefile.

# Variable to defined functions that can be tested
TESTABLE_FUNCS := center_banner veritas

# Validates the FUNC variable and runs the corresponding test function
# Usage: `make test FUNC=<function_name>`
# Example: `make test FUNC=center_banner`
# To see available test functions, run `make test-help`
.PHONY: test
test:
	@if [ -z "$(FUNC)" ]; then \
		echo "Usage: make test FUNC=<function_name>"; \
		$(MAKE) test-help; \
		exit 1; \
	fi; \
	if ! echo "$(TESTABLE_FUNCS)" | grep -qw "$(FUNC)"; then \
		echo "Unknown FUNC='$(FUNC)'"; \
		$(MAKE) test-help; \
		exit 1; \
	fi; \
	$(MAKE) test-$(FUNC)

.PHONY: test-help
test-help:
	@echo "Available test functions:"
	@for f in $(TESTABLE_FUNCS); do echo "  - $$f"; done

# Test framework ends here

# To print a message in the center of the terminal
# Usage: $(call center_banner, "Your message here")
# Example: $(call center_banner, "Welcome to the OCP Installer")
# This will print the message centered with '=' padding
define center_banner
	cols=$$(tput cols); \
	msg=" $(1) "; \
	msg_len=$${#msg}; \
	padding=$$(( (cols - msg_len) / 2 )); \
	fill=$$(printf '%*s' "$$padding" | tr ' ' '='); \
	printf "%s%s%s\n" "$$fill" "$$msg" "$$fill"; \
	[ $$(( (cols - msg_len) % 2 )) -eq 1 ] && printf "=\n" || true
endef


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
virt: ## Configures the virt bits (only for POWER90)
	@if [ "$(POWER90)" = "false" ]; then echo "Error, virt is only for power90"; exit 1; fi
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

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v

# Usage: `make test FUNC=center_banner` 
# OR `make test FUNC=center_banner MSG="Your message is here"`
.PHONY: test-center_banner
test-center_banner: ## Test the center_banner function
	$(call center_banner,$(if $(MSG),$(MSG),Default Test message which should be centered))

# Usage: `make veritas POWER90=true`
# This will provision a baremetal cluster with minimal OCP install and setup the Veritas stack.
# or `make veritas TAGS=dependencies` to just install dependencies
# or `make veritas TAGS=install` to install veritas stack 
# or `make veritas TAGS=cleanup` to uninstall veritas stack
.PHONY: veritas
veritas: ## Provision cluster with minimal install and setup Veritas stack
	@echo "TAGS: $(TAGS)"
	@echo "TAGS_STRING: $(TAGS_STRING)"
	@echo "POWER90: $(POWER90)"
	@echo "EXTRA_ARGS: $(EXTRA_ARGS)"
	@echo "EXTRA_VARS: $(EXTRA_VARS)"

	@if [ -z "$(TAGS)" ]; then \
		$(call center_banner, Starting OCP cluster Installation); \
		ansible-playbook -i hosts --tags "1_ocp_install,3_ebs" $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/install.yml; \
	else \
		$(call center_banner, Skipping OCP install because TAGS is set: $(TAGS)); \
	fi; \
	\
	$(call center_banner, Starting Veritas Stack Operation)
	
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_ARGS) $(EXTRA_VARS) playbooks/veritas/veritas.yml
