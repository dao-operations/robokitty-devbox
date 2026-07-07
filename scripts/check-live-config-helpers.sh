#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [ "$expected" = "$actual" ] || fail "$label: expected $expected, got $actual"
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
live_dir="$root_dir/live"
infra_dir="$root_dir/infra"
source_dir="$tmpdir/state/worktree-sources"
mkdir -p "$bindir" "$config_dir" "$workdir" "$live_dir" "$source_dir"

playbook="$tmpdir/render.yml"
cat >"$playbook" <<YAML
---
- name: Render live config helpers for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render helper scripts
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/{{ item.src }}"
        dest: "$bindir/{{ item.dest }}"
        mode: "0755"
      loop:
        - src: robokitty-new-worktree.sh.j2
          dest: robokitty-new-worktree
        - src: robokitty-drift-report.sh.j2
          dest: robokitty-drift-report
        - src: robokitty-sync-live-to-infra.sh.j2
          dest: robokitty-sync-live-to-infra
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e "robokitty_config_dir=$config_dir" \
  -e "robokitty_live_dir=$live_dir" \
  -e "robokitty_infra_dir=$infra_dir" \
  -e "robokitty_repo_config_file=$config_dir/repos.json" \
  -e "robokitty_worktree_source_dir=$source_dir" \
  >/dev/null

new="$bindir/robokitty-new-worktree"
drift="$bindir/robokitty-drift-report"
sync="$bindir/robokitty-sync-live-to-infra"
bash -n "$new"
bash -n "$drift"
bash -n "$sync"

git init -b main "$infra_dir" >/dev/null
git -C "$infra_dir" config user.name "Robokitty Test"
git -C "$infra_dir" config user.email "robokitty-test@example.invalid"
git -C "$infra_dir" config commit.gpgsign false
mkdir -p "$infra_dir/codex/skills/devbox-maintenance"
printf '# Infra guidance\n' >"$infra_dir/codex/AGENTS.md"
printf '%s\n' '---' 'name: devbox-maintenance' '---' '' '# Skill' \
  >"$infra_dir/codex/skills/devbox-maintenance/SKILL.md"
git -C "$infra_dir" add codex
git -C "$infra_dir" commit -m "chore: seed guidance" >/dev/null
git init --bare -b main "$tmpdir/infra-origin.git" >/dev/null
git -C "$infra_dir" remote add origin "$tmpdir/infra-origin.git"
git -C "$infra_dir" push -u origin main >/dev/null

mkdir -p "$live_dir/codex/skills/devbox-maintenance"
mkdir -p "$live_dir/codex/skills/.system/generated-skill"
printf '# Live guidance\n' >"$live_dir/codex/AGENTS.md"
printf '%s\n' '---' 'name: devbox-maintenance' '---' '' '# Skill live' \
  >"$live_dir/codex/skills/devbox-maintenance/SKILL.md"
printf 'ignored generated cache\n' >"$live_dir/codex/skills/.system/generated-skill/secret.env"

cat >"$config_dir/repos.json" <<JSON
{
  "root": "$root_dir",
  "workdir": "$workdir",
  "infra_dir": "$infra_dir",
  "allowed_branch_prefix": "agent/",
  "repos": {
    "robokitty-infra": {
      "alias": "robokitty-infra",
      "path": "$infra_dir",
      "default_branch": "main",
      "allowed_base_branches": ["main"]
    }
  }
}
JSON

if "$drift" >/dev/null; then
  fail "drift report returned clean status for changed live guidance"
fi

sync_output="$(PATH="$bindir:$PATH" "$sync" agent/sync-live-guidance-test main)"
sync_wt="${sync_output%%$'\n'*}"
assert_eq "$workdir/infra.agent.sync-live-guidance-test" "$sync_wt" "sync worktree path"
assert_eq "agent/sync-live-guidance-test" "$(git -C "$sync_wt" branch --show-current)" "sync branch"

diff_output="$(git -C "$sync_wt" diff -- codex)"
[[ "$diff_output" == *"# Live guidance"* ]] || fail "synced worktree does not contain live AGENTS.md drift"
[[ "$diff_output" == *"# Skill live"* ]] || fail "synced worktree does not contain live skill drift"
[ ! -e "$sync_wt/codex/skills/.system" ] || fail "Codex system skill cache was synced"
[ -z "$(git -C "$infra_dir" status --porcelain)" ] || fail "canonical infra checkout became dirty"

printf 'not allowed\n' >"$live_dir/codex/skills/devbox-maintenance/secret.env"
if PATH="$bindir:$PATH" "$sync" agent/sync-live-guidance-bad main >/dev/null 2>&1; then
  fail "sync accepted secret-like live guidance file"
fi

echo "OK: live drift helpers report and sync guidance into managed worktrees"
