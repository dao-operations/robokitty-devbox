---
name: frontend-change
description: Make a frontend change in an isolated sibling worktree, run checks, and submit a draft PR.
---

# Frontend change skill

## Workflow

1. Inspect the current repo state, then create a sibling worktree on an
   `agent/<area>-<short-task>` branch:

```bash
robokitty-new-worktree <repo-alias> agent/<task-name> main
```

2. Enter the worktree and inspect repo instructions:

```bash
cd /srv/robokitty-devbox/work/<repo>.agent.<task-name>
find .. -name AGENTS.md -print
```

3. Make the smallest useful change. Work only in the managed worktree.

4. Prefer containerized checks when package scripts or dependencies are untrusted:

```bash
devbox-run <repo-alias> "$PWD" -- pnpm install --frozen-lockfile
devbox-run <repo-alias> "$PWD" -- pnpm test
devbox-run <repo-alias> "$PWD" -- pnpm build
```

5. If container use is impractical, run repo commands on the host only when no secrets are readable in the worktree.

6. Run the pre-submit checklist:

```bash
git diff --check
git status --short
git diff --stat
```

Confirm the diff has no secrets, generated junk, or unrelated files. If a
relevant check cannot run, stop and report the exact failure.

7. Commit locally.

8. Write `PR_BODY.md` and leave it untracked:

```markdown
## Summary

- ...

## Testing

- ...

## Risks

- ...

## Notes

- ...
```

9. Submit with `githubctl`.

## Final report

Report branch, PR URL, files changed, commands run, test/build status, known
risks, and next step.
