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
infra_dir="$root_dir/infra"
source_dir="$tmpdir/state/worktree-sources"
mkdir -p "$bindir" "$config_dir" "$workdir" "$source_dir"

playbook="$tmpdir/render.yml"
cat >"$playbook" <<YAML
---
- name: Render worktree helpers for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  vars:
    robokitty_config_dir: "$config_dir"
  tasks:
    - name: Render worktree helper scripts
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/{{ item.src }}"
        dest: "$bindir/{{ item.dest }}"
        mode: "0755"
      loop:
        - src: robokitty-new-worktree.sh.j2
          dest: robokitty-new-worktree
        - src: robokitty-delete-worktree.sh.j2
          dest: robokitty-delete-worktree
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e "robokitty_config_dir=$config_dir" \
  -e "robokitty_repo_config_file=$config_dir/repos.json" \
  -e "robokitty_worktree_source_dir=$source_dir" >/dev/null

new="$bindir/robokitty-new-worktree"
delete="$bindir/robokitty-delete-worktree"
bash -n "$new"
bash -n "$delete"

git_common_dir() {
  local repo="$1"
  local path
  path="$(git -C "$repo" rev-parse --git-common-dir)"
  case "$path" in
    /*) ;;
    *) path="$repo/$path" ;;
  esac
  realpath "$path"
}

init_repo() {
  local repo="$1"
  local remote="$2"
  mkdir -p "$repo"
  git init -b main "$repo" >/dev/null
  git -C "$repo" config user.name "Robokitty Test"
  git -C "$repo" config user.email "robokitty-test@example.invalid"
  git -C "$repo" config commit.gpgsign false
  printf '# %s\n' "$(basename "$repo")" >"$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m "chore: seed test repo" >/dev/null
  git init --bare -b main "$remote" >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -u origin main >/dev/null
}

init_repo "$workdir/app" "$tmpdir/app-origin.git"
init_repo "$infra_dir" "$tmpdir/infra-origin.git"
init_repo "$tmpdir/private-seed" "$tmpdir/private-origin.git"
git init --bare -q "$source_dir/private-app.git"
git -C "$source_dir/private-app.git" fetch --no-tags "$tmpdir/private-origin.git" \
  refs/heads/main:refs/remotes/origin/main >/dev/null
git -C "$source_dir/private-app.git" worktree add --detach "$workdir/private-app" \
  refs/remotes/origin/main >/dev/null

cat >"$config_dir/repos.json" <<JSON
{
  "root": "$root_dir",
  "workdir": "$workdir",
  "infra_dir": "$infra_dir",
  "allowed_branch_prefix": "agent/",
  "repos": {
    "app": {
      "alias": "app",
      "path": "$workdir/app",
      "default_branch": "main",
      "allowed_base_branches": ["main"]
    },
    "private-app": {
      "alias": "private-app",
      "path": "$workdir/private-app",
      "source_path": "$source_dir/private-app.git",
      "default_branch": "main",
      "allowed_base_branches": ["main"],
      "brokered_sync": true
    },
    "robokitty-infra": {
      "alias": "robokitty-infra",
      "path": "$infra_dir",
      "default_branch": "main",
      "allowed_base_branches": ["main"]
    }
  }
}
JSON

app_wt="$("$new" app agent/wp5-test main)"
assert_eq "$workdir/app.agent.wp5-test" "$app_wt" "app worktree path"
assert_eq "agent/wp5-test" "$(git -C "$app_wt" branch --show-current)" "app worktree branch"
assert_eq "$app_wt" "$("$new" app agent/wp5-test main)" "idempotent app worktree path"
"$delete" app agent/wp5-test --delete-local-branch
[ ! -e "$app_wt" ] || fail "app worktree was not deleted"
if git -C "$workdir/app" show-ref --verify --quiet refs/heads/agent/wp5-test; then
  fail "app local branch was not deleted"
fi

dirty_wt="$("$new" app agent/wp5-dirty main)"
printf 'dirty\n' >"$dirty_wt/dirty.txt"
if "$delete" app agent/wp5-dirty >/dev/null 2>&1; then
  fail "dirty worktree delete succeeded without --force"
fi
"$delete" app agent/wp5-dirty --force --delete-local-branch
[ ! -e "$dirty_wt" ] || fail "dirty app worktree was not force deleted"

infra_wt="$("$new" robokitty-infra agent/wp5-infra main)"
assert_eq "$workdir/infra.agent.wp5-infra" "$infra_wt" "infra worktree path"
assert_eq "agent/wp5-infra" "$(git -C "$infra_wt" branch --show-current)" "infra worktree branch"
assert_eq "$source_dir/infra" "$(git_common_dir "$infra_wt")" "infra source common dir"
[ -z "$(git -C "$infra_dir" status --porcelain)" ] || fail "canonical infra checkout became dirty"
"$delete" robokitty-infra agent/wp5-infra --delete-local-branch
[ ! -e "$infra_wt" ] || fail "infra worktree was not deleted"
if git -C "$source_dir/infra" show-ref --verify --quiet refs/heads/agent/wp5-infra; then
  fail "infra source local branch was not deleted"
fi

private_wt="$("$new" private-app agent/wp5-private main)"
assert_eq "$workdir/private-app.agent.wp5-private" "$private_wt" "private worktree path"
assert_eq "agent/wp5-private" "$(git -C "$private_wt" branch --show-current)" "private worktree branch"
assert_eq "$source_dir/private-app.git" "$(git_common_dir "$private_wt")" "private source common dir"
"$delete" private-app agent/wp5-private --delete-local-branch
[ ! -e "$private_wt" ] || fail "private worktree was not deleted"
if git -C "$source_dir/private-app.git" show-ref --verify --quiet refs/heads/agent/wp5-private; then
  fail "private source local branch was not deleted"
fi

if "$new" app main main >/dev/null 2>&1; then
  fail "unsafe branch without agent/ prefix was accepted"
fi

echo "OK: worktree helpers create, validate, and delete predictable worktrees"
