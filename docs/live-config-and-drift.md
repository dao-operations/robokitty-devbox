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
robokitty-sync-live-to-infra
cd /srv/robokitty-devbox/infra
git diff -- codex
```

Then create a branch:

```bash
robokitty-new-worktree robokitty-infra agent/sync-live-guidance-YYYY-MM-DD main
```

Copy or sync the live changes into that worktree, commit, and submit via `githubctl`.

## Philosophy

Live guidance is the fast feedback loop. The infra repo is the canonical reviewed record. Drift is allowed temporarily but should be reconciled periodically.
