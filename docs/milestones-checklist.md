# Milestones and checklist

## M0 — Skeleton imported

- [ ] Repo created.
- [ ] Skeleton pushed.
- [ ] Codex can read README/AGENTS/docs.

## M1 — Host baseline

- [ ] Ubuntu 24.04 VPS created.
- [ ] Cloudflare Tunnel and Access application created.
- [ ] First boot bootstrap starts `cloudflared` before production Ansible.
- [ ] Production inventory uses aliases, not public IPs.
- [ ] Encrypted vault file created and committed.
- [ ] Users created.
- [ ] Base packages installed.
- [ ] UFW/fail2ban safe baseline applied with no public SSH exposure.

## M2 — Codex and Takopi

- [ ] Codex installed as `agent`.
- [ ] Codex logged in via ChatGPT.
- [ ] Codex permission profile uses internet + Auto-review.
- [ ] Codex runner can start the bubblewrap sandbox.
- [ ] Codex profile does not grant broad write access to the top-level devbox root.
- [ ] Codex app-server smoke runs in a fresh session after config changes.
- [ ] Takopi installed as `agent-bridge`.
- [ ] Takopi service starts.
- [ ] Telegram task reaches Codex.

## M3 — Secret boundaries

- [ ] `agent` cannot read Takopi config.
- [ ] `agent` cannot read GitHub PAT.
- [ ] `agent` cannot read Git signing private key.
- [ ] `agent` has no persistent GitHub token.
- [ ] `robokitty-security-check` passes.

## M4 — GitHub broker

- [ ] Separate GitHub agent user created.
- [ ] GitHub PAT stored only under `agent-git`.
- [ ] SSH signing public key added to the GitHub agent account as a signing key.
- [ ] `githubctl status` works.
- [ ] `githubctl submit` creates signed draft PR commit from the agent user's fork.
- [ ] `githubctl audit --limit 20 --format json` shows recent broker activity.
- [ ] No merge/API passthrough exists.

## M5 — Container runner

- [ ] Podman rootless works for `agent`.
- [ ] `devbox-run` runs a command in selected repo.
- [ ] No host credential directories are mounted.

## M6 — First useful remote task

- [ ] `robokitty-bootstrap-task <repo-alias>` prints the concrete Telegram prompt.
- [ ] Telegram triggers worktree creation.
- [ ] Codex edits docs/code.
- [ ] Codex runs appropriate local validation before submitting.
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

- [ ] Administrative SSH and Ansible run through Cloudflare Access.
- [ ] VPS provider firewall denies inbound SSH.
- [ ] Recoverable from service failure.
- [ ] Tokens can be rotated.
- [ ] VPS can be rebuilt from scratch.
- [ ] Docs reflect actual behavior.
