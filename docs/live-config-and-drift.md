# Live config and drift model

## Problem

If every AGENTS.md or skill change requires an Ansible PR, merge, and deploy, iteration becomes too slow.

## Decision

Codex may directly edit non-secret live guidance on the devbox:

```text
/srv/robokitty-devbox/live/codex/AGENTS.md
/srv/robokitty-devbox/live/codex/skills/*
```

These are symlinked into:

```text
/home/agent/.codex/AGENTS.md
/home/agent/.codex/skills
```

This makes guidance changes take effect quickly for future sessions.

P0 drift sync accepts only guidance-shaped files:

- `AGENTS.md`,
- `skills/<skill-name>/SKILL.md`.

The drift and sync helpers fail closed on symlinks, unsafe path names, secret-like
filenames, and unsupported live files.

Codex may create its own generated system skill cache at `skills/.system` under
the live skills symlink. The helpers validate that this cache path is a real
directory, ignore it in drift reports, and never sync it back to the infra repo.

## Guardrail

Codex may not directly edit privileged baseline state:

- sudoers,
- systemd units,
- users,
- secret files,
- GitHub broker scripts under `/usr/local/lib`,
- `/etc/robokitty-devbox`,
- Ansible Vault values.

Privileged changes must be proposed in this repository and applied manually by the human operator.

## Weekly sync

Run:

```bash
robokitty-drift-report || true
robokitty-sync-live-to-infra agent/sync-live-guidance-YYYY-MM-DD main
cd /srv/robokitty-devbox/work/infra.agent.sync-live-guidance-YYYY-MM-DD
git diff -- codex
```

Then commit and submit the sync worktree:

```bash
git add codex
git commit -m "docs: sync live Codex guidance"
printf '%s\n' \
  '## Summary' \
  '- Sync live Codex guidance from the devbox.' \
  '' \
  '## Validation' \
  '- robokitty-drift-report reviewed before sync.' \
  > PR_BODY.md
# Leave PR_BODY.md untracked; githubctl copies it as submit metadata.
githubctl submit \
  --repo robokitty-infra \
  --worktree "$PWD" \
  --branch agent/sync-live-guidance-YYYY-MM-DD \
  --base main \
  --title "Agent: sync live Codex guidance" \
  --body-file PR_BODY.md \
  --draft \
  --format json
```

The sync helper creates or reuses a managed infra worktree under
`/srv/robokitty-devbox/work` and leaves the canonical infra checkout clean.

## Philosophy

Live guidance is the fast feedback loop. The infra repo is the canonical reviewed record. Drift is allowed temporarily but should be reconciled periodically.
