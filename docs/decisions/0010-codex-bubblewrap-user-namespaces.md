# ADR 0010: Enable user namespaces for Codex bubblewrap

## Status

Accepted.

## Decision

Configure the Ubuntu host so the Codex runner can start its `bubblewrap`
sandbox. The playbook enables unprivileged user namespace cloning, sets a
minimum `user.max_user_namespaces` value, and installs an AppArmor profile for
`/usr/bin/bwrap` with the `userns` permission on Ubuntu systems that enforce
restricted unprivileged user namespaces.

Do not disable the Codex sandbox and do not use `danger-full-access`.

## Rationale

Codex command execution fails before shell startup if `bubblewrap` cannot create
the user namespace it needs. That failure blocks Telegram-to-Codex bootstrap
tasks even though Takopi, Codex login, Cloudflare access, and GitHub broker
configuration are otherwise working.

Unprivileged user namespaces increase kernel attack surface, so this is a real
security tradeoff. The narrower AppArmor profile follows Ubuntu's per-application
allowance model and is preferable to globally disabling AppArmor's user namespace
restriction. The remaining controls are split Unix users, secret file modes,
Codex permission requirements, the restricted GitHub broker, and the
`robokitty-security-check` bubblewrap probe.
