#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/requirements.toml"
playbook="$tmpdir/render.yml"

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

cat >"$playbook" <<YAML
---
- name: Render Codex requirements template for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render requirements
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/codex-requirements.toml.j2"
        dest: "$rendered"
        mode: "0600"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  >/dev/null

UV_BIN="${UV:-uv}"
UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python - "$rendered" <<'PY'
from __future__ import annotations

import sys
import tomllib
from pathlib import Path

path = Path(sys.argv[1])
data = tomllib.loads(path.read_text())
rules = data.get("rules", {}).get("prefix_rules", [])


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


if not isinstance(rules, list):
    fail("rules.prefix_rules must be a list")

for index, rule in enumerate(rules):
    pattern = rule.get("pattern")
    if not isinstance(pattern, list) or not pattern:
        fail(f"rule {index} pattern must be a non-empty list")
    if not all(isinstance(item, dict) for item in pattern):
        fail(f"rule {index} pattern entries must be TOML objects")
    if rule.get("decision") == "allow":
        fail("requirements.toml must not contain allow rules")

print(f"OK: {path} is valid TOML and contains no allow rules")
PY
