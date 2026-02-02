#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-}"
openai_key_file="${2:-}"
anthropic_key_file="${3:-}"

if [ -z "$output_path" ] || [ -z "$openai_key_file" ] || [ -z "$anthropic_key_file" ]; then
  echo "pi-auth: usage: pi-auth <output> <openai_key_file> <anthropic_key_file>" >&2
  exit 1
fi

read_secret() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "pi-auth: secret not found: $path" >&2
    exit 1
  fi
  local value
  value="$(cat "$path")"
  if [ -z "$value" ]; then
    echo "pi-auth: secret empty: $path" >&2
    exit 1
  fi
  printf '%s' "$value"
}

openai_key="$(read_secret "$openai_key_file")"
anthropic_key="$(read_secret "$anthropic_key_file")"

install -d -m 0700 "$(dirname "$output_path")"

umask 077

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

jq -n \
  --arg openai "$openai_key" \
  --arg anthropic "$anthropic_key" \
  '{
    openai: { type: "api_key", key: $openai },
    "openai-codex": { type: "api_key", key: $openai },
    anthropic: { type: "api_key", key: $anthropic }
  }' > "$tmp_file"

chmod 0600 "$tmp_file"

mv "$tmp_file" "$output_path"
