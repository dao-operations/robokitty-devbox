---
name: github-pr-submit
description: Submit an agent branch as a draft GitHub PR through the restricted githubctl broker.
---

# GitHub PR submit skill

Use this when a task is ready to leave the devbox as a GitHub draft PR.

## Preconditions

- Work is on a branch matching `agent/[A-Za-z0-9._-]+`.
- Worktree is clean.
- Commits are local.
- `PR_BODY.md` exists inside the worktree.
- No secrets are included in the diff.

## Commands

```bash
git status --short
git branch --show-current
git log --oneline origin/main..HEAD
```

Submit:

```bash
githubctl submit \
  --repo <alias> \
  --worktree <absolute-worktree-path> \
  --branch agent/<task> \
  --base main \
  --title "Agent: <short title>" \
  --body-file PR_BODY.md \
  --draft \
  --format json
```

After submission:

```bash
githubctl pr checks --repo <alias> --number <pr-number> --format json
```

## Never do

- Do not run authenticated `gh` directly.
- Do not merge PRs.
- Do not dispatch workflows.
- Do not push protected branches.
