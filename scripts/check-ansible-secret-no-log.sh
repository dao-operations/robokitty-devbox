#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UV_BIN="${UV:-uv}"
UV_CACHE_DIR="${UV_CACHE_DIR:-$repo_root/.uv-cache}" \
UV_PYTHON_PREFERENCE=only-system \
  "$UV_BIN" run python - "$repo_root/roles/robokitty_devbox/tasks" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

SECRET_NAME_RE = ("token", "password", "private key", "signing private")


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


root = Path(sys.argv[1])
repo_root = root.parent.parent.parent
for path in sorted(root.glob("*.yml")):
    data = yaml.safe_load(path.read_text()) or []
    if not isinstance(data, list):
        continue
    for index, task in enumerate(data, start=1):
        if not isinstance(task, dict):
            continue
        name = str(task.get("name", "")).lower()
        if not any(marker in name for marker in SECRET_NAME_RE):
            continue
        if task.get("no_log") is True:
            continue
        fail(f"{path.relative_to(repo_root)} task {index} handles secret-like data without no_log: {task.get('name')}")

print("OK: obvious secret-handling Ansible tasks use no_log")
PY
