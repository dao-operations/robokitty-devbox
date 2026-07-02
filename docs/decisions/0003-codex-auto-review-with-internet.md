# ADR 0003: Use Codex Auto-review with internet access

## Status

Accepted.

## Decision

Use Codex Auto-review / “Approve for me” and enable network access. Do not use full access.

## Rationale

The devbox is for real development work, so Codex needs docs, package registries, GitHub, and public internet. Security comes from denied secret paths, split users, and not placing valuable secrets in the runner user's readable filesystem.
