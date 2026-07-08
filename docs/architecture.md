# Architecture

## Goal

Robokitty is an always-on remote development box controlled from Telegram, Codex, and SSH.

It is deliberately not a general agent framework. Codex is the harness. Takopi is the Telegram bridge. The custom work is the security boundary around GitHub credentials, filesystem secrets, worktree conventions, and repeatable operational hygiene.

## Components

```text
Telegram
  -> Takopi as agent-bridge
  -> Codex as agent
  -> repo worktrees under /srv/robokitty-devbox/work
  -> githubctl broker daemon as agent-git
  -> GitHub draft PRs
```

### agent-bridge

Owns Takopi and the Telegram token. It can invoke Codex through a constrained wrapper but cannot read Codex credentials or GitHub credentials.

### agent

Owns Codex, worktrees, live guidance, and normal development commands. It has internet access. It must not be able to read Telegram or GitHub secrets.

### agent-git

Owns the separate GitHub identity's PAT and exposes only the restricted
`githubctl` interface through a group-owned Unix socket. Codex can ask for
brokered operations, but it cannot read or persist the PAT.

### rootless Podman

Used for repo command execution where practical. Codex remains on the host; repo commands can be run in containers using `devbox-run`.

### live guidance

`/srv/robokitty-devbox/live/codex` is live-editable by Codex for fast iteration. Periodically sync it back to the infra repo.

## Data/control flow

```text
Telegram message
  -> Takopi reads token and receives update
  -> Takopi starts Codex through /usr/local/lib/robokitty-devbox/wrappers/codex
  -> Codex edits files in a runner-owned worktree
  -> Codex runs tests, preferably via devbox-run
  -> Codex commits locally
  -> Codex calls githubctl submit
  -> githubctl sends prepared request to the agent-git broker daemon
  -> agent-git reads the third-identity PAT
  -> broker safe-squashes diff into a clean upstream clone
  -> broker creates or reuses the agent identity fork
  -> broker pushes agent/* branch to that fork and opens draft PR upstream
```
