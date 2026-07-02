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
  -> githubctl broker as agent-git
  -> GitHub draft PRs
```

### agent-bridge

Owns Takopi and the Telegram token. It can invoke Codex through a constrained wrapper but cannot read Codex credentials or GitHub App credentials.

### agent

Owns Codex, worktrees, live guidance, and normal development commands. It has internet access. It must not be able to read Telegram or GitHub secrets.

### agent-git

Owns the GitHub App private key. It mints short-lived installation tokens and exposes only the restricted `githubctl` interface.

### rootless Podman

Used for repo command execution where practical. Codex remains on the host; repo commands can be run in containers using `devbox-run`.

### live guidance

`/srv/robokitty-devbox/live/codex` is live-editable by Codex for fast iteration. Periodically sync it back to the infra repo.

## Data/control flow

```text
Telegram message
  -> Takopi reads token and receives update
  -> Takopi starts Codex through /usr/local/lib/robokitty-devbox/wrappers/codex
  -> Codex edits files in a sibling worktree
  -> Codex runs tests, preferably via devbox-run
  -> Codex commits locally
  -> Codex calls githubctl submit
  -> githubctl re-execs as agent-git
  -> agent-git mints GitHub App token
  -> broker safe-squashes diff into a clean clone
  -> broker pushes agent/* branch and opens draft PR
```
