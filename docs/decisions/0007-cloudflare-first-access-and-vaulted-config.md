# ADR 0007: Use Cloudflare-first SSH access and committed encrypted vault config

## Status

Accepted.

## Decision

Use Cloudflare Tunnel plus Cloudflare Access as the production administrative SSH path for the devbox. Production Ansible should connect through the Cloudflare Access hostname, not through a public VPS SSH port.

Store deployment-specific sensitive and private-ish values in Ansible Vault files that may be committed to this repository only while encrypted. Do not commit decrypted vault material or vault passwords.

## Rationale

The operator already has Cloudflare Zero Trust and a domain. Cloudflare Access avoids the Tailscale plus local VPN interaction concern and removes the need to expose SSH on the public internet during steady state.

Committed encrypted vault files make the deployment reconstructible from the public repo without leaking plaintext IPs, chat IDs, tunnel tokens, GitHub PATs, or repository configuration. This keeps human-controlled production values available for backup while allowing agents to maintain variable references and validation without knowing the values.

## Consequences

The first VPS boot needs a bootstrap path for `cloudflared`, because Ansible needs a transport before it can apply the role. The preferred bootstrap is provider `cloud-init` or a provider console command that installs `cloudflared` and starts the tunnel before any public SSH exposure is required.

Ansible Vault ciphertext in a public repository can be attacked offline. The vault password must be high entropy and stored outside git. Rekeying a vault does not remove old ciphertext from git history, so mistakenly committed decrypted files or weak vault passwords remain serious incidents.

Agents and CI can run syntax and example-inventory checks without the vault password. A human with vault access remains responsible for production check and apply runs.
