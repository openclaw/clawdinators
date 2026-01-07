#!/usr/bin/env bash
set -euo pipefail

bucket="${S3_BUCKET:-}"
region="${AWS_REGION:-}"
prefix="${S3_PREFIX:-clawdinator-images}"
out_dir="${OUT_DIR:-dist}"

if [ -z "${bucket}" ] || [ -z "${region}" ]; then
  echo "S3_BUCKET and AWS_REGION are required." >&2
  exit 1
fi

img_path="${out_dir}/nixos.img"
zst_path="${out_dir}/nixos.img.zst"

if [ ! -f "${img_path}" ]; then
  echo "Missing ${img_path}. Run build-image.sh first." >&2
  exit 1
fi

if [ ! -f "${zst_path}" ]; then
  zstd "${img_path}" -o "${zst_path}"
fi

timestamp="$(date -u +%Y%m%d-%H%M%S)"
object_key="${prefix}/nixos-${timestamp}.img.zst"

aws s3 cp "${zst_path}" "s3://${bucket}/${object_key}" --region "${region}"

if [ -n "${S3_PUBLIC_URL:-}" ]; then
  echo "${S3_PUBLIC_URL}"
  exit 0
fi

aws s3 presign "s3://${bucket}/${object_key}" --region "${region}" --expires-in 3600
