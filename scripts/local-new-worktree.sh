#!/usr/bin/env bash
set -euo pipefail
usage(){ echo "usage: scripts/local-new-worktree.sh agent/<slug> [base]" >&2; exit 2; }
[ "$#" -ge 1 ] || usage
branch="$1"; base="${2:-main}"
[[ "$branch" =~ ^agent/[A-Za-z0-9._-]+$ ]] || { echo "branch must match agent/[A-Za-z0-9._-]+" >&2; exit 2; }
repo="$(basename "$(git rev-parse --show-toplevel)")"
root="$(git rev-parse --show-toplevel)"
slug="${branch#agent/}"
wt="$(dirname "$root")/$repo.agent.$slug"
git fetch origin "$base" || true
git worktree add "$wt" -b "$branch" "origin/$base"
echo "$wt"
