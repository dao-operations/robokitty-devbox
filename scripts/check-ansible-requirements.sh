#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
requirements="$repo_root/requirements.yml"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/robokitty-check-ansible-requirements"
playbook="$tmpdir/render.yml"

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

cat >"$playbook" <<YAML
---
- name: Render Ansible requirements policy checker
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render checker
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/robokitty-check-ansible-requirements.py.j2"
        dest: "$rendered"
        mode: "0755"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" >/dev/null

UV_BIN="${UV:-uv}"
UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python "$rendered" "$requirements"

bad_range="$tmpdir/bad-range.yml"
cat >"$bad_range" <<'YAML'
---
collections:
  - name: community.general
    version: ">=9.0.0"
YAML
if UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
  UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python "$rendered" "$bad_range" >/dev/null 2>&1; then
  echo "error: requirements checker accepted a ranged collection version" >&2
  exit 1
fi

bad_source="$tmpdir/bad-source.yml"
cat >"$bad_source" <<'YAML'
---
collections:
  - name: community.general
    version: "13.1.0"
    source: https://example.invalid/galaxy
YAML
if UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
  UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python "$rendered" "$bad_source" >/dev/null 2>&1; then
  echo "error: requirements checker accepted a non-allowlisted source" >&2
  exit 1
fi

bad_collection="$tmpdir/bad-collection.yml"
cat >"$bad_collection" <<'YAML'
---
collections:
  - name: example.untrusted
    version: "1.2.3"
YAML
if UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
  UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python "$rendered" "$bad_collection" >/dev/null 2>&1; then
  echo "error: requirements checker accepted a non-allowlisted collection" >&2
  exit 1
fi

echo "OK: Ansible collection requirements are exact-pinned and allowlisted"
