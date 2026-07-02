---
name: devbox-maintenance
description: Maintain live Robokitty guidance and sync drift back to the infra repo.
---

# Devbox maintenance skill

Use this for improving AGENTS.md, skills, docs, and helper guidance.

## Fast live iteration

Non-secret live guidance may be edited directly under:

```text
/srv/robokitty-devbox/live/codex
```

Changes apply quickly to future Codex sessions because `/home/agent/.codex/AGENTS.md` and skills are symlinked to the live tree.

## Weekly sync

To sync live drift back to the infra repo:

```bash
robokitty-drift-report || true
robokitty-sync-live-to-infra
cd /srv/robokitty-devbox/infra
git diff -- codex
```

Then create an `agent/sync-live-guidance-YYYY-MM-DD` branch and submit a PR with `githubctl`.

## Boundaries

Do not edit:

- `/home/agent-bridge`,
- `/home/agent-git`,
- sudoers,
- systemd units,
- secret files,
- vaulted variables.

Privileged changes must be proposed in the infra repo and applied manually by the human operator.
