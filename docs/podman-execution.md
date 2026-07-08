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

Each repo may set `container_image` and `container_workdir` in repo config.
`container_workdir` is a safe relative path inside the selected worktree and
defaults to `/workspace`. It does not add mounts or arbitrary Podman flags.

Use non-login shells inside language images unless the repo specifically
requires login-shell behavior. Login shells may reset image-provided `PATH`
entries such as `/usr/local/cargo/bin` in the official Rust images.

Official language images may omit optional developer components. For example,
the official Rust image can provide `rustc` and `cargo` without `rustfmt`; run
checks that match the configured image, or use a repo-specific image with the
missing component preinstalled.

Rootless containers run with the runner UID through `--userns=keep-id`, so
commands should not try to mutate image-owned global tool directories such as
`/usr/local/lib/node_modules`. If a repo pins a package manager version, install
that tool into `/tmp` or the worktree for the single `devbox-run` invocation.

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
- use `--security-opt=no-new-privileges`,
- disable the per-container AppArmor profile with
  `--security-opt=apparmor=unconfined` while relying on rootless execution,
  explicit mounts, dropped capabilities, and host runtime-helper AppArmor
  profiles for the P0 boundary.

On Ubuntu 24.04, rootless Podman also needs explicit host support:

- the runner has subordinate UID/GID ranges,
- the runner keeps its normal primary group for rootless Podman and broker
  handoff, with `agent-work` only as a supplementary group for shared worktree
  state,
- per-user storage config forces `fuse-overlayfs` for the overlay driver,
- AppArmor user-namespace profiles are loaded for `podman`, `conmon`, `crun`,
  `fuse-overlayfs`, and `slirp4netns` when Ubuntu's restricted unprivileged
  user namespace sysctl exists.

## P0/P1 line

P0:

- install Podman,
- provide `devbox-run`,
- use it when practical,
- allow direct host execution for the first smoke test.

P1:

- add repo-specific container images and workdirs,
- add devcontainer support if needed,
- prefer `devbox-run` for all install/build/test.

P2:

- enforce repo commands through containers for selected repos.
