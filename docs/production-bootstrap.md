# Production Bootstrap

This is the intended path from a fresh Ubuntu 24.04 VPS to a locked-down Robokitty devbox.

## Target posture

- Ubuntu 24.04 VPS.
- No public SSH dependency in steady state.
- Cloudflare Tunnel publishes SSH at a private hostname such as `ssh.example.com`.
- Cloudflare Access protects that hostname with an allow policy for the operator identity.
- Local admin and Ansible SSH use `cloudflared access ssh` as the SSH proxy command.
- Provider firewall denies inbound traffic where the provider supports it.
- SSHD listens on `127.0.0.1` in production mode; Cloudflare Tunnel forwards to it locally.
- Host UFW defaults to deny inbound and does not allow world-open SSH.
- Takopi receives Telegram updates outbound; phones do not connect to the VPS.

## Bootstrap reality

Ansible still needs an SSH transport. If public SSH is closed from the start, the VPS must run `cloudflared` before the first Ansible run.

Preferred bootstrap:

1. Create the Cloudflare Tunnel and Access application before buying or booting the VPS.
2. Put the tunnel token or credentials in Ansible Vault, and also use them in the provider `cloud-init` user data for first boot.
3. Boot the VPS with user data that installs `cloudflared`, starts the tunnel, and installs the operator SSH public key.
4. Keep the provider firewall closed to inbound SSH.
5. Run Ansible through the Cloudflare Access hostname.

Use `docs/cloud-init/cloudflared-bootstrap.yml.example` as the first-boot shape.
The real user-data contains a tunnel token and public key, so do not commit a
filled copy.

The checked-in template is intentionally small enough for providers with a
32 KiB cloud-init limit. Verify or render it with:

```fish
make cloud-init-check
set -x ROBOKITTY_OPERATOR_SSH_PUBLIC_KEY (cat ~/.ssh/id_ed25519.pub)
set -x ROBOKITTY_CLOUDFLARED_TUNNEL_TOKEN "<cloudflare tunnel token>"
scripts/render-cloud-init.sh --output /tmp/robokitty-cloud-init.generated.yml
```

Provider user-data commonly remains visible in provider metadata and local
cloud-init state. Treat the first-boot tunnel token as a bootstrap credential:
after Ansible has applied the managed token file, rotate or refresh the tunnel
token from Cloudflare if the dashboard supports it for your tunnel type.

Break-glass bootstrap options:

- Use the provider console if `cloud-init` fails.
- Temporarily open SSH only from the operator's current IP, apply the playbook, then close it and rotate any exposed bootstrap credentials.
- Destroy and rebuild the VPS if first boot is questionable. This is often cleaner than debugging a half-bootstrapped host.

## Cloudflare setup

Create a tunnel in Cloudflare Zero Trust. Publish an SSH application hostname, for example:

```text
Hostname: ssh.example.com
Service: ssh://127.0.0.1:22
```

Add a Cloudflare Access self-hosted application for that hostname. For the pilot, allow only the operator identity and require MFA if available.

On the operator machine, install `cloudflared` and configure SSH:

```sshconfig
Host robokitty-devbox
  HostName ssh.example.com
  User root
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

Then test:

```bash
ssh robokitty-devbox
```

For Codex App SSH projects, configure a separate alias that logs in directly as
the Codex runner user. Store the matching public key in the encrypted vault as
`vault_robokitty_runner_ssh_authorized_keys`; the checked-in production vars
map that vault value into `robokitty_runner_ssh_authorized_keys`.

```sshconfig
Host robokitty-agent
  HostName ssh.example.com
  User agent
  IdentityFile ~/.ssh/robokitty_agent_codex_app
  IdentitiesOnly yes
  ForwardAgent no
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

Then test:

```bash
ssh robokitty-agent
```

For Ansible, the production inventory should use the Cloudflare hostname or SSH alias. The public VPS IP should not be needed for normal operation.

## Vault policy

Committed encrypted vault files are acceptable for this project if all of these are true:

