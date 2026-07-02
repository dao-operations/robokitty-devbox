# Drift sync prompt

You are reconciling live Robokitty guidance back into the infra repo.

On the devbox:

1. Run `robokitty-drift-report || true`.
2. Run `robokitty-sync-live-to-infra`.
3. Inspect `git diff -- codex` in `/srv/robokitty-devbox/infra`.
4. Remove accidental secrets or low-value noise.
5. Commit the reviewed guidance changes on `agent/sync-live-guidance-YYYY-MM-DD`.
6. Submit a draft PR with `githubctl`.

Do not modify privileged Ansible state unless explicitly asked.

Final response format:

```text
Live changes synced:
Files changed:
Secrets checked:
PR URL:
Manual follow-up:
```
