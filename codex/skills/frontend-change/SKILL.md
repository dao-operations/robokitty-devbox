---
name: frontend-change
description: Make a frontend change in an isolated sibling worktree, run checks, and submit a draft PR.
---

# Frontend change skill

## Workflow

1. Create a sibling worktree:

```bash
robokitty-new-worktree <repo-alias> agent/<task-name> main
```

2. Enter the worktree and inspect repo instructions:

```bash
cd /srv/robokitty-devbox/work/<repo>.agent.<task-name>
find .. -name AGENTS.md -print
```

3. Make the smallest useful change.

4. Prefer containerized checks when package scripts or dependencies are untrusted:

```bash
devbox-run <repo-alias> "$PWD" -- pnpm install --frozen-lockfile
devbox-run <repo-alias> "$PWD" -- pnpm test
devbox-run <repo-alias> "$PWD" -- pnpm build
```

5. If container use is impractical, run repo commands on the host only when no secrets are readable in the worktree.

6. Commit locally.

7. Write `PR_BODY.md`.

8. Submit with `githubctl`.

## Final report

Report branch, PR URL, commands run, and known risks.
