# ADR 0012: Self-hosted deploy runner pilot

## Status

Accepted for pilot implementation. Production use requires explicit operator
enablement in vault-backed inventory values.

## Context

Robokitty should be able to propose infrastructure changes, open a PR, and
update the devbox after the operator approves and merges that PR. The desired
operator experience is phone-friendly: review the PR, merge it, and let the
box apply the reviewed upstream branch without a separate laptop Ansible run.

The existing security model deliberately keeps the Ansible Vault password with
the human operator. Moving deployment onto the VPS changes that model: a
server-side deploy path must be able to decrypt the vault at apply time.

The VPS is Cloudflare-first. It does not expose public SSH in steady state.
GitHub's self-hosted runner does not require inbound connectivity; it opens
outbound HTTPS connections to GitHub. Therefore this design must not add
webhook listeners, public SSH allowances, or provider firewall openings.

The existing GitHub broker also intentionally denies workflow file edits and
workflow dispatch. This ADR does not relax that policy. The initial workflow
bootstrap remains a human-authored GitHub-side change or a later explicitly
reviewed policy change.

## Decision

Add an optional self-hosted deploy runner with two Unix users:

- `agent-actions` runs the GitHub Actions self-hosted runner service.
- `agent-deploy` owns the deploy vault password and the clean deploy checkout.

`agent-actions` cannot read the vault password, cannot write the deploy
checkout, and is not in the Codex or GitHub broker handoff path. It may invoke
one root-owned sudo command with no arguments:

```text
/usr/local/bin/robokitty-deploy-infra
```

The wrapper does not deploy from `$GITHUB_WORKSPACE`. It fetches the configured
protected branch into an `agent-deploy`-owned checkout, verifies that the
checkout is clean and matches `origin/<branch>`, installs Ansible collections
into a root-owned cache, runs a syntax check with the vault password file, and
then applies the production playbook through a local connection.

The deploy path is disabled by default. Enabling it requires:

- an explicit `host-resident-vault-password` custody acknowledgement,
- a checksummed GitHub Actions runner package URL,
- a runner registration token,
- a vault password value or source file,
- fixed repository, branch, inventory, and playbook paths.

## Security Model

This is not a claim that Codex can cryptographically never influence secrets.
After merge, reviewed infra code is root-equivalent because Ansible applies it
with vault access. The security claim is narrower:

- Codex cannot directly read the vault password.
- Codex cannot directly invoke deployment.
- GitHub job code cannot directly read the vault password because it runs as
  `agent-actions`, not `agent-deploy`.
- Deployment uses reviewed upstream branch state, not the mutable Actions
  workspace.
- Cloudflare-first ingress remains unchanged; the runner is outbound-only.

Required GitHub-side controls:

- run deploy only on `push` to the protected upstream branch,
- do not run deploy jobs for pull requests or forks,
- use a dedicated self-hosted runner label,
- restrict the runner to the infra repository or a narrow runner group,
- use minimal `GITHUB_TOKEN` permissions,
- pin third-party actions,
- prefer a protected Environment with required reviewers if a second deploy
  approval is desired.

## Consequences

Positive:

- Merging a reviewed PR can update the devbox without a laptop deploy.
- CI and deployment use the VPS's persistent caches and larger resources.
- GitHub does not hold the Ansible Vault password.
- Cloudflare-only access remains compatible.

Negative:

- The VPS now holds deploy capability.
- A malicious reviewed merge can exfiltrate decrypted secrets through Ansible.
- A compromise of `agent-actions` can trigger the fixed deploy wrapper, though
  it cannot choose arbitrary arguments, workspaces, playbooks, or vault files.
- A runner registration credential exists under `agent-actions`.

Rejected:

- Running the self-hosted runner as the vault-owning deploy user. This would let
  arbitrary workflow commands read the vault password directly.
- Letting Codex call the deploy wrapper. This would collapse the review/merge
  approval boundary.
- Adding a webhook listener. It is unnecessary and would weaken the
  Cloudflare-first ingress posture.
