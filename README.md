# robokitty-devbox

`robokitty-devbox` is a pilot infrastructure repository for an always-on Ubuntu VPS development box controlled from Codex and Telegram.

The goal is to prove this operating model:

```text
Telegram / laptop Codex / Cloudflare Access SSH
        │
        ▼
Ubuntu VPS devbox
        │
        ├── agent-bridge: Takopi + Telegram token
        ├── agent: Codex + worktrees + internet access
        ├── agent-git: third-identity GitHub PAT + restricted GitHub broker
        ├── rootless Podman runner for repo commands
        └── live Codex guidance with periodic drift sync back to this repo
```

Codex should be useful, internet-enabled, and able to create signed PR commits, while being technically unable to read the Telegram bot token, the GitHub PAT, or the SSH signing private key used by the separate agent identity.

## What this repository contains

```text
playbooks/                 Ansible playbook entrypoint
roles/robokitty_devbox/     Ansible role scaffold
codex/                      Seed AGENTS.md and skills deployed to the devbox
docs/                       Architecture, security model, runbook, work plan
prompts/                    Prompts for implementer/reviewer/integrator/security passes
scripts/                    Local helper scripts for this repo
```

## Core decisions

1. Ubuntu 24.04 only.
2. No Terraform for the pilot.
3. No MCP for the pilot.
4. No Kubernetes for the pilot.
5. Use Codex with ChatGPT login, not OpenAI API-key billing.
6. Use Codex `Approve for me` / Auto-review, not full access.
7. Enable Codex internet access, but keep filesystem restrictions and Unix-user secret separation.
8. Use Takopi as the Telegram bridge.
9. Use a separate GitHub user through a restricted broker instead of giving Codex an authenticated GitHub CLI.
10. Sign broker-created PR commits by default with a dedicated SSH signing key.
11. Use rootless Podman for repo command execution where possible.
12. Let Codex iterate live on non-secret guidance under `/srv/robokitty-devbox/live`; periodically sync drift back into this repo.
13. Only a human with vault access applies privileged Ansible changes.
14. Use Cloudflare Tunnel plus Cloudflare Access for production SSH and Ansible transport.
15. Commit only encrypted Ansible Vault files for deployment-specific private config.

## First useful milestone

On the devbox, generate the first task prompt:

```bash
robokitty-bootstrap-task <repo-alias>
```

Then send the generated Telegram message. It will look like:

```text
/<repo-alias>
Create a tiny README.md or docs/ change on branch agent/bootstrap-test.
Use the managed worktree helper and stop if it fails.
Run the lightweight checks, including git diff --check.
Commit locally for review.
Create PR_BODY.md and leave it untracked.
Submit a draft PR using githubctl.
Report the PR URL.
Do not merge.
```

Do not put `@agent/bootstrap-test` on the Telegram directive line; the prompt
asks Codex to create the runner-owned worktree with `robokitty-new-worktree`.
The generated bootstrap task is intentionally docs-only, so `git diff --check`
is enough for that smoke. For real infra changes touching playbooks, roles,
templates, scripts, broker behavior, sudoers, systemd units, Podman runner
behavior, or Codex permission/guidance wiring, require `make ci` locally on the
VPS before `githubctl submit`.

## How to start with Codex

Open this repository in Codex and give it:

```text
Read README.md, AGENTS.md, docs/workpackages.md, docs/milestones-checklist.md, and docs/runbook.md.
Start with WP0 and WP1. Keep changes small. Do not implement outside the documented scope without updating docs/decisions.
```

Use the prompts in `prompts/` for structured implementation, review, and integration passes.

## Local validation

Install Ansible collections and run the local checks with `uv`:

```bash
make install-dev
make ci
```

For a syntax-only pass:

```bash
make syntax
```

## Current status

This is a project skeleton and implementation brief, not a finished Ansible role. The role contains enough scaffolding and templates to let Codex begin implementation without re-litigating the architecture.
