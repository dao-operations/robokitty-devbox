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
- Keep durable workflow/guidance improvements separate from product-code PRs.

## Worktree convention

Use managed sibling worktrees for all edits:

```text
/srv/robokitty-devbox/work/repo
/srv/robokitty-devbox/work/repo.agent.task-name
```

Use branch names like `agent/<area>-<short-task>`, for example
`agent/docs-devbox-validation` or `agent/api-cache-refresh`.

Start each code or docs task by inspecting repo state, creating the managed
worktree, and then working only in that worktree:

```bash
robokitty-new-worktree <repo-alias> agent/<task-name> main
```

Delete them with:

```bash
robokitty-delete-worktree <repo-alias> agent/<task-name>
```

Use `robokitty-status` if you need to confirm the live repo alias list.

## GitHub workflow

1. Inspect current repo state and local instructions.
2. Create an `agent/*` managed worktree with `robokitty-new-worktree`.
3. Make the smallest useful change only inside that worktree.
4. Run local validation in the managed worktree before submitting.
5. Commit locally for review/audit.
6. Write `PR_BODY.md` inside the worktree and leave it untracked.
7. Submit the committed branch diff through `githubctl submit`; the broker pushes to the configured agent fork and opens the upstream PR.
8. Report PR URL and checks.

Validation ladder:

- Always run `git diff --check`.
- For docs-only changes, lightweight checks are enough unless the prompt asks for more.
- For infra changes touching playbooks, roles, templates, scripts, broker behavior,
  sudoers, systemd units, Podman runner behavior, or Codex permission/guidance
  wiring, run `make ci` locally before `githubctl submit`.
- Use `devbox-run` for package-heavy or untrusted commands, for example package
  installs, builds, typechecks, integration tests, and repo scripts with
  external dependencies.
- Direct host commands are fine for small read-only inspection such as `rg`,
  `git status`, `git diff`, `sed`, `ls`, and `git diff --check`.
- Before `githubctl submit`, run a pre-submit checklist:
  `git status --short`, `git diff --stat`, relevant validation, and a quick
  check that no secrets, generated junk, or unrelated dirty files are included.
- If a relevant check cannot run, stop and report the exact failure instead of
  submitting.

Use this `PR_BODY.md` shape:

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

If deployment is requested, do not deploy directly. Open a PR, report validation
and risks, and state the human review or deployment step needed.

If you make durable changes to live guidance, sync them back through the infra
repo in a separate explicit change; do not bundle workflow guidance changes with
product-code PRs.
