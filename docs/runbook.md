# Runbook

## 0. Create the repo

Create a new GitHub repository for this skeleton, for example:

```text
robokitty-devbox
```

Push this skeleton to it.

## 1. Create VPS

Create an Ubuntu 24.04 VPS manually. Record:

- public IP,
- initial SSH user,
- SSH key path.

## 2. Create Telegram bot

Use BotFather to create a bot. Record:

- bot token,
- numeric user ID,
- chat ID.

Store token in Ansible Vault.

## 3. Create GitHub App

Create a GitHub App named something like `robokitty-devbox`.

P0 permissions:

```text
Contents: read/write
Pull requests: read/write
Metadata: read-only
Checks: read-only optional
Commit statuses: read-only optional
```

Do not grant:

```text
Secrets
Environments
Administration
Deployments
Actions write
```

Install the App only on target repos. Download the private key and store it outside git or in Ansible Vault.

## 4. Configure inventory

```bash
mkdir -p inventories/local group_vars/robokitty_devboxes
cp inventories/example/hosts.yml inventories/local/hosts.yml
cp group_vars/robokitty_devboxes/robokitty_devbox.yml.example group_vars/robokitty_devboxes/robokitty_devbox.yml
cp group_vars/robokitty_devboxes/vault.yml.example group_vars/robokitty_devboxes/vault.yml
```

Edit values.

Vault secrets:

```bash
ansible-vault encrypt group_vars/robokitty_devboxes/vault.yml
```

## 5. Run Ansible

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/robokitty_devbox.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/robokitty_devbox.yml --check --ask-vault-pass
ansible-playbook -i inventories/local/hosts.yml playbooks/robokitty_devbox.yml --ask-vault-pass
```

## 6. Log in to Codex

```bash
ssh <host>
sudo -iu agent
codex login --device-auth
```

If needed, use SSH local forwarding for browser login.

## 7. Validate boundaries

```bash
robokitty-status
robokitty-security-check
```

## 8. First Telegram test

Send:

```text
/<repo-alias> @agent/bootstrap-test
Create a tiny documentation-only change on branch agent/bootstrap-test.
Run lightweight checks.
Commit locally.
Create PR_BODY.md.
Submit a draft PR using githubctl.
Report the PR URL.
Do not merge.
```

Production smoke status on 2026-07-07:

- Telegram-launched Codex submitted a draft PR through `githubctl`.
- Successful smoke PR: https://github.com/dao-operations/robokitty-devbox/pull/2
- `githubctl pr checks` returned `ok` with an empty checks list, so no GitHub CI signal is configured yet.
- This validates the local Telegram -> Codex -> `githubctl` broker -> GitHub PR path, but not repository CI.

## 9. Weekly drift sync

```bash
robokitty-drift-report || true
robokitty-sync-live-to-infra
```

Then submit a PR for changes under `codex/`.
