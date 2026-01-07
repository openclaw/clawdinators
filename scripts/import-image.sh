#!/usr/bin/env bash
set -euo pipefail

image_url="${1:-}"
if [ -z "${image_url}" ]; then
  echo "Usage: import-image.sh <image-url>" >&2
  exit 1
fi

name="${IMAGE_NAME:-clawdinator-nixos-$(date -u +%Y%m%d-%H%M%S)}"
description="${IMAGE_DESCRIPTION:-CLAWDINATOR NixOS image}"

hcloud image create \
  --from-url "${image_url}" \
  --type custom \
  --architecture x86 \
  --name "${name}" \
  --description "${description}"
