# Brief for Codex: implement robokitty-devbox

You are implementing an Ubuntu 24.04 Ansible-managed remote development box called Robokitty.

## Read first

1. `README.md`
2. `AGENTS.md`
3. `docs/architecture.md`
4. `docs/security-model.md`
5. `docs/workpackages.md`
6. `docs/milestones-checklist.md`
7. `docs/runbook.md`

## Core architecture

- `agent-bridge`: runs Takopi, owns Telegram token.
- `agent`: runs Codex, owns worktrees, has internet.
- `agent-git`: owns GitHub App key and performs brokered GitHub operations.
- `githubctl`: only authenticated GitHub interface available to Codex.
- `devbox-run`: rootless Podman wrapper for repo commands.
- `/srv/robokitty-devbox/live/codex`: live-editable Codex guidance.
- `/srv/robokitty-devbox/infra`: infra repo clone, periodically synced from live guidance.

## Required P0 properties

- Codex uses ChatGPT login, not OpenAI API-key auth.
- Codex uses Auto-review / Approve for me.
- Codex has internet access.
- Codex does not have `danger-full-access`.
- Codex cannot read Telegram token.
- Codex cannot read GitHub App private key.
- Codex cannot run authenticated `gh` directly.
- GitHub PR creation goes through `githubctl`.
- GitHub broker cannot merge, dispatch workflows, access secrets, or pass through arbitrary API calls.
- Podman wrapper runs repo commands without mounting host credential directories.
- Live AGENTS.md/skills can be updated quickly; drift sync reconciles to repo periodically.

## Suggested sequence

Start with WP0 and WP1. Do not try to finish everything in one pass.

Use `prompts/implementer.md`, `prompts/reviewer.md`, and `prompts/security-reviewer.md` for structured passes.

## Do not ask the human to revisit architecture unless you find a concrete blocker

If a detail is ambiguous, choose the safer/simple option and document it in an ADR.
