---
name: devbox-maintenance
description: Maintain live Robokitty guidance and sync drift back to the infra repo.
---

# Devbox maintenance skill

Use this for improving AGENTS.md, skills, docs, and helper guidance.

Keep durable workflow improvements separate from product-code PRs. If a product
task reveals a better workflow, report the observation there, then make the
guidance change through a dedicated infra/guidance task.

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
robokitty-sync-live-to-infra agent/sync-live-guidance-YYYY-MM-DD main
cd /srv/robokitty-devbox/work/infra.agent.sync-live-guidance-YYYY-MM-DD
git diff -- codex
```

Then commit the `codex/` changes in that worktree and submit a PR with
`githubctl`.

Use a PR body with:

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

The P0 sync helper accepts only `AGENTS.md` and `skills/<name>/SKILL.md`.
It ignores Codex's generated `skills/.system` cache and never syncs that cache
back to the infra repo. Move broader support files through a normal infra-repo
PR.

## Boundaries

Do not edit:

- `/home/agent-bridge`,
- `/home/agent-git`,
- sudoers,
- systemd units,
- secret files,
- vaulted variables.

Privileged changes must be proposed in the infra repo and applied manually by the human operator.
