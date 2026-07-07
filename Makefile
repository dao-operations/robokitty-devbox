SHELL := /bin/bash

UV ?= uv
UV_CACHE_DIR ?= $(CURDIR)/.uv-cache
ANSIBLE_HOME ?= $(CURDIR)/.ansible
ANSIBLE_LOCAL_TEMP ?= $(ANSIBLE_HOME)/tmp/local
ANSIBLE_REMOTE_TEMP ?= /tmp/robokitty-ansible-remote
ANSIBLE_COLLECTIONS_PATH ?= $(ANSIBLE_HOME)/collections
ANSIBLE_GALAXY ?= ansible-galaxy
ANSIBLE_LINT ?= ansible-lint
ANSIBLE_PLAYBOOK ?= ansible-playbook
YAMLLINT ?= yamllint
INVENTORY ?= inventories/example/hosts.yml
PLAYBOOK ?= playbooks/robokitty_devbox.yml

ANSIBLE_ENV := ANSIBLE_HOME=$(ANSIBLE_HOME) ANSIBLE_LOCAL_TEMP=$(ANSIBLE_LOCAL_TEMP) ANSIBLE_REMOTE_TEMP=$(ANSIBLE_REMOTE_TEMP) ANSIBLE_COLLECTIONS_PATH=$(ANSIBLE_COLLECTIONS_PATH)

.PHONY: help prepare-ansible install-dev install-collections lint-yaml lint-ansible syntax codex-requirements-check sudoers-check github-broker-check worktree-helpers-check devbox-run-check live-config-helpers-check bootstrap-task-check cloud-init-check ci

help:
	@echo "Targets: install-dev lint-yaml lint-ansible syntax worktree-helpers-check devbox-run-check live-config-helpers-check bootstrap-task-check cloud-init-check ci"
	@echo "Variables: INVENTORY=$(INVENTORY) PLAYBOOK=$(PLAYBOOK)"

prepare-ansible:
	@mkdir -p "$(ANSIBLE_HOME)" "$(ANSIBLE_LOCAL_TEMP)" "$(ANSIBLE_REMOTE_TEMP)" "$(ANSIBLE_COLLECTIONS_PATH)"

install-dev:
	UV_CACHE_DIR=$(UV_CACHE_DIR) $(UV) tool install --force \
		--with-requirements requirements-dev.txt \
		--with-executables-from ansible-lint \
		--with-executables-from yamllint \
		ansible-core
	$(MAKE) install-collections

install-collections: prepare-ansible
	$(ANSIBLE_ENV) $(ANSIBLE_GALAXY) collection install --force -r requirements.yml -p "$(ANSIBLE_COLLECTIONS_PATH)"

lint-yaml: prepare-ansible
	@command -v "$(YAMLLINT)" >/dev/null || { echo "error: $(YAMLLINT) not found; run 'make install-dev'"; exit 127; }
	$(YAMLLINT) .

lint-ansible: prepare-ansible
	@command -v "$(ANSIBLE_LINT)" >/dev/null || { echo "error: $(ANSIBLE_LINT) not found; run 'make install-dev'"; exit 127; }
	$(ANSIBLE_ENV) $(ANSIBLE_LINT) --strict .

syntax: prepare-ansible
	@command -v "$(ANSIBLE_PLAYBOOK)" >/dev/null || { echo "error: $(ANSIBLE_PLAYBOOK) not found; run 'make install-dev'"; exit 127; }
	$(ANSIBLE_ENV) $(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" --syntax-check

codex-requirements-check: prepare-ansible
	@command -v "$(UV)" >/dev/null || { echo "error: $(UV) not found; run 'make install-dev'"; exit 127; }
	$(ANSIBLE_ENV) UV="$(UV)" scripts/check-codex-requirements-template.sh

sudoers-check: prepare-ansible
	@command -v visudo >/dev/null || { echo "error: visudo not found"; exit 127; }
	$(ANSIBLE_ENV) scripts/check-sudoers-template.sh

github-broker-check: prepare-ansible
	@command -v "$(UV)" >/dev/null || { echo "error: $(UV) not found; run 'make install-dev'"; exit 127; }
	$(ANSIBLE_ENV) UV="$(UV)" scripts/check-github-broker-templates.sh

worktree-helpers-check: prepare-ansible
	$(ANSIBLE_ENV) scripts/check-worktree-helpers.sh

devbox-run-check: prepare-ansible
	$(ANSIBLE_ENV) scripts/check-devbox-run-template.sh

live-config-helpers-check: prepare-ansible
	$(ANSIBLE_ENV) scripts/check-live-config-helpers.sh

bootstrap-task-check: prepare-ansible
	$(ANSIBLE_ENV) scripts/check-bootstrap-task-template.sh

cloud-init-check:
	scripts/render-cloud-init.sh --check-template

ci: lint-yaml lint-ansible syntax codex-requirements-check sudoers-check github-broker-check worktree-helpers-check devbox-run-check live-config-helpers-check bootstrap-task-check cloud-init-check
