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
        - src: ansible-deploy.cfg.j2
          dest: ansible-deploy.cfg
          mode: "0644"
        - src: robokitty-deploy-logrotate.j2
          dest: robokitty-deploy-logrotate
          mode: "0644"
        - src: robokitty-check-ansible-requirements.py.j2
          dest: robokitty-check-ansible-requirements
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
python3 -m py_compile "$tmpdir/robokitty-check-ansible-requirements"

grep -Fq 'Defaults:agent-actions env_reset' "$tmpdir/sudoers-robokitty-devbox" || {
  echo "error: Actions runner sudo policy must reset caller environment" >&2
  exit 1
}

grep -Fq 'Defaults:agent-actions env_delete += "BASH_ENV ENV CDPATH GLOBIGNORE SHELLOPTS"' \
  "$tmpdir/sudoers-robokitty-devbox" || {
    echo "error: Actions runner sudo policy must delete shell startup environment" >&2
    exit 1
  }

grep -Fq 'Defaults:agent-actions secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
  "$tmpdir/sudoers-robokitty-devbox" || {
    echo "error: Actions runner sudo policy must pin command search path" >&2
    exit 1
  }

grep -Fq 'agent-actions ALL=(root) NOPASSWD: /usr/local/bin/robokitty-deploy-infra' \
  "$tmpdir/sudoers-robokitty-devbox" || {
    echo "error: Actions runner sudo rule must be fixed to deploy wrapper" >&2
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

grep -Fxq 'PrivateTmp=true' "$tmpdir/actions-runner.service" || {
  echo "error: Actions runner service must use a private tmp directory" >&2
  exit 1
}

grep -Fxq 'InaccessiblePaths=/home/agent /home/agent-bridge /home/agent-git' \
  "$tmpdir/actions-runner.service" || {
  echo "error: Actions runner service must hide other agent homes" >&2
  exit 1
}

grep -Fq 'only $actions_user may invoke this wrapper through sudo' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must reject unexpected sudo callers" >&2
    exit 1
  }

grep -Fxq '#!/bin/bash' "$tmpdir/robokitty-deploy-infra" || {
  echo "error: deploy wrapper must use an absolute shell interpreter" >&2
  exit 1
}

grep -Fq 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must set a fixed PATH before privileged work" >&2
    exit 1
  }

grep -Fq '[ "$#" -eq 1 ]' "$tmpdir/robokitty-deploy-infra" || {
  echo "error: deploy wrapper must require exactly one triggering SHA argument" >&2
  exit 1
}

grep -Fq 'expected commit SHA must be 40 lowercase hex characters' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must validate the triggering SHA format" >&2
    exit 1
  }

grep -Fq 'origin/$branch moved since workflow trigger' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must refuse branch-head drift from triggering SHA" >&2
    exit 1
  }

grep -Fq 'ANSIBLE_CONFIG="$ansible_config"' "$tmpdir/robokitty-deploy-infra" || {
  echo "error: deploy wrapper must pin ANSIBLE_CONFIG" >&2
  exit 1
}

grep -Fq 'require_stat "$deploy_home" "700 $deploy_user $deploy_user"' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must validate deploy home ownership" >&2
    exit 1
  }

grep -Fq 'require_stat "$ansible_home/collections" "755 root root"' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must validate Ansible collection cache ownership" >&2
    exit 1
  }

grep -Fq 'require_stat "$checkout" "700 $deploy_user $deploy_user"' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must validate checkout ownership after clone" >&2
    exit 1
  }

grep -Fq 'deploy Ansible config ownership or mode is unsafe' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must validate deploy Ansible config ownership" >&2
    exit 1
  }

if ! grep -Fq 'ansible_env=(' "$tmpdir/robokitty-deploy-infra" ||
   ! grep -Fq '  -i' "$tmpdir/robokitty-deploy-infra"; then
  echo "error: deploy wrapper must run Ansible under env -i" >&2
  exit 1
fi

grep -Fq 'cd "$checkout"' "$tmpdir/robokitty-deploy-infra" || {
  echo "error: deploy wrapper must change to the clean checkout before Ansible" >&2
  exit 1
}

if grep -Fq -- '--force' "$tmpdir/robokitty-deploy-infra"; then
  echo "error: deploy wrapper must not force-refresh Galaxy collections every deploy" >&2
  exit 1
fi

grep -Fq '/usr/local/bin/robokitty-check-ansible-requirements "$checkout/requirements.yml"' \
  "$tmpdir/robokitty-deploy-infra" || {
    echo "error: deploy wrapper must enforce Ansible requirements policy at deploy time" >&2
    exit 1
  }

grep -Fq 'collections_path = /var/cache/robokitty-devbox/ansible/collections' \
  "$tmpdir/ansible-deploy.cfg" || {
    echo "error: deploy Ansible config must pin collection path" >&2
    exit 1
  }

grep -Fq 'create 0600 root root' "$tmpdir/robokitty-deploy-logrotate" || {
  echo "error: deploy logrotate config must preserve root-only logs" >&2
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

grep -Fq 'deploy directories match expected ownership' "$tmpdir/robokitty-security-check" || {
  echo "error: security check must validate deploy directory ownership" >&2
  exit 1
}

grep -Fq -- '- --disableupdate' "$repo_root/roles/robokitty_devbox/tasks/deploy_runner.yml" || {
  echo "error: Actions runner registration must disable runner auto-update" >&2
  exit 1
}

grep -Fq 'github-runner-removed' "$repo_root/roles/robokitty_devbox/tasks/deploy_runner.yml" || {
  echo "error: disable cleanup must require GitHub runner removal acknowledgement" >&2
  exit 1
}

grep -Fq "robokitty_deploy_runner_repo_visibility_ack in ['private-repo', 'public-repo-risk-accepted']" \
  "$repo_root/roles/robokitty_devbox/tasks/00_contract.yml" || {
    echo "error: deploy runner contract must require repo visibility acknowledgement" >&2
    exit 1
  }

grep -Fq 'vault_robokitty_deploy_runner_repo_visibility_ack: private-repo' \
  "$repo_root/docs/self-hosted-deploy-runner.md" || {
    echo "error: deploy runner docs must prefer private repo enablement" >&2
    exit 1
  }

grep -Fq 'robokitty-deploy-infra "$GITHUB_SHA"' \
  "$repo_root/docs/self-hosted-deploy-runner.md" || {
    echo "error: deploy workflow docs must pass GITHUB_SHA to the wrapper" >&2
    exit 1
  }

if grep -Eq 'uses:[[:space:]]+actions/checkout@v[0-9]+' \
  "$repo_root/docs/self-hosted-deploy-runner.md"; then
  echo "error: deploy workflow docs must not tag-pin actions/checkout" >&2
  exit 1
fi

echo "OK: deploy runner templates keep Actions execution separate from deploy secrets"
