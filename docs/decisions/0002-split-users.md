# ADR 0002: Split Unix users for bridge, runner, and GitHub broker

## Status

Accepted.

## Decision

Use:

- `agent-bridge` for Takopi and Telegram token,
- `agent` for Codex and worktrees,
- `agent-git` for the separate GitHub identity PAT and authenticated GitHub actions.

## Rationale

Codex should not be able to read Telegram or GitHub credentials. OS-level file permissions are the simplest useful security boundary for P0.
