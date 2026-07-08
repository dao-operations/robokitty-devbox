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
one root-owned sudo command. The wrapper requires the triggering commit SHA and
rejects malformed or stale branch-head input:

```text
/usr/local/bin/robokitty-deploy-infra
```

The wrapper does not deploy from `$GITHUB_WORKSPACE`. It fetches the configured
protected branch into an `agent-deploy`-owned checkout, verifies that
`origin/<branch>` still equals the workflow's triggering SHA, validates that the
checkout is clean, installs exact-pinned Ansible collections into a root-owned
cache, runs a syntax check with the vault password file, and then applies the
production playbook through a local connection. It invokes Ansible with a
scrubbed environment and a root-owned `ANSIBLE_CONFIG` so caller workspaces and
environment variables cannot supply Ansible plugin or config paths. The sudo
handoff for `agent-actions` also uses per-user environment reset, deletes shell
startup environment variables, and pins `secure_path`; the wrapper itself uses
an absolute shell interpreter and sets its own fixed `PATH` before privileged
work.

The deploy path is disabled by default. Enabling it requires:

- an explicit `host-resident-vault-password` custody acknowledgement,
- an explicit acknowledgement that GitHub branch/environment/runner controls
  are configured,
- an explicit repository visibility acknowledgement, normally `private-repo`,
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
- Deployment is bound to the workflow's triggering SHA and fails if the branch
  head changes before the wrapper runs.
- Cloudflare-first ingress remains unchanged; the runner is outbound-only.

Required GitHub-side controls before enablement:

- make the infra repository private before enablement, or explicitly accept
  public-repository runner risk only for a time-boxed pilot,
- run deploy only on `push` to the protected upstream branch,
- do not run deploy jobs for pull requests, forks, `pull_request_target`,
  issue-comment triggers, or untrusted `workflow_run` paths,
- use a dedicated self-hosted runner label,
- restrict the runner to the infra repository or a narrow runner group,
- require CODEOWNERS review for workflows, Ansible, inventories, deploy wrapper,
  and sudoers paths,
- require a protected Environment reviewer as a second deploy approval,
- use minimal `GITHUB_TOKEN` permissions,
- pin all actions to reviewed full-length commit SHAs.

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
  it cannot choose arbitrary workspaces, playbooks, or vault files, and the
  wrapper rejects non-SHA or stale-SHA input.
- A runner registration credential exists under `agent-actions`.
- The persistent runner program directory remains writable by the job user in
  this pilot, so a private repository and reviewed workflow triggers are part
  of the intended enablement boundary.
- The long-lived runner cannot use `NoNewPrivileges=true` because it must cross
  a narrow sudo boundary. Moving deploy triggering to a dedicated broker or
  systemd oneshot would allow stronger service hardening later.

Rejected:

- Running the self-hosted runner as the vault-owning deploy user. This would let
  arbitrary workflow commands read the vault password directly.
- Letting Codex call the deploy wrapper. This would collapse the review/merge
  approval boundary.
- Adding a webhook listener. It is unnecessary and would weaken the
  Cloudflare-first ingress posture.
