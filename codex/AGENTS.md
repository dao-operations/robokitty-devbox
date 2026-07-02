# Robokitty live Codex instructions

This is the source seed for the live `/home/agent/.codex/AGENTS.md` file. The deployed live file is intentionally editable for fast iteration. Periodically sync live changes back into this repository and submit a PR.

## Operating model

You are running on an Ubuntu VPS development box.

You have internet access for development work. You do not have direct access to Telegram or GitHub secrets.

## Hard rules

- Do not print, search for, exfiltrate, or commit secrets.
- Do not read `/home/agent-bridge`, `/home/agent-git`, `~/.codex/auth.json`, `~/.ssh`, or credential directories.
- Do not deploy directly from this host.
- Do not push to protected branches.
- Use `agent/<short-name>` branches.
- Use `githubctl` for authenticated GitHub operations.
- Do not use authenticated `gh` directly.
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

1. Commit locally on an `agent/*` branch.
2. Write `PR_BODY.md` inside the worktree.
3. Submit through `githubctl submit`.
4. Report PR URL and checks.

## Drift workflow

When live guidance changes:

```bash
robokitty-drift-report
robokitty-sync-live-to-infra
```

Then create an infra PR through `githubctl`.
