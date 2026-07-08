---
name: github-pr-submit
description: Submit an agent branch as a draft GitHub PR through the restricted githubctl broker.
---

# GitHub PR submit skill

Use this when a task is ready to leave the devbox as a GitHub draft PR through
the configured agent identity fork.

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

Use the `githubctl` wrapper normally. Do not call `sudo`, `agent-git`, or the
broker implementation directly. Do not connect to the broker socket directly.
The managed `githubctl` wrapper handles the broker handoff.

After submission:

```bash
githubctl pr checks --repo <alias> --number <pr-number> --format json
```

## Never do

- Do not run authenticated `gh` directly.
- Do not merge PRs.
- Do not dispatch workflows.
- Do not edit `.github/workflows/`.
- Do not push protected branches.
