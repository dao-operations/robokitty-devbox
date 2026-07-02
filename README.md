# robokitty-devbox

`robokitty-devbox` is a pilot infrastructure repository for an always-on Ubuntu VPS development box controlled from Codex and Telegram.

The goal is to prove this operating model:

```text
Telegram / laptop Codex / SSH
        │
        ▼
Ubuntu VPS devbox
        │
        ├── agent-bridge: Takopi + Telegram token
        ├── agent: Codex + worktrees + internet access
        ├── agent-git: GitHub App key + restricted GitHub broker
        ├── rootless Podman runner for repo commands
        └── live Codex guidance with periodic drift sync back to this repo
```

Codex should be useful, internet-enabled, and able to create PRs, while being technically unable to read the Telegram bot token or GitHub App private key.

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
9. Use a GitHub App through a restricted broker instead of giving Codex an authenticated GitHub CLI.
10. Use rootless Podman for repo command execution where possible.
11. Let Codex iterate live on non-secret guidance under `/srv/robokitty-devbox/live`; periodically sync drift back into this repo.
12. Only a human with vault access applies privileged Ansible changes.

## First useful milestone

From Telegram, tell Robokitty to:

```text
/<repo-alias> @agent/bootstrap-test
Create a tiny documentation-only change on branch agent/bootstrap-test.
Run the lightweight checks.
Commit locally.
Create PR_BODY.md.
Submit a draft PR using githubctl.
Report the PR URL.
Do not merge.
```

## How to start with Codex

Open this repository in Codex and give it:

```text
Read README.md, AGENTS.md, docs/workpackages.md, docs/milestones-checklist.md, and docs/runbook.md.
Start with WP0 and WP1. Keep changes small. Do not implement outside the documented scope without updating docs/decisions.
```

Use the prompts in `prompts/` for structured implementation, review, and integration passes.

## Current status

This is a project skeleton and implementation brief, not a finished Ansible role. The role contains enough scaffolding and templates to let Codex begin implementation without re-litigating the architecture.
