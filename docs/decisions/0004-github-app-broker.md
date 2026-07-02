# ADR 0004: Use a GitHub App broker instead of direct authenticated gh

## Status

Accepted.

## Decision

Codex may not use an authenticated GitHub CLI directly. It uses `githubctl`, which runs as `agent-git`, mints short-lived GitHub App installation tokens, and exposes a narrow allowlist of operations.

## Rationale

This mirrors the future production capability-gateway model: the agent can request actions without reading the credential that performs them.
