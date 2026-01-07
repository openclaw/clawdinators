#!/usr/bin/env bash
set -euo pipefail

config_path="${CONFIG_PATH:-nix/hosts/clawdinator-1-image.nix}"
out_dir="${OUT_DIR:-dist}"

mkdir -p "${out_dir}"

nix run github:nix-community/nixos-generators -- -f raw-efi -c "${config_path}" -o "${out_dir}"

if [ ! -f "${out_dir}/nixos.img" ]; then
  echo "Expected image at ${out_dir}/nixos.img" >&2
  exit 1
fi
