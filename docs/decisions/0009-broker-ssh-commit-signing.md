# ADR 0009: Sign broker commits with a dedicated SSH key

## Status

Accepted.

## Decision

Enable broker-side commit signing by default using a dedicated SSH signing key.
The private key is stored in Ansible Vault and installed only for `agent-git`.
The public key must be added to the separate GitHub agent account as an SSH
signing key.

The Codex runner does not receive the signing private key. Local runner commits
remain intermediate audit material; `githubctl` creates the pushed clean squash
commit and signs that commit before pushing to the agent user's fork.

## Rationale

The broker is the only component that pushes commits to GitHub, so signing at
the broker boundary gives the useful provenance signal without expanding the
Codex runner's secret access. SSH signing is simpler than GPG for an unattended
Ubuntu VPS and is supported by GitHub for commit verification.

## Consequences

The signing key is another secret on the VPS, so it must be dedicated to
signing, vault-backed, file-mode restricted, and rotated if exposed. It should
not be reused as an operator SSH key or GitHub authentication key. Because the
broker is non-interactive, the installed private key must be usable by Git
without prompting for a passphrase.
