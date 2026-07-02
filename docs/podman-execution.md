# Podman execution model

## Decision

Use rootless Podman in P0, but do not run Codex itself inside each repo container.

Codex runs on the host. Repo commands can be run in containers through `devbox-run`.

## Why this split

- Codex needs persistent local context, worktrees, and Takopi integration.
- Repo package scripts may be untrusted or messy.
- Rootless Podman lets us run package-heavy commands without mounting host credentials.
- This avoids the complexity of persistent per-repo containers while still teaching the right security lesson.

## Command

```bash
devbox-run <repo-alias> <worktree-path> -- <command...>
```

Example:

```bash
devbox-run dao /srv/robokitty-devbox/work/example-frontend.agent.bootstrap-test -- pnpm build
```

## Container constraints

The wrapper should:

- mount only the selected worktree at `/workspace`,
- not mount `/home/agent`,
- not mount `/home/agent-bridge`,
- not mount `/home/agent-git`,
- not mount SSH keys,
- not mount Codex auth,
- allow network,
- run rootless,
- drop capabilities,
- use `--security-opt=no-new-privileges`.

## P0/P1 line

P0:

- install Podman,
- provide `devbox-run`,
- use it when practical,
- allow direct host execution for the first smoke test.

P1:

- add repo-specific container images,
- add devcontainer support if needed,
- prefer `devbox-run` for all install/build/test.

P2:

- enforce repo commands through containers for selected repos.
