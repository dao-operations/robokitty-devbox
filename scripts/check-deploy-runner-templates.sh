#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

playbook="$tmpdir/render.yml"

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

cat >"$playbook" <<YAML
---
- name: Render deploy runner templates for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  vars:
    robokitty_deploy_runner_enabled: true
    robokitty_actions_runner_github_url: https://github.com/dao-operations/robokitty-devbox
    robokitty_deploy_runner_github_url: https://github.com/dao-operations/robokitty-devbox
    robokitty_actions_runner_package_url: https://github.com/actions/runner/releases/download/v2.999.0/actions-runner-linux-x64-2.999.0.tar.gz
    robokitty_actions_runner_package_checksum: sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    robokitty_actions_runner_registration_token: dummy-token
    robokitty_deploy_runner_secret_custody_ack: host-resident-vault-password
    robokitty_deploy_runner_vault_password: dummy-vault-password
    robokitty_infra_repo:
      alias: robokitty-infra
      owner: dao-operations
      repo: robokitty-devbox
      default_branch: master
      clone_url: https://github.com/dao-operations/robokitty-devbox.git
      path: /srv/robokitty-devbox/infra
      allowed_base_branches:
        - master
  tasks:
    - name: Render deploy runner templates
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/{{ item.src }}"
        dest: "$tmpdir/{{ item.dest }}"
        mode: "{{ item.mode }}"
      loop:
        - src: sudoers-robokitty-devbox.j2
          dest: sudoers-robokitty-devbox
          mode: "0440"
        - src: robokitty-deploy-infra.sh.j2
          dest: robokitty-deploy-infra
          mode: "0755"
        - src: actions-runner.service.j2
          dest: actions-runner.service
          mode: "0644"
        - src: codex-config.toml.j2
          dest: codex-config.toml
          mode: "0644"
        - src: robokitty-security-check.sh.j2
          dest: robokitty-security-check
          mode: "0755"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e robokitty_deploy_runner_enabled=true \
  -e robokitty_actions_runner_github_url=https://github.com/dao-operations/robokitty-devbox \
  -e robokitty_deploy_runner_github_url=https://github.com/dao-operations/robokitty-devbox \
  >/dev/null

visudo -cf "$tmpdir/sudoers-robokitty-devbox" >/dev/null
bash -n "$tmpdir/robokitty-deploy-infra"
bash -n "$tmpdir/robokitty-security-check"

grep -Fq 'agent-actions ALL=(root) NOPASSWD: /usr/local/bin/robokitty-deploy-infra ""' \
  "$tmpdir/sudoers-robokitty-devbox" || {
    echo "error: Actions runner sudo rule must be fixed to deploy wrapper with no args" >&2
    exit 1
  }

if grep -Fq 'agent ALL=(root)' "$tmpdir/sudoers-robokitty-devbox" ||
   grep -Fq 'agent ALL=(agent-deploy)' "$tmpdir/sudoers-robokitty-devbox"; then
  echo "error: Codex runner must not get deploy sudo access" >&2
  exit 1
fi

grep -Fxq 'User=agent-actions' "$tmpdir/actions-runner.service" || {
  echo "error: Actions runner service must run as agent-actions" >&2
  exit 1
}

grep -Fxq 'NoNewPrivileges=false' "$tmpdir/actions-runner.service" || {
  echo "error: Actions runner service must permit the narrow sudo deploy handoff" >&2
  exit 1
}

grep -Fq 'only $actions_user may invoke this wrapper through sudo' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must reject unexpected sudo callers" >&2
    exit 1
  }

grep -Fq '[ "$#" -eq 0 ]' "$tmpdir/robokitty-deploy-infra" || {
  echo "error: deploy wrapper must reject arguments" >&2
  exit 1
}

if grep -Fq 'GITHUB_WORKSPACE' "$tmpdir/robokitty-deploy-infra"; then
  echo "error: deploy wrapper must not deploy from GitHub workspace" >&2
  exit 1
fi

grep -Fq '"/home/agent-actions" = "deny"' "$tmpdir/codex-config.toml" || {
  echo "error: Codex config must deny Actions runner home" >&2
  exit 1
}

grep -Fq '"/home/agent-deploy" = "deny"' "$tmpdir/codex-config.toml" || {
  echo "error: Codex config must deny deploy runner home" >&2
  exit 1
}

grep -Fq "Actions runner cannot read deploy vault password" \
  "$tmpdir/robokitty-security-check" || {
    echo "error: security check must validate Actions runner cannot read vault password" >&2
    exit 1
  }

grep -Fq 'actions_nopasswd_count' "$tmpdir/robokitty-security-check" || {
  echo "error: security check must count Actions runner sudo capabilities" >&2
  exit 1
}

echo "OK: deploy runner templates keep Actions execution separate from deploy secrets"
