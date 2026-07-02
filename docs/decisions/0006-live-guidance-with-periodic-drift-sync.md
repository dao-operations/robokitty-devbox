# ADR 0006: Allow live guidance edits with periodic drift sync

## Status

Accepted.

## Decision

Codex may edit non-secret live guidance under `/srv/robokitty-devbox/live/codex`. Periodically sync those changes back to this repo and submit PRs.

## Rationale

Requiring a PR and Ansible run for every guidance tweak is too slow. Live edits improve iteration speed. The infra repo remains the reviewed canonical record after periodic reconciliation.
