# ADR 0011: GitHub broker Unix socket daemon

## Status

Accepted.

## Context

The first broker design used `sudo` from the Codex runner to cross from
`agent` to `agent-git` for authenticated GitHub operations. Production testing
showed this is not reliable from Codex-spawned commands because the Linux
sandbox sets `no_new_privs`. In that state, `sudo` cannot perform the setuid
transition, and bubblewrap can also present host files such as `/etc/sudo.conf`
with unexpected ownership.

Codex still must not receive the GitHub PAT or signing private key.

## Decision

Run a small `agent-git` broker daemon behind a root-managed Unix socket at
`/run/robokitty-devbox/githubctl.sock`.

The public `githubctl` wrapper remains the agent-facing interface. For submit
and PR comment operations it prepares bounded patch/body files as the runner in
`/var/lib/robokitty-devbox/githubctl-exchange`, then sends only broker
arguments to the daemon. The broker rejects prepared files outside that managed
exchange directory. The exchange directory is not under the worktree parent,
because Codex's sandbox setup scans managed workspaces and can fail closed when
it encounters unreadable broker-owned handoff directories. For status, audit,
PR view, and PR checks it forwards the restricted command directly. The daemon
executes the existing restricted broker implementation as `agent-git`.

The socket is owned by `agent-git:agent` with mode `0660`. Codex is configured
to allow that specific Unix socket and no broad Unix socket access. The handoff
uses the runner's primary group because Codex command sandboxes preserve that
group reliably, while supplementary groups may be absent. `requirements.toml`
remains restrictive and contains no `allow` rules.

## Consequences

- Codex no longer needs to run `sudo` for GitHub operations.
- The PAT and signing private key remain readable only by `agent-git`.
- The broker command surface remains `status`, `audit`, `submit`, `pr view`,
  `pr checks`, and `pr comment`.
- The daemon is now part of the production service set and must be covered by
  `robokitty-security-check`.
- Broker exchange state lives outside the Codex worktree parent, and the
  playbook removes the legacy in-workdir exchange directory during apply.
