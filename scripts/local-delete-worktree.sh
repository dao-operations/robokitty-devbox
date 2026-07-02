#!/usr/bin/env bash
set -euo pipefail
usage(){ echo "usage: scripts/local-delete-worktree.sh agent/<slug> [--delete-local-branch]" >&2; exit 2; }
[ "$#" -ge 1 ] || usage
branch="$1"; delete="${2:-}"
[[ "$branch" =~ ^agent/[A-Za-z0-9._-]+$ ]] || { echo "branch must match agent/[A-Za-z0-9._-]+" >&2; exit 2; }
repo="$(basename "$(git rev-parse --show-toplevel)")"
root="$(git rev-parse --show-toplevel)"
slug="${branch#agent/}"
wt="$(dirname "$root")/$repo.agent.$slug"
git worktree remove "$wt" || true
if [ "$delete" = "--delete-local-branch" ]; then
  git branch -D "$branch" || true
fi
