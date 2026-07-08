# ADR 0008: Use a third GitHub identity with a restricted broker

## Status

Accepted.

## Decision

Use a separate GitHub user, such as `robokitty-agent`, for brokered GitHub
operations. Store that user's PAT under `agent-git` with owner-only
permissions. Codex uses `githubctl`; it does not receive the PAT or an
authenticated GitHub CLI session. The broker derives the contribution owner and
fork owner from the PAT's authenticated GitHub login at runtime; an optional
expected-owner setting can fail closed if the wrong PAT is installed.

For submissions, `githubctl` creates a clean squash commit from the runner's
prepared diff, pushes the `agent/*` branch to the separate identity's fork, and
opens a draft PR against the configured upstream repository.

## Rationale

This keeps one contribution model across owned repos, external org repos, and
open-source upstreams. The agent identity is visible in commits and PR activity,
while the human operator can review, discuss, and merge separately. It also
avoids requiring every upstream organization to install a GitHub App before the
agent can contribute.

## Consequences

The PAT is broader and longer-lived than GitHub App installation tokens, so it
must be stored only under `agent-git`, rotated on a schedule, and scoped as
narrowly as GitHub permits for the target repositories. The broker remains
narrow: no merge, workflow dispatch, workflow file edits, secrets, admin, or
arbitrary API passthrough in P0.