- The file is encrypted with Ansible Vault before commit.
- The vault password is high entropy and never committed.
- Decrypted vault files, temporary plaintext copies, and editor backups are never committed.
- The operator understands that public ciphertext can be attacked offline forever.

Put these values in vault:

- Cloudflare tunnel token or credentials.
- Cloudflare SSH hostname if the operator wants it private.
- Initial or production Ansible host/user values.
- Public SSH keys allowed to log in directly as the Codex runner user for
  Codex App SSH projects.
- Telegram bot token, chat ID, and allowed user IDs.
- GitHub PAT for the separate agent identity.
- Optional expected GitHub login for that PAT.
- Git commit author name and email for commits created by the agent.
- SSH commit signing private and public key for commits created by the broker.
- Any private notes needed to rebuild the VPS.

Keep repo routing config in checked-in production group vars unless the repo
names or clone URLs are themselves sensitive. This lets Codex propose routing
changes without needing vault access.

Do not put the Ansible Vault password in this repo. Prefer storing the operator SSH private key in a password manager, not in this public repository, even if encrypted.

## Repository config shape

Production inventory should contain stable aliases, not public IPs:

```yaml
---
all:
  children:
    robokitty_devboxes:
      hosts:
        robokitty-devbox-01:
```

Group vars can refer to vault-backed values:

```yaml
ansible_host: "{{ vault_robokitty_cloudflare_ssh_hostname }}"
ansible_user: "{{ vault_robokitty_ansible_user | default('root') }}"
ansible_ssh_common_args: >-
  -o ProxyCommand="/usr/local/bin/cloudflared access ssh --hostname %h"
```

The checked-in production inventory under `inventories/production/` follows this
pattern. Create the real encrypted vault at:

```text
inventories/production/group_vars/robokitty_devboxes/vault.yml
```

The agent can maintain the playbook and variable names without seeing the vault values. Production check and apply runs remain human-operated:

```bash
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --check --ask-vault-pass
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --ask-vault-pass
```

## Hardening expected from the playbook

The playbook should own the host baseline after the bootstrap transport exists:

- UFW deny incoming, allow outgoing, and no world-open SSH.
- SSHD restricted to loopback in Cloudflare production mode.
- SSH password login disabled.
- Fail2ban installed even though public SSH should not be exposed.
- Unattended upgrades installed.
- Dedicated Unix users for bridge, Codex runner, and GitHub broker.
- Secret files owned by non-runner users with owner-only permissions.
- Codex permission profile without `danger-full-access`.
- Codex/bubblewrap user namespace prerequisites for the non-full-access sandbox.
- `githubctl` restricted operations and audit trail.
- Rootless Podman runner without host secret mounts.
- `robokitty-security-check` validation.

This is a practical production pilot baseline, not a perfect host-hardening proof. Residual risks should stay explicit in `docs/security-model.md`.

## Telegram and phone path

The phone does not SSH, VPN, or connect to the VPS. The phone sends Telegram messages. Takopi runs on the VPS as `agent-bridge`, talks outbound to Telegram, and starts Codex locally through the constrained wrapper.

Cloudflare Access is for human administrative SSH and Ansible transport from the operator machine.

## Operating decisions

Telegram topics:

- Use later when one group has multiple repos, projects, or long-running task threads.
- Leave disabled for first production unless the chat becomes noisy.

Multi-user Telegram routing:

- Means allowing more Telegram user IDs and possibly routing users or projects into different topics.
- Keep single-operator for first production. Every allowed user can influence the agent, so adding users is a security decision.

Dedicated ChatGPT workspace identity:

- Means logging the VPS Codex runner into a dedicated ChatGPT account or workspace identity rather than a personal everyday identity.
- Recommended before real production work if available. It improves auditability and limits account blast radius.
- It can be deferred for the first private smoke test if account setup would block deployment.

## References

- Cloudflare Tunnel SSH use case: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/
- Cloudflare client-side `cloudflared` SSH: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/
- Ansible Vault guide: https://docs.ansible.com/ansible/latest/vault_guide/index.html
