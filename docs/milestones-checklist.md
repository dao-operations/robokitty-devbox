# Milestones and checklist

## M0 — Skeleton imported

- [ ] Repo created.
- [ ] Skeleton pushed.
- [ ] Codex can read README/AGENTS/docs.

## M1 — Host baseline

- [ ] Ubuntu 24.04 VPS created.
- [ ] Inventory configured.
- [ ] Vault file created.
- [ ] Users created.
- [ ] Base packages installed.
- [ ] UFW/fail2ban safe baseline applied.

## M2 — Codex and Takopi

- [ ] Codex installed as `agent`.
- [ ] Codex logged in via ChatGPT.
- [ ] Codex permission profile uses internet + Auto-review.
- [ ] Takopi installed as `agent-bridge`.
- [ ] Takopi service starts.
- [ ] Telegram task reaches Codex.

## M3 — Secret boundaries

- [ ] `agent` cannot read Takopi config.
- [ ] `agent` cannot read GitHub App private key.
- [ ] `agent` has no persistent GitHub token.
- [ ] `robokitty-security-check` passes.

## M4 — GitHub broker

- [ ] GitHub App installed on target repo.
- [ ] `githubctl status` works.
- [ ] `githubctl submit` creates draft PR.
- [ ] No merge/API passthrough exists.

## M5 — Container runner

- [ ] Podman rootless works for `agent`.
- [ ] `devbox-run` runs a command in selected repo.
- [ ] No host credential directories are mounted.

## M6 — First useful remote task

- [ ] Telegram triggers worktree creation.
- [ ] Codex edits docs/code.
- [ ] Checks run.
- [ ] Branch committed.
- [ ] Draft PR created.
- [ ] Summary posted to Telegram.

## M7 — Drift loop

- [ ] Codex edits live guidance.
- [ ] Drift report shows changes.
- [ ] Sync copies live guidance into infra repo.
- [ ] Draft PR opened for guidance changes.
- [ ] Human reviews/merges.
- [ ] Human manually runs Ansible.

## M8 — Production-ish pilot quality

- [ ] Recoverable from service failure.
- [ ] Tokens can be rotated.
- [ ] VPS can be rebuilt from scratch.
- [ ] Docs reflect actual behavior.
