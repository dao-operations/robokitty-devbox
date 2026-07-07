#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

playbook="$tmpdir/render.yml"
exchange_path="/var/lib/robokitty-devbox/githubctl-exchange"
repo_config_path="/var/lib/robokitty-devbox/repos.json"
worktree_source_path="/var/lib/robokitty-devbox/worktree-sources"
broker_handoff_group="agent"

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

cat >"$playbook" <<YAML
---
- name: Render GitHub broker templates for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render broker Python templates
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/{{ item }}"
        dest: "$tmpdir/{{ item | regex_replace('[.]j2$', '') }}"
        mode: "0600"
      loop:
        - githubctl.py.j2
        - githubctl-prep.py.j2
        - githubctl-brokerd.py.j2
        - codex-config.toml.j2
        - takopi.service.j2
        - githubctl-broker.service.j2
        - robokitty-cloudflared.service.j2
        - robokitty-security-check.sh.j2
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e "robokitty_enable_proc_hardening=true" \
  >/dev/null

UV_BIN="${UV:-uv}"
UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python -m py_compile \
  "$tmpdir/githubctl.py" \
  "$tmpdir/githubctl-prep.py" \
  "$tmpdir/githubctl-brokerd.py"

if grep -F "/srv/robokitty-devbox/work/.githubctl-exchange" \
  "$tmpdir/githubctl.py" \
  "$tmpdir/githubctl-prep.py" \
  "$tmpdir/codex-config.toml" \
  "$tmpdir/takopi.service" \
  "$tmpdir/githubctl-broker.service" >/dev/null; then
  echo "error: GitHub broker exchange path must not live under the worktree parent" >&2
  exit 1
fi

grep -F "EXCHANGE_DIR = Path('$exchange_path')" \
  "$tmpdir/githubctl-prep.py" >/dev/null || {
    echo "error: githubctl-prep rendered an unexpected exchange path" >&2
    exit 1
  }

grep -F "PREPARED_FILE_PARENT = Path('$exchange_path')" \
  "$tmpdir/githubctl.py" >/dev/null || {
    echo "error: githubctl rendered an unexpected prepared file parent" >&2
    exit 1
  }

grep -F "\"$exchange_path\" = \"write\"" "$tmpdir/codex-config.toml" >/dev/null || {
  echo "error: Codex config must grant exact write access to broker exchange path" >&2
  exit 1
}

grep -F "\"$worktree_source_path\" = \"write\"" "$tmpdir/codex-config.toml" >/dev/null || {
  echo "error: Codex config must grant exact write access to worktree source path" >&2
  exit 1
}

grep -F "\"$repo_config_path\" = \"read\"" "$tmpdir/codex-config.toml" >/dev/null || {
  echo "error: Codex config must grant exact read access to repo routing config" >&2
  exit 1
}

grep -F "CONFIG = Path('$repo_config_path')" "$tmpdir/githubctl.py" >/dev/null || {
  echo "error: githubctl rendered an unexpected repo routing config path" >&2
  exit 1
}

grep -F "ReadWritePaths=/home/agent-bridge /srv/robokitty-devbox/work $exchange_path $worktree_source_path" \
  "$tmpdir/takopi.service" >/dev/null || {
    echo "error: Takopi unit must grant exact write access to broker exchange and worktree source paths" >&2
    exit 1
  }

grep -F "ReadWritePaths=/home/agent-git /run/robokitty-devbox $exchange_path /tmp" \
  "$tmpdir/githubctl-broker.service" >/dev/null || {
    echo "error: GitHub broker unit must grant exact write access to broker exchange path" >&2
    exit 1
  }

for service_template in takopi.service githubctl-broker.service robokitty-cloudflared.service; do
  grep -Fx "ProtectProc=invisible" "$tmpdir/$service_template" >/dev/null || {
    echo "error: $service_template must hide cross-user process lists when proc hardening is enabled" >&2
    exit 1
  }
