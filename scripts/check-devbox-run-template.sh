#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(realpath "$(mktemp -d)")"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  grep -Fq -- "$pattern" "$file" || fail "$label missing: $pattern"
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Fq -- "$pattern" "$file"; then
    fail "$label unexpectedly present: $pattern"
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
source_dir="$tmpdir/state/worktree-sources"
capture="$tmpdir/podman-argv.txt"
mkdir -p "$bindir" "$config_dir" "$workdir" "$source_dir"

playbook="$tmpdir/render.yml"
cat >"$playbook" <<YAML
---
- name: Render devbox-run wrapper for validation
  hosts: localhost
  connection: local
  gather_facts: false
  become: false
  vars_files:
    - "$repo_root/roles/robokitty_devbox/defaults/main.yml"
  tasks:
    - name: Render devbox-run
      ansible.builtin.template:
        src: "$repo_root/roles/robokitty_devbox/templates/devbox-run.sh.j2"
        dest: "$bindir/devbox-run"
        mode: "0755"
YAML

ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-ansible-playbook}"
"$ANSIBLE_PLAYBOOK_BIN" -i localhost, "$playbook" \
  -e "robokitty_config_dir=$config_dir" \
  -e "robokitty_repo_config_file=$config_dir/repos.json" \
  -e "robokitty_worktree_source_dir=$source_dir" >/dev/null

devbox_run="$bindir/devbox-run"
bash -n "$devbox_run"

cat >"$bindir/podman" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${PODMAN_CAPTURE:?}"
printf '%s\n' "$@" >"$PODMAN_CAPTURE"
SH
chmod +x "$bindir/podman"

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
git -C "$workdir/app" worktree add -b agent/wp6-test "$workdir/app.agent.wp6-test" main >/dev/null
mkdir -p "$workdir/app.agent.wp6-test/frontend"
init_repo "$infra_dir" "$tmpdir/infra-origin.git"
git clone --bare "$infra_dir" "$source_dir/infra" >/dev/null
git -C "$source_dir/infra" worktree add -b agent/wp6-infra "$workdir/infra.agent.wp6-infra" main >/dev/null

cat >"$config_dir/repos.json" <<JSON
{
  "root": "$root_dir",
  "workdir": "$workdir",
  "infra_dir": "$infra_dir",
  "repos": {
    "app": {
      "alias": "app",
      "path": "$workdir/app",
      "container_image": "docker.io/library/node:22-bookworm",
      "container_workdir": "frontend"
    },
    "robokitty-infra": {
      "alias": "robokitty-infra",
      "path": "$infra_dir",
      "container_image": "docker.io/library/ubuntu:24.04"
    }
  }
}
JSON

PATH="$bindir:$PATH" PODMAN_CAPTURE="$capture" \
  "$devbox_run" app "$workdir/app.agent.wp6-test" -- node --version
assert_file_contains "$capture" "run" "podman command"
assert_file_contains "$capture" "--rm" "ephemeral container"
assert_file_contains "$capture" "--userns=keep-id" "rootless user mapping"
assert_file_contains "$capture" "--security-opt=no-new-privileges" "no-new-privileges"
assert_file_contains "$capture" "--security-opt=apparmor=unconfined" "container AppArmor profile disable"
assert_file_contains "$capture" "--cap-drop=ALL" "capability drop"
assert_file_contains "$capture" "--network=slirp4netns" "network mode"
assert_file_contains "$capture" "--http-proxy=false" "proxy disable"
assert_file_contains "$capture" "GH_TOKEN=" "GitHub token scrub"
assert_file_contains "$capture" "GITHUB_TOKEN=" "GitHub token scrub"
assert_file_contains "$capture" "OPENAI_API_KEY=" "OpenAI key scrub"
assert_file_contains "$capture" "TELEGRAM_BOT_TOKEN=" "Telegram token scrub"
assert_file_contains "$capture" "type=bind,source=$workdir/app.agent.wp6-test,target=/workspace,rw" "selected worktree mount"
assert_file_contains "$capture" "-w" "workdir flag"
assert_file_contains "$capture" "/workspace/frontend" "repo container workdir"
assert_file_contains "$capture" "docker.io/library/node:22-bookworm" "repo image"
assert_file_contains "$capture" "node" "command argv"
assert_file_contains "$capture" "--version" "command argv"
assert_file_not_contains "$capture" "/home/" "host home mount"
assert_file_not_contains "$capture" ".ssh" "ssh mount"

mount_count="$(grep -Fc -- "--mount" "$capture")"
[ "$mount_count" = "1" ] || fail "expected exactly one bind mount, got $mount_count"

PATH="$bindir:$PATH" PODMAN_CAPTURE="$capture" \
  "$devbox_run" robokitty-infra "$workdir/infra.agent.wp6-infra" -- true
assert_file_contains "$capture" "type=bind,source=$workdir/infra.agent.wp6-infra,target=/workspace,rw" "infra worktree mount"
assert_file_contains "$capture" "/workspace" "default container workdir"
assert_file_contains "$capture" "docker.io/library/ubuntu:24.04" "infra image"

if PATH="$bindir:$PATH" PODMAN_CAPTURE="$capture" \
  "$devbox_run" app "$tmpdir/outside" -- true >/dev/null 2>&1; then
  fail "outside worktree path was accepted"
fi

if PATH="$bindir:$PATH" PODMAN_CAPTURE="$capture" \
  "$devbox_run" app "$workdir/app.agent.wp6-test/../app.agent.wp6-test" -- true >/dev/null 2>&1; then
  fail "non-canonical worktree path was accepted"
fi

cat >"$config_dir/repos.json" <<JSON
{
  "root": "$root_dir",
  "workdir": "$workdir",
  "infra_dir": "$infra_dir",
  "repos": {
    "app": {
      "alias": "app",
      "path": "$workdir/app",
      "container_image": "docker.io/library/node:22-bookworm",
      "container_workdir": "../secret"
    }
  }
}
JSON

if PATH="$bindir:$PATH" PODMAN_CAPTURE="$capture" \
  "$devbox_run" app "$workdir/app.agent.wp6-test" -- true >/dev/null 2>&1; then
  fail "unsafe container_workdir was accepted"
fi

echo "OK: devbox-run validates worktrees and invokes Podman with constrained mounts"
