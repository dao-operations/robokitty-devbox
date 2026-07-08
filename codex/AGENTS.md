# Robokitty live Codex instructions

Managed seed from robokitty-devbox. This file is intentionally live-editable by
Codex for fast iteration. Periodically sync changes back to the infra repo with
`robokitty-sync-live-to-infra agent/sync-live-guidance-YYYY-MM-DD main`.

## Operating model

You are running on an Ubuntu VPS development box.

You have internet access for development work. You do not have direct access to Telegram, GitHub, or commit-signing secrets.

## Hard rules

- Do not print, search for, exfiltrate, or commit secrets.
- Do not read `/home/agent-bridge`, `/home/agent-git`, `~/.codex/auth.json`, `~/.ssh`, or credential directories.
- Do not deploy directly from this host.
- Do not push to protected branches.
- Use `agent/<short-name>` branches.
- Use `githubctl` for authenticated GitHub operations.
- Do not use authenticated `gh` directly.
- Do not call `sudo` or `/usr/local/lib/robokitty-devbox/githubctl.py` directly.
- `githubctl` talks to the restricted broker daemon through the managed wrapper;
  do not bypass it or try to reach the broker socket directly.
- Use `devbox-run` for package-heavy or untrusted repo commands when practical.

## Worktree convention

Use sibling worktrees:

```text
/srv/robokitty-devbox/work/repo
/srv/robokitty-devbox/work/repo.agent.task-name
```

Create them with:

```bash
robokitty-new-worktree <repo-alias> agent/<task-name> main
```

Delete them with:

```bash
robokitty-delete-worktree <repo-alias> agent/<task-name>
```

## GitHub workflow

1. Keep work on an `agent/*` branch and commit locally for review/audit.
2. Write `PR_BODY.md` inside the worktree.
3. Submit the committed branch diff through `githubctl submit`; the broker pushes to the configured agent fork and opens the upstream PR.
4. Report PR URL and checks.

Example:

```bash
githubctl submit \
  --repo dao \
  --worktree /srv/robokitty-devbox/work/example-frontend.agent.bootstrap-test \
  --branch agent/bootstrap-test \
  --base main \
  --title "Agent: bootstrap test" \
  --body-file PR_BODY.md \
  --draft \
  --format json
```

## Completion report

Always summarize:

- branch,
- PR URL,
- files changed,
- commands run,
- test/build status,
- known risks,
- suggested next step.
