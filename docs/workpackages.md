# Workpackages

## WP0 — Repository bootstrap

Goal: make this skeleton internally consistent and easy to run.

Tasks:

- Verify Ansible paths match repo conventions.
- Fill obvious placeholders.
- Add linting commands if the local Ansible repo uses them.
- Confirm docs and templates agree on variable names.

Exit criteria:

- `ansible-playbook --syntax-check` runs against example inventory, or all blockers are explicitly documented.

## WP1 — Ubuntu baseline

Tasks:

- Implement Ubuntu 24.04 preflight.
- Install packages.
- Create users/groups/directories.
- Add safe UFW/fail2ban/unattended-upgrades baseline.

Exit criteria:

- VPS has `agent-bridge`, `agent`, `agent-git`.
- No SSH lockout.

## WP2 — Codex + Approve for me

Tasks:

- Install Codex as `agent`.
- Configure ChatGPT login mode.
- Configure permission profile with internet enabled.
- Configure Auto-review / Approve for me.
- Do not configure API-key auth or full access.

Exit criteria:

- `sudo -iu agent codex --version` works.
- Manual ChatGPT login works.

## WP3 — Takopi bridge

Tasks:

- Install Takopi as `agent-bridge`.
- Render secret config.
- Run under systemd.
- Start Codex through constrained wrapper.

Exit criteria:

- Telegram message reaches Codex.
- `agent` cannot read Takopi token.

## WP4 — GitHub App broker

Tasks:

- Store GitHub App private key under `agent-git`.
- Mint installation tokens.
- Implement `githubctl status`, `submit`, `pr view`, `pr checks`, `pr comment`.
- Safe-squash submission through clean temporary clone.

Exit criteria:

- Codex can submit draft PR through `githubctl`.
- Codex cannot read GitHub App key.
- No merge or arbitrary API passthrough exists.

## WP5 — Worktree convention

Tasks:

- Implement `robokitty-new-worktree`.
- Implement `robokitty-delete-worktree`.
- Use sibling worktree paths: `../repo.agent.task-name`.

Exit criteria:

- Worktree creation/deletion is predictable and safe.

## WP6 — Rootless Podman runner

Tasks:

- Install Podman.
- Implement `devbox-run`.
- Run selected repo commands in containers without mounting host secrets.

Exit criteria:

- `devbox-run <repo> <worktree> -- node --version` works.
- Build/test commands can run for one target repo.

## WP7 — Live guidance + drift sync

Tasks:

- Seed live AGENTS.md/skills.
- Symlink into Codex config.
- Implement drift report and sync scripts.

Exit criteria:

- Codex can edit live guidance.
- Drift can be synced back to infra repo and submitted as PR.

## WP8 — End-to-end bootstrap task

Tasks:

- Create docs-only branch from Telegram.
- Run checks.
- Submit draft PR.
- Report result.

Exit criteria:

- Telegram -> Codex -> worktree -> githubctl -> GitHub PR works.

## WP9 — Hardening backlog

Tasks:

- Tailscale or Cloudflare Access.
- Repo-specific containers/devcontainers.
- Stronger process visibility hardening.
- Log/audit trail for `githubctl`.
- Multi-user Telegram group topics.
- Dedicated ChatGPT workspace identity.
