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
- Keep the dev/example path safe from lockout, but require Cloudflare-first access before production use.

Exit criteria:

- VPS has `agent-bridge`, `agent`, `agent-git`.
- No SSH lockout.
- Production docs identify the Cloudflare bootstrap path before public SSH is removed.

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

## WP4 — GitHub third-identity broker

Tasks:

- Store a separate GitHub identity PAT under `agent-git`.
- Store a dedicated SSH commit signing key under `agent-git`.
- Keep the PAT and signing private key unreadable by the Codex runner and bridge users.
- Implement `githubctl status`, `submit`, `pr view`, `pr checks`, `pr comment`.
- Implement brokered sync for configured private repositories without exposing
  the GitHub PAT to the Codex runner.
- Safe-squash submission through clean temporary clone.
- Push agent branches to the separate identity's fork and open PRs upstream.
- Sign broker-created squash commits by default.
- Deny workflow file edits, merges, workflow dispatch, secrets, admin, and arbitrary API passthrough.

Exit criteria:

- Codex can submit draft PR through `githubctl`.
- Codex can sync configured private repositories into local credential-free
  worktrees.
- Codex cannot read GitHub PAT.
- Codex cannot read Git signing private key.
- No merge or arbitrary API passthrough exists.

## WP5 — Worktree convention

Tasks:

- Implement `robokitty-new-worktree`.
- Implement `robokitty-delete-worktree`.
- Use sibling worktree paths under the configured work directory:
  `../repo.agent.task-name`. For the infra repo, place task worktrees under
  the work directory instead of making the top-level devbox root writable.
- For the infra repo, create those task worktrees from a runner-owned source
  repo outside the canonical checkout so Codex does not mutate protected
  canonical `.git` metadata.
- For broker-synced private repos, create task worktrees from the runner-owned
  local source repo created by `githubctl repo sync`.

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
- Docs-only smoke tasks run lightweight local validation before submit.
- Infra changes use VPS-local `make ci` as the pre-submit signal before relying
  on any external GitHub CI.

## WP9 — Cloudflare-first production access

Tasks:

- Use Cloudflare Tunnel plus Cloudflare Access as the production SSH and Ansible transport.
- Document provider `cloud-init` or console bootstrap for `cloudflared` before the first Ansible run.
- Add committed encrypted Ansible Vault as the production config pattern.
- Make the production inventory contain aliases and vault references, not public IPs.
- Tighten role contracts so production Cloudflare mode does not require world-open SSH CIDRs.
- Add SSH daemon hardening that is compatible with Cloudflare Access SSH.
- Validate that UFW has deny-incoming posture and no public SSH allow rule in production mode.

Exit criteria:

- A fresh Ubuntu 24.04 VPS can be reached by Ansible through Cloudflare Access without opening public SSH.
- Production check/apply runs use only committed encrypted vault values plus a human-provided vault password.
- `robokitty-security-check` passes after apply.

## WP10 — Remaining hardening backlog

Tasks:

- Repo-specific container workdirs and images.
- Devcontainer support if needed.
- Stronger process visibility hardening for managed services.
- Log/audit trail for `githubctl`.
- Multi-user Telegram group topics.
- Dedicated ChatGPT workspace identity.

## WP11 — Self-hosted deploy runner pilot

Tasks:

- Document the deploy-runner security model in an ADR.
- Keep Cloudflare-first ingress unchanged; the runner must use outbound GitHub
  connectivity only.
- Add a disabled-by-default GitHub Actions self-hosted runner managed by
  Ansible.
- Split GitHub job execution from deploy secret custody:
  `agent-actions` runs workflows, `agent-deploy` owns the vault password and
  clean deploy checkout.
- Add a fixed deploy wrapper that accepts no arguments, ignores
  `$GITHUB_WORKSPACE`, fetches the protected upstream branch into a clean
  deploy checkout, and applies Ansible through local connection.
- Extend `robokitty-security-check` and template checks for the deploy runner.
- Document the required human-authored GitHub workflow because `githubctl`
  intentionally blocks workflow file edits.

Exit criteria:

- Codex cannot read the deploy vault password.
- The Actions runner cannot read the deploy vault password.
- Codex cannot invoke deploy.
- The Actions runner can invoke only the fixed deploy wrapper through sudo.
- No inbound firewall, SSH, or webhook access is added.
- The deploy workflow runs only after protected-branch merge.
