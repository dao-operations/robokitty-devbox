# Runbook

## 0. Create the repo

Create a new GitHub repository for this skeleton, for example:

```text
robokitty-devbox
```

Push this skeleton to it.

## 1. Create VPS

Production uses Cloudflare-first access. Read `docs/production-bootstrap.md`
before buying the VPS.

Create the Cloudflare Tunnel and Access application first. Configure its SSH
service as `ssh://127.0.0.1:22`. Then create an Ubuntu 24.04 VPS with provider
`cloud-init` user data based on
`docs/cloud-init/cloudflared-bootstrap.yml.example`.

Render the paste-ready user-data locally:

```fish
set -x ROBOKITTY_OPERATOR_SSH_PUBLIC_KEY (cat ~/.ssh/id_ed25519.pub)
set -x ROBOKITTY_CLOUDFLARED_TUNNEL_TOKEN "<cloudflare tunnel token>"
scripts/render-cloud-init.sh --output /tmp/robokitty-cloud-init.generated.yml
```

The helper refuses to render over 32 KiB and refuses non-temporary output paths.

Record in Ansible Vault, not plaintext git:

- Cloudflare SSH hostname,
- bootstrap or production SSH user,
- Cloudflare tunnel token or credentials,
- any private provider notes needed to rebuild the VPS.

The public VPS IP should not be needed for normal SSH or Ansible operation.

## 2. Create Telegram bot

Use BotFather to create a bot. Record:

- bot token,
- numeric user ID,
- chat ID.

Store token, chat ID, and allowed user IDs in Ansible Vault.

## 3. Create GitHub agent user

Create a separate GitHub user for the agent, for example `robokitty-agent`.
This should not be your personal account. Enable 2FA, add a recovery method,
and use an email address you control for notifications and password recovery.

Create a personal access token for that user and store it in Ansible Vault.
Use an expiration date you are comfortable rotating. For public-only work,
grant the narrow public repository scope. For private repositories, grant repo
access only to the repositories or organizations the agent must work with.

The broker uses this token only as `agent-git`. The Codex runner cannot read it
and does not get an authenticated `gh` session.

Do not grant:

```text
Secrets
Environments
Administration
Deployments
Actions write
Workflow write
Delete repo
Organization admin
```

The normal contribution path is fork-based:

1. `githubctl` clones the configured upstream repo.
2. It applies the committed Codex diff as one clean commit.
3. It creates or reuses the agent user's fork.
4. It pushes the `agent/*` branch to that fork.
5. It opens a draft PR against the upstream repo.

For private org repositories, add the agent user as an org member or repo
collaborator with enough access to read the upstream and create PRs from its
fork. If the org enforces SSO for tokens, authorize the token for that org.

Choose a Git author identity for agent commits, for example
`Robokitty Agent <robokitty-agent@example.com>`, and store it in Ansible Vault.

Create a dedicated SSH signing key for broker commits. Do not reuse your
operator SSH key and do not use this key for GitHub authentication. The broker
uses the PAT for GitHub API and push authentication; the SSH key only signs the
clean squash commit.

1Password is fine as the place you create or store this key, but the VPS cannot
depend on your local 1Password SSH agent. Export the dedicated private key into
Ansible Vault, keep it unencrypted inside the vault value so non-interactive Git
signing works, and install the public key on the `robokitty-agent` GitHub
account as an SSH **Signing key**.

Generate a dedicated key locally with OpenSSH if you do not use 1Password:

```fish
ssh-keygen -t ed25519 -C "robokitty-agent signing" -f /tmp/robokitty-agent-signing -N ""
cat /tmp/robokitty-agent-signing.pub
```

In GitHub, log in as the agent user, open **Settings -> SSH and GPG keys**,
choose **New SSH key**, set the type to **Signing key**, and paste the public
key. GitHub documents that SSH keys can be used for commit signing and that an
SSH key used for both authentication and signing must be uploaded twice, once
for each type.

## 4. Configure inventory

For production, use a checked-in inventory with aliases and no public IPs.
Keep deployment-specific values in committed encrypted vault files.

Example production inventory shape:

```yaml
---
all:
  children:
    robokitty_devboxes:
      hosts:
        robokitty-devbox-01:
```

Create and edit the encrypted vault:

```bash
ansible-vault create inventories/production/group_vars/robokitty_devboxes/vault.yml
```

Required GitHub values in that vault:

```yaml
vault_robokitty_github_token: "github_pat_..."
# Optional fail-closed assertion. Leave empty to derive the contribution owner
# from the GitHub PAT login.
vault_robokitty_github_expected_owner: ""
vault_robokitty_git_user_name: Robokitty Agent
vault_robokitty_git_user_email: robokitty-agent@example.com
vault_robokitty_git_signing_private_key_pem: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
vault_robokitty_git_signing_public_key: "ssh-ed25519 AAAA... robokitty-agent signing"
```

The broker derives the contribution owner from the GitHub login authenticated by
`vault_robokitty_github_token`. Set
`vault_robokitty_github_expected_owner` only if you want the playbook to render
a fail-closed runtime assertion that the PAT belongs to a specific GitHub login.

