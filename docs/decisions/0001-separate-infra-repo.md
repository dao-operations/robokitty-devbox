# ADR 0001: Use a separate robokitty-devbox infra repo

## Status

Accepted.

## Decision

Keep this pilot out of the production/company Ansible repository.

## Rationale

The devbox is an experiment. It should evolve quickly without touching unrelated production automation. A separate repo lets Codex propose changes to its own operating model while the human operator controls vault secrets and Ansible deployment.
