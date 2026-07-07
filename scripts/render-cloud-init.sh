#!/usr/bin/env bash
set -euo pipefail

limit=32768
template="docs/cloud-init/cloudflared-bootstrap.yml.example"
output=""
check_template=false

usage() {
  cat >&2 <<'USAGE'
usage:
  scripts/render-cloud-init.sh --check-template
  ROBOKITTY_OPERATOR_SSH_PUBLIC_KEY="..." \
  ROBOKITTY_CLOUDFLARED_TUNNEL_TOKEN="..." \
    scripts/render-cloud-init.sh [--output path] [--limit bytes]

Renders the Cloudflare-first cloud-init user-data from the checked-in example.
The rendered output contains secrets. Write it only to ignored paths or /tmp.
USAGE
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-template)
      check_template=true
      shift
      ;;
    --limit)
      [ "$#" -ge 2 ] || usage
      limit="$2"
      shift 2
      ;;
    --output|-o)
      [ "$#" -ge 2 ] || usage
      output="$2"
      shift 2
      ;;
    --template)
      [ "$#" -ge 2 ] || usage
      template="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[ -r "$template" ] || { echo "error: template not readable: $template" >&2; exit 1; }
[[ "$limit" =~ ^[0-9]+$ ]] || { echo "error: --limit must be an integer" >&2; exit 2; }

template_bytes="$(wc -c < "$template" | tr -d ' ')"
if [ "$template_bytes" -gt "$limit" ]; then
  echo "error: template is ${template_bytes} bytes, over limit ${limit}" >&2
  exit 1
fi

template_text="$(< "$template")"
case "$template_text" in
  "#cloud-config"*) ;;
  *) echo "error: template must start with #cloud-config" >&2; exit 1 ;;
esac

if [ "$check_template" = true ]; then
  grep -q 'REPLACE_WITH_OPERATOR_PUBLIC_KEY' "$template" || {
    echo "error: template is missing operator public key placeholder" >&2
    exit 1
  }
  grep -q 'REPLACE_WITH_CLOUDFLARE_TUNNEL_TOKEN' "$template" || {
    echo "error: template is missing tunnel token placeholder" >&2
    exit 1
  }
  echo "OK: $template is ${template_bytes} bytes, under limit ${limit}"
  exit 0
fi

ssh_key="${ROBOKITTY_OPERATOR_SSH_PUBLIC_KEY:-}"
tunnel_token="${ROBOKITTY_CLOUDFLARED_TUNNEL_TOKEN:-}"

[ -n "$ssh_key" ] || { echo "error: ROBOKITTY_OPERATOR_SSH_PUBLIC_KEY is required" >&2; exit 2; }
[ -n "$tunnel_token" ] || { echo "error: ROBOKITTY_CLOUDFLARED_TUNNEL_TOKEN is required" >&2; exit 2; }
case "$ssh_key" in
  *$'\n'*) echo "error: SSH public key must be one line" >&2; exit 2 ;;
esac
case "$tunnel_token" in
  *$'\n'*) echo "error: tunnel token must be one line" >&2; exit 2 ;;
esac

rendered="${template_text//REPLACE_WITH_OPERATOR_PUBLIC_KEY/$ssh_key}"
rendered="${rendered//REPLACE_WITH_CLOUDFLARE_TUNNEL_TOKEN/$tunnel_token}"

if grep -q 'REPLACE_WITH_' <<<"$rendered"; then
  echo "error: rendered cloud-init still contains an unresolved placeholder" >&2
  exit 1
fi

rendered_bytes="$(printf '%s\n' "$rendered" | wc -c | tr -d ' ')"
if [ "$rendered_bytes" -gt "$limit" ]; then
  echo "error: rendered cloud-init is ${rendered_bytes} bytes, over limit ${limit}" >&2
  exit 1
fi

if [ -n "$output" ]; then
  case "$output" in
    *.generated.yml|*.rendered.yml|*.secret.yml|*.tmp.yml|/tmp/*|/private/tmp/*) ;;
    *)
      echo "error: output path should be ignored or temporary: $output" >&2
      exit 2
      ;;
  esac
  umask 077
  printf '%s\n' "$rendered" > "$output"
  echo "OK: wrote ${rendered_bytes} bytes to $output"
else
  printf '%s\n' "$rendered"
  echo "OK: rendered ${rendered_bytes} bytes, under limit ${limit}" >&2
fi
