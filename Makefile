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

.PHONY: help prepare-ansible install-dev install-collections lint-yaml lint-ansible syntax ci

help:
	@echo "Targets: install-dev lint-yaml lint-ansible syntax ci"
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

ci: lint-yaml lint-ansible syntax
