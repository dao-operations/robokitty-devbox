# Self-hosted Deploy Runner

This optional pilot lets a reviewed merge to the infra repository deploy the
devbox from the VPS itself.

The short answer to the Cloudflare question: the box being reachable only
through `cloudflared` is compatible with this design. The GitHub Actions runner
connects outbound to GitHub over HTTPS. No inbound webhook port, public SSH
rule, or provider firewall opening is required.

## Boundary

Users:

- `agent` runs Codex and cannot read deploy secrets or invoke deploy.
- `agent-actions` runs the GitHub Actions runner and can invoke only the fixed
  deploy wrapper through sudo.
- `agent-deploy` owns the vault password and clean deploy checkout.

The deploy wrapper:

- requires exactly one lowercase 40-character commit SHA argument,
- rejects unexpected sudo callers,
- ignores `$GITHUB_WORKSPACE`,
- fetches the configured protected branch into an `agent-deploy` checkout,
- verifies `origin/<branch>` still matches the triggering SHA and the checkout
  is clean,
- runs through an `agent-actions` sudo rule with environment reset and a fixed
  command search path,
- runs Ansible with a scrubbed environment and root-owned deploy config,
- uses a vault password file under `agent-deploy`,
- runs Ansible with local connection against the production inventory.

## Enablement

The feature is off unless vault-backed inventory enables it:

```yaml
vault_robokitty_deploy_runner_enabled: true
vault_robokitty_deploy_runner_secret_custody_ack: host-resident-vault-password
vault_robokitty_deploy_runner_github_controls_ack: protected-branch-environment-runner-scope
vault_robokitty_actions_runner_package_url: https://github.com/actions/runner/releases/download/vX.Y.Z/actions-runner-linux-x64-X.Y.Z.tar.gz
vault_robokitty_actions_runner_package_checksum: sha256:<release-sha256>
vault_robokitty_actions_runner_registration_token: <short-lived-registration-token>
vault_robokitty_deploy_runner_vault_password: <ansible-vault-password>
```

Use a fresh GitHub runner registration token when the runner has not already
been configured. The token is short-lived; after the runner is configured,
future Ansible applies can keep the stored value non-empty even if it has
expired, because registration is skipped when `.runner` already exists.

Apply once from the operator machine:

```bash
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --check --ask-vault-pass
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --ask-vault-pass
```

Then validate:

```bash
robokitty-security-check
systemctl status robokitty-actions-runner
```

## GitHub Workflow

The current `githubctl` broker blocks workflow file edits. Add the real
workflow through a human-controlled GitHub path, or make a later explicit ADR
and broker-policy change to allow agent-authored workflow updates.

Template:

```yaml
name: Robokitty Infra Deploy

"on":
  push:
    branches:
      - master

permissions:
  contents: read

concurrency:
  group: robokitty-infra-deploy
  cancel-in-progress: false

jobs:
  deploy:
    name: Validate and deploy
    runs-on:
      - self-hosted
      - robokitty-devbox
      - infra-deploy
    environment: robokitty-devbox
    timeout-minutes: 60
    steps:
      - name: Check out reviewed branch
        # Pin actions to reviewed full-length commit SHAs before enabling.
        uses: actions/checkout@<full-length-commit-sha>
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Install validation tools
        run: make install-dev

      - name: Validate
        run: make ci

      - name: Deploy
        run: sudo -n /usr/local/bin/robokitty-deploy-infra "$GITHUB_SHA"
```

Hard GitHub enablement requirements:

- protect `master` and require PR review before merge,
- require CODEOWNERS review for `.github/workflows/**`, Ansible roles,
  inventory, deploy wrapper templates, and sudoers templates,
- do not allow the deploy workflow on PR, fork, `pull_request_target`,
  issue-comment, or untrusted `workflow_run` events,
- restrict the self-hosted runner to this repository or a tightly scoped runner
  group,
- use a unique label set such as `robokitty-devbox` and `infra-deploy`,
- use a GitHub Environment with required reviewers as a second explicit deploy
  approval after merge,
- keep `GITHUB_TOKEN` permissions minimal,
- pin all actions, including GitHub-owned actions, to reviewed full-length
  commit SHAs.

Ansible Galaxy collections are deploy code. `requirements.yml` must use exact
collection versions and allowlisted sources; the deploy wrapper rechecks that
policy before installing collections. Tasks that handle decrypted vault values
must use `no_log: true`, because deploy logs are root-only but still durable.

## Operations

The deploy log directory is:

```text
/var/log/robokitty-devbox/deploy
```

To disable automated deployment:

1. Remove or disable the GitHub workflow.
2. Set `vault_robokitty_deploy_runner_enabled: false`.
3. Apply Ansible from the operator machine.
4. Remove the runner from GitHub repository settings if it should no longer
   connect.

To rotate the vault password:

1. Rekey the encrypted vault from the operator machine.
2. Update `vault_robokitty_deploy_runner_vault_password`.
3. Apply Ansible from the operator machine.
4. Run `robokitty-security-check`.
