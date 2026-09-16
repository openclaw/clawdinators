#!/usr/bin/env bash
set -euo pipefail

region="${AWS_REGION:?AWS_REGION required}"
keep_count="${KEEP_COUNT:-6}"
apply="${APPLY:-false}"

if ! [[ "${keep_count}" =~ ^[0-9]+$ ]] || [ "${keep_count}" -lt 1 ]; then
  echo "KEEP_COUNT must be a positive integer." >&2
  exit 1
fi

aws_deregister_image() {
  local image_id="$1"
  local output

  if ! output="$(
    aws ec2 deregister-image \
      --region "${region}" \
      --image-id "${image_id}" \
      2>&1
  )"; then
    if [[ "${output}" == *"InvalidAMIID.NotFound"* ]] || [[ "${output}" == *"InvalidAMIID.Unavailable"* ]]; then
      echo "AMI already gone: ${image_id}" >&2
      return 0
    fi
    echo "${output}" >&2
    return 1
  fi
}

aws_delete_snapshot() {
  local snapshot_id="$1"
  local output

  if [ -z "${snapshot_id}" ]; then
    return 0
  fi

  if ! output="$(
    aws ec2 delete-snapshot \
      --region "${region}" \
      --snapshot-id "${snapshot_id}" \
      2>&1
  )"; then
    if [[ "${output}" == *"InvalidSnapshot.NotFound"* ]]; then
      echo "Snapshot already gone: ${snapshot_id}" >&2
      return 0
    fi
    echo "${output}" >&2
    return 1
  fi
}

array_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done

  return 1
}

find_image_row() {
  local needle="$1"
  local row
  local image_id

  for row in "${image_rows[@]}"; do
    IFS=$'\t' read -r image_id _rest <<< "${row}"
    if [ "${image_id}" = "${needle}" ]; then
      printf '%s\n' "${row}"
      return 0
    fi
  done

  return 1
}

# Capture lookup failures before building the keep-set; process substitutions
# do not propagate their exit status to the parent shell.
in_use_ami_ids_text="$(
  aws ec2 describe-instances \
    --region "${region}" \
    --filters \
    "Name=tag:app,Values=clawdinator" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].ImageId' \
    --output text |
    tr '\t' '\n' |
    sed '/^None$/d;/^$/d' |
    sort -u
)"

in_use_ami_ids=()
while IFS= read -r image_id; do
  if [ -n "${image_id}" ]; then
    in_use_ami_ids+=("${image_id}")
  fi
done <<< "${in_use_ami_ids_text}"

images_json="$(
  aws ec2 describe-images \
    --region "${region}" \
    --owners self \
    --filters "Name=tag:clawdinator,Values=true" \
    --output json
)"

image_rows_text="$(
  printf '%s\n' "${images_json}" | jq -r '
    .Images
    | sort_by(.CreationDate)
    | reverse[]
    | [
        .ImageId,
        (.Name // ""),
        .CreationDate,
        ((.RootDeviceName // "/dev/xvda") as $root
          | ([.BlockDeviceMappings[]? | select(.DeviceName == $root) | .Ebs.SnapshotId][0] // ""))
      ]
    | @tsv
  '
)"

image_rows=()
while IFS= read -r row; do
  if [ -n "${row}" ]; then
    image_rows+=("${row}")
  fi
done <<< "${image_rows_text}"

if [ "${#image_rows[@]}" -eq 0 ]; then
  echo "No CLAWDINATOR AMIs found."
  exit 0
fi

declare -a newest_ids=()
declare -a keep_ids=()
declare -a prune_rows=()

for image_id in "${in_use_ami_ids[@]}"; do
  keep_ids+=("${image_id}")
done

recent_index=0
for row in "${image_rows[@]}"; do
  IFS=$'\t' read -r image_id name creation_date snapshot_id <<< "${row}"

  if [ "${recent_index}" -lt "${keep_count}" ]; then
    newest_ids+=("${image_id}")
    if ! array_contains "${image_id}" "${keep_ids[@]}"; then
      keep_ids+=("${image_id}")
    fi
    recent_index=$((recent_index + 1))
  fi

  if ! array_contains "${image_id}" "${keep_ids[@]}"; then
    prune_rows+=("${row}")
  fi
done

echo "CLAWDINATOR AMI retention"
echo "Mode: $(printf '%s' "${apply}" | tr '[:lower:]' '[:upper:]')"
echo "Region: ${region}"
echo

echo "In-use AMIs (${#in_use_ami_ids[@]}):"
if [ "${#in_use_ami_ids[@]}" -eq 0 ]; then
  echo "  (none)"
else
  for image_id in "${in_use_ami_ids[@]}"; do
    echo "  ${image_id}"
  done
fi
echo

echo "Newest ${keep_count} AMIs by age:"
for image_id in "${newest_ids[@]}"; do
  row="$(find_image_row "${image_id}")"
  IFS=$'\t' read -r _image_id name creation_date snapshot_id <<< "${row}"
  echo "  ${image_id}  ${creation_date}  ${name}"
done
echo

echo "Keep-set (${#keep_ids[@]} total):"
for row in "${image_rows[@]}"; do
  reasons=()
  IFS=$'\t' read -r image_id name creation_date snapshot_id <<< "${row}"
  if array_contains "${image_id}" "${keep_ids[@]}"; then
    if array_contains "${image_id}" "${in_use_ami_ids[@]}"; then
      reasons+=("in-use")
    fi
    if array_contains "${image_id}" "${newest_ids[@]}"; then
      reasons+=("recent")
    fi
    reason="$(
      IFS=,
      printf '%s' "${reasons[*]}"
    )"
    echo "  keep ${image_id}  ${creation_date}  ${reason}  ${name}"
  fi
done
echo

echo "Prune-set (${#prune_rows[@]} total):"
if [ "${#prune_rows[@]}" -eq 0 ]; then
  echo "  (none)"
else
  for row in "${prune_rows[@]}"; do
    IFS=$'\t' read -r image_id name creation_date snapshot_id <<< "${row}"
    echo "  prune ${image_id}  ${creation_date}  snapshot=${snapshot_id:-none}  ${name}"
  done
fi
echo

if [ "${apply}" != "true" ]; then
  echo "Dry-run only. Re-run with APPLY=true to prune old CLAWDINATOR AMIs."
  exit 0
fi

for row in "${prune_rows[@]}"; do
  IFS=$'\t' read -r image_id name creation_date snapshot_id <<< "${row}"
  echo "Deregistering ${image_id} (${name})"
  aws_deregister_image "${image_id}"

  if [ -n "${snapshot_id}" ]; then
    echo "Deleting snapshot ${snapshot_id}"
    aws_delete_snapshot "${snapshot_id}"
  fi
done
