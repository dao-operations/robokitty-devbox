# ADR 0005: Use rootless Podman for repo commands, not for Codex itself

## Status

Accepted.

## Decision

Install rootless Podman and provide `devbox-run` for repo commands. Keep Codex on the host.

## Rationale

This gives useful isolation for package scripts and builds without creating a full per-repo container platform or complicating Takopi/Codex session handling.
