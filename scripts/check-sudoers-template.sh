#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/sudoers-robokitty-devbox"
wrapper="$tmpdir/codex-wrapper"
playbook="$tmpdir/render.yml"

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

cat >"$playbook" <<YAML
---
- name: Render sudoers template for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render sudoers
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/sudoers-robokitty-devbox.j2"
        dest: "$rendered"
        mode: "0440"
    - name: Render Codex wrapper
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/codex-wrapper.sh.j2"
        dest: "$wrapper"
        mode: "0755"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  >/dev/null

visudo -cf "$rendered" >/dev/null
bash -n "$wrapper"
grep -Fq "ALL=(agent)" "$rendered" || \
  { echo "error: sudoers does not constrain bridge to agent" >&2; exit 1; }
if grep -Fq "ALL=(agent:agent-work)" "$rendered"; then
  echo "error: sudoers must not override agent primary group" >&2
  exit 1
fi
grep -Fq -- "-u agent --" "$wrapper" || \
  { echo "error: Codex wrapper does not run as agent with default primary group" >&2; exit 1; }
if grep -Fq -- "-g agent-work" "$wrapper"; then
  echo "error: Codex wrapper must not override agent primary group" >&2
  exit 1
fi
if grep -Fq "ALL=(agent-git)" "$rendered"; then
  echo "error: sudoers must not let agent sudo to agent-git" >&2
  exit 1
fi

echo "OK: sudoers and Codex wrapper use agent default primary group and no agent-git sudo handoff"
