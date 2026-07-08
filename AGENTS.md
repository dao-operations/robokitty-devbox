# Instructions for agents working on robokitty-devbox

This repository defines the infrastructure and operating model for an Ubuntu VPS agent devbox.

## Mission

Implement a small, auditable, security-conscious remote development box using Ansible, Codex, Takopi, rootless Podman, and a restricted GitHub broker for a separate agent identity.

## Hard rules

- Do not commit real secrets.
- Do not add Terraform.
- Do not add Kubernetes.
- Do not add MCP.
- Do not configure Codex `danger-full-access`.
- Do not give the Codex runner user direct access to the Telegram token, GitHub PAT, or Git signing private key.
- Do not give the Codex runner user a persistent GitHub token.
- Do not implement GitHub merge, workflow dispatch, secrets, admin, or arbitrary API passthrough in P0.
- Keep Ansible idempotent.
- Keep this repo Ubuntu 24.04-focused.
- Prefer explicit validation and fail-closed behavior.

## Work style

- Read `docs/workpackages.md` before making changes.
- Keep each PR/worktree focused on one workpackage.
- Update docs when changing architecture.
- If a decision changes, add or update an ADR under `docs/decisions/`.
- Treat `roles/robokitty_devbox/templates/githubctl.py.j2` and sudoers templates as security-sensitive.
- Run syntax checks where possible.

## Validation commands

Preferred local validation uses the repo Makefile and `uv`:

```bash
make ci
```

For a lightweight syntax-only check:

```bash
ansible-playbook -i inventories/example/hosts.yml playbooks/robokitty_devbox.yml --syntax-check
```

When implementation is far enough along, use:

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/robokitty_devbox.yml --check --ask-vault-pass
ansible-playbook -i inventories/local/hosts.yml playbooks/robokitty_devbox.yml --ask-vault-pass
```

## Security-review trigger

Ask a reviewer agent to inspect any change touching:

- sudoers,
- systemd units,
- GitHub broker,
- token handling,
- file permissions,
- Codex permission profiles,
- Podman volume mounts,
- scripts in `/usr/local/bin`.