Commit the encrypted vault file after confirming it starts with
`$ANSIBLE_VAULT`. Do not commit decrypted vault files, temporary plaintext
copies, `.vault-pass`, or private SSH keys.

Edit repo routing in
`inventories/production/group_vars/robokitty_devboxes/vars.yml` unless the repo
names or clone URLs are sensitive enough to vault. The checked-in `owner` and
`repo` fields are the upstream PR target. The fork owner is the authenticated
GitHub PAT login reported by `githubctl status`.

The production default keeps `robokitty_repos` empty and configures only the
`robokitty-infra` alias for this repository. Use that alias for the first
bootstrap smoke. Add target application repos only after the base devbox is
healthy:

```yaml
robokitty_repos:
  - alias: app
    owner: upstream-owner
    repo: upstream-repo
    default_branch: main
    clone_url: https://github.com/upstream-owner/upstream-repo.git
    path: /srv/robokitty-devbox/work/upstream-repo
    allowed_base_branches:
      - main
    allow_push: true
    allow_pr_create: true
    container_image: docker.io/library/node:22-bookworm
    # Optional. Use a safe relative path for monorepos, for example frontend.
    container_workdir: .
```

`inventories/local/` remains available for throwaway local experiments and is
ignored by git.

## 5. Run Ansible

```bash
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --syntax-check
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --check --ask-vault-pass
ansible-playbook -i inventories/production/hosts.yml playbooks/robokitty_devbox.yml --ask-vault-pass
```

## 6. Log in to Codex

```bash
ssh robokitty-devbox
sudo -iu agent
codex login --device-auth
```

The SSH alias should route through Cloudflare Access with `cloudflared access ssh`.
The phone is not part of this path; it talks to Telegram, and Takopi talks
outbound to Telegram from the VPS.

## 7. Validate boundaries

```bash
robokitty-status
robokitty-security-check
githubctl audit --limit 20 --format json
```

`robokitty-security-check` must confirm that the runner can read only the
non-secret repo routing config, uses its primary group for broker handoff, and
can reach the specific GitHub broker Unix socket. It must also
confirm that the GitHub broker daemon is active, the broker socket is owned by
`agent-git:agent`, the broker exchange directory is owned by
`agent:agent` under `/var/lib/robokitty-devbox`, the infra worktree source
directory is runner-writable under `/var/lib/robokitty-devbox/worktree-sources`,
managed long-running services hide cross-user process lists, the legacy
in-workdir exchange directory is absent, Takopi Codex wrapper launches the
runner without overriding its primary group, and `requirements.toml` contains
no `allow` rules.

## 8. First Telegram test

Generate the concrete prompt from live repo config:

```bash
robokitty-bootstrap-task <repo-alias>
```

After Ansible changes Codex or Takopi configuration, restart Takopi before
rerunning the Telegram smoke and use `/new` in Telegram to avoid reusing a
Codex app-server thread with stale sandbox state:

```bash
sudo systemctl restart takopi
```

Before sending it, run:

```bash
robokitty-status
robokitty-security-check
githubctl status --repo <repo-alias> --format json
```

`githubctl status` must report `"ok": true`. Its `authenticated_login` is the
derived contribution owner and fork owner. If `expected_owner_matches_token` is
false, update `vault_robokitty_github_expected_owner`, leave it empty, or
replace the PAT with one from the expected GitHub login before running the
Telegram smoke.

Then send the generated Telegram message. It will look like:

```text
/<repo-alias>
Create a tiny README.md or docs/ change on branch agent/bootstrap-test.
Use the managed worktree helper and stop if it fails.
Run lightweight checks, including git diff --check.
Commit locally for review.
Create PR_BODY.md and leave it untracked.
Submit a draft PR using githubctl.
Report the PR URL.
Do not merge.
```

Do not include `@agent/bootstrap-test` on the directive line for this smoke.
Takopi would try to create the worktree as `agent-bridge`; the prompt asks
Codex to create the runner-owned worktree with `robokitty-new-worktree`.
The bootstrap task is intentionally docs-only, so `git diff --check` is enough
for this smoke. For real infra changes touching playbooks, roles, templates,
scripts, broker behavior, sudoers, systemd units, Podman runner behavior, or
Codex permission/guidance wiring, require `make ci` locally in the managed
worktree before `githubctl submit`.

The expected result is a draft PR from the agent user's fork, with an
`agent/bootstrap-test` branch as the PR head, and a Telegram summary that
includes the branch, PR URL, changed files, commands run, check status, risks,
and next step.

## 9. Weekly drift sync

```bash
robokitty-drift-report || true
robokitty-sync-live-to-infra agent/sync-live-guidance-YYYY-MM-DD main
```

The sync helper accepts only `codex/AGENTS.md` and
`codex/skills/<skill-name>/SKILL.md`, creates or reuses a managed infra
worktree under `/srv/robokitty-devbox/work`, and leaves the canonical infra
checkout clean. Commit the worktree changes under `codex/`, then submit them
with `githubctl`.
