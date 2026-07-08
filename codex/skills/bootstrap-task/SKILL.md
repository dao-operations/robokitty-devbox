---
name: bootstrap-task
description: Run the first end-to-end Robokitty bootstrap task from Telegram to a draft PR.
---

# Bootstrap task skill

Use this for the first useful remote task after the devbox is deployed.

## Goal

Prove the full path:

```text
Telegram -> Codex -> worktree -> checks -> commit -> githubctl -> draft PR -> Telegram report
```

## Workflow

1. Create the requested worktree:

```bash
robokitty-new-worktree <repo-alias> agent/bootstrap-test <base-branch>
```

If the helper fails, stop and report the failure. Do not create a fallback clone
and do not edit the canonical repo checkout directly.

2. Make a tiny documentation-only change.

Acceptable targets:

- update `README.md`,
- add or update a file under `docs/`.

3. Run lightweight checks.

At minimum:

```bash
git diff --check
```

Use repo-specific checks when obvious and cheap.

4. Commit locally on `agent/bootstrap-test`.

5. Create `PR_BODY.md` in the worktree with:

- summary,
- validation commands and results,
- known risks,
- note that this is a bootstrap smoke PR.

6. Submit a draft PR through `githubctl submit`.

Use the `githubctl` wrapper normally. Do not call `sudo`, `agent-git`, or the
broker implementation directly. Do not connect to the broker socket directly.
The managed `githubctl` wrapper handles the broker handoff.
Run `githubctl status --repo <repo-alias> --format json` before submitting.

7. If a PR number is available, run `githubctl pr checks`.

## Boundaries

- Do not touch secrets or credentials.
- Do not modify sudoers, systemd units, GitHub broker scripts, token handling, or Codex permission profiles.
- Do not modify `AGENTS.md`, `codex/`, `.codex/`, or live guidance files.
- Do not run authenticated `gh` directly.
- Do not merge.

## Final report

Report:

- branch,
- PR URL,
- files changed,
- commands run,
- check status,
- known risks,
- suggested next step.
