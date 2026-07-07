#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label missing: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$label unexpectedly present: $needle"
  fi
}

export ANSIBLE_HOME="${ANSIBLE_HOME:-$repo_root/.ansible}"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-$ANSIBLE_HOME/tmp/local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/robokitty-ansible-remote}"
export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-$ANSIBLE_HOME/collections}"
export ANSIBLE_STDOUT_CALLBACK=default

mkdir -p "$ANSIBLE_HOME" "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP" "$ANSIBLE_COLLECTIONS_PATH"

bindir="$tmpdir/bin"
config_dir="$tmpdir/config"
root_dir="$tmpdir/root"
workdir="$root_dir/work"
infra_dir="$root_dir/infra"
mkdir -p "$bindir" "$config_dir" "$workdir" "$infra_dir"

playbook="$tmpdir/render.yml"
cat >"$playbook" <<YAML
---
- name: Render bootstrap task helper for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render bootstrap task helper
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/robokitty-bootstrap-task.sh.j2"
        dest: "$bindir/robokitty-bootstrap-task"
        mode: "0755"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e "robokitty_config_dir=$config_dir" \
  -e "robokitty_repo_config_file=$config_dir/repos.json" \
  >/dev/null

helper="$bindir/robokitty-bootstrap-task"
bash -n "$helper"

cat >"$config_dir/repos.json" <<JSON
{
  "root": "$root_dir",
  "workdir": "$workdir",
  "infra_dir": "$infra_dir",
  "allowed_branch_prefix": "agent/",
  "repos": {
    "app": {
      "alias": "app",
      "owner": "example-org",
      "repo": "example-app",
      "full_name": "example-org/example-app",
      "path": "$workdir/example-app",
      "default_branch": "main",
      "allowed_base_branches": ["main"],
      "allow_push": true,
      "allow_pr_create": true
    },
    "robokitty-infra": {
      "alias": "robokitty-infra",
      "owner": "dao-operations",
      "repo": "robokitty-devbox",
      "full_name": "dao-operations/robokitty-devbox",
      "path": "$infra_dir",
      "default_branch": "master",
      "allowed_base_branches": ["master"],
      "allow_push": true,
      "allow_pr_create": true
    }
  }
}
JSON

default_output="$("$helper")"
assert_contains "$default_output" "Repo:        app (example-org/example-app)" "default repo"
assert_contains "$default_output" "Branch:      agent/bootstrap-test" "default branch"
assert_contains "$default_output" "Worktree:    $workdir/example-app.agent.bootstrap-test" "default worktree"
assert_contains "$default_output" "/app" "telegram route"
assert_contains "$default_output" "robokitty-new-worktree app agent/bootstrap-test main" "worktree command"
assert_contains "$default_output" "$workdir/example-app.agent.bootstrap-test" "worktree path"
assert_contains "$default_output" "githubctl status --repo app --format json" "githubctl status"
assert_contains "$default_output" "This docs-only bootstrap smoke does not require make ci." "docs-only validation guidance"
assert_contains "$default_output" "run make ci" "infra validation guidance"
assert_contains "$default_output" "If the worktree helper fails, stop and report the failure." "no fallback guidance"
assert_contains "$default_output" "Do not create a" "no fallback guidance"
assert_contains "$default_output" "fallback clone" "no fallback guidance"
assert_contains "$default_output" "If any required command fails" "failure handling"
assert_not_contains "$default_output" "@agent/bootstrap-test" "Takopi branch suffix"

infra_output="$("$helper" robokitty-infra agent/bootstrap-smoke)"
assert_contains "$infra_output" "Repo:        robokitty-infra (dao-operations/robokitty-devbox)" "infra repo"
assert_contains "$infra_output" "Base:        master" "infra base"
assert_contains "$infra_output" "Branch:      agent/bootstrap-smoke" "infra branch"
assert_contains "$infra_output" "Worktree:    $workdir/infra.agent.bootstrap-smoke" "infra worktree"
assert_contains "$infra_output" "robokitty-new-worktree robokitty-infra agent/bootstrap-smoke master" "infra worktree command"
assert_contains "$infra_output" "githubctl status --repo robokitty-infra --format json" "infra githubctl status"

if "$helper" app main >/dev/null 2>&1; then
  fail "unsafe branch without agent/ prefix was accepted"
fi

echo "OK: bootstrap task helper renders concrete Telegram prompts"