done

grep -F "Group=$broker_handoff_group" "$tmpdir/githubctl-broker.service" >/dev/null || {
  echo "error: GitHub broker unit must use the runner primary group for handoff" >&2
  exit 1
}

grep -F "HANDOFF_GROUP = '$broker_handoff_group'" "$tmpdir/githubctl-prep.py" >/dev/null || {
  echo "error: githubctl-prep must use the runner primary group for handoff" >&2
  exit 1
}

grep -F "runner can write githubctl broker exchange directory" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must validate runner access to broker exchange path" >&2
    exit 1
  }

grep -F "state directory ownership or mode is unsafe for broker handoff" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must validate state directory handoff traversal" >&2
    exit 1
  }

grep -F "must not keep agent-work supplementary membership" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must reject stale broker user work-group membership" >&2
    exit 1
  }

grep -F "managed service units use ProtectProc=invisible" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must validate managed service process visibility hardening" >&2
    exit 1
  }

grep -F "runner can write worktree source directory" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must validate runner access to worktree source path" >&2
    exit 1
  }

grep -F "legacy githubctl broker exchange directory remains under workdir" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must reject the legacy in-workdir exchange path" >&2
    exit 1
  }

grep -F "legacy repo routing config remains under denied etc path" \
  "$tmpdir/robokitty-security-check.sh" >/dev/null || {
    echo "error: security check must reject the legacy etc repo routing config" >&2
    exit 1
  }

fixture="$tmpdir/prep-fixture"
mkdir -p "$fixture" "$tmpdir/prep-exchange"
git -C "$fixture" init -q
git -C "$fixture" checkout -q -B master
git -C "$fixture" config user.name "Robokitty Template Test"
git -C "$fixture" config user.email "robokitty-template-test@example.invalid"
git -C "$fixture" config commit.gpgsign false
printf "base\n" >"$fixture/README.md"
git -C "$fixture" add README.md
git -C "$fixture" commit -q -m "base"
git -C "$fixture" checkout -q -b agent/body-file-smoke
printf "change\n" >>"$fixture/README.md"
git -C "$fixture" commit -q -am "change"
printf "Bootstrap smoke body\n" >"$fixture/PR_BODY.md"

UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python - "$tmpdir/githubctl-prep.py" "$fixture" "$tmpdir/prep-exchange" <<'PY'
from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

module_path = Path(sys.argv[1])
worktree = Path(sys.argv[2]).resolve()
exchange_dir = Path(sys.argv[3]).resolve()

spec = importlib.util.spec_from_file_location("githubctl_prep_rendered", module_path)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def make_exchange_dir() -> Path:
    path = exchange_dir / "robokitty-submit.test"
    path.mkdir(parents=True, exist_ok=True)
    return path

def write_exchange_file(path: Path, data: bytes) -> None:
    path.write_bytes(data)

module.make_exchange_dir = make_exchange_dir
module.write_exchange_file = write_exchange_file

args = argparse.Namespace(
    repo="robokitty-infra",
    worktree=str(worktree),
    branch="agent/body-file-smoke",
    base="master",
    title="Agent: bootstrap test",
    body_file="PR_BODY.md",
    draft=True,
    format="json",
)

broker_args = module.prepare_submit(args)
body_path = Path(broker_args[broker_args.index("--body-file") + 1])
patch_path = Path(broker_args[broker_args.index("--patch-file") + 1])
assert body_path.read_text() == "Bootstrap smoke body\n"
assert b"README.md" in patch_path.read_bytes()

(worktree / "UNCOMMITTED.md").write_text("dirty\n")
try:
    module.prepare_submit(args)
except ValueError as ex:
    assert "uncommitted changes other than body-file" in str(ex)
else:
    raise AssertionError("submit prep accepted unrelated uncommitted changes")
PY

echo "OK: rendered GitHub broker templates compile and keep exchange state outside workdir"
