#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/bin"
cp "$repo_root/scripts/tests/fixtures/prune-aws.sh" "$workdir/bin/aws"
chmod +x "$workdir/bin/aws"
export PATH="$workdir/bin:$PATH"
export AWS_CALLS="$workdir/aws-calls"
export AWS_REGION="test-region"
export KEEP_COUNT=1

failures=0
for scenario in instance-error image-error invalid-json invalid-images empty in-use prune dry-run; do
  export SCENARIO="$scenario"
  export APPLY=true
  if [ "$scenario" = dry-run ]; then
    export APPLY=false
  fi
  : > "$AWS_CALLS"
  result=0
  bash "$repo_root/scripts/prune-clawdinator-ami-history.sh" > "$workdir/stdout" 2> "$workdir/stderr" || result=$?

  failed=false
  case "$scenario" in
    instance-error | image-error | invalid-json | invalid-images)
      if [ "$result" -eq 0 ] || [ ! -s "$workdir/stderr" ]; then
        failed=true
      fi
      ;;
    *)
      if [ "$result" -ne 0 ]; then
        failed=true
      fi
      ;;
  esac

  if [ "$scenario" = prune ]; then
    if ! grep -Fxq 'ec2 deregister-image --region test-region --image-id ami-old' "$AWS_CALLS" ||
      ! grep -Fxq 'ec2 delete-snapshot --region test-region --snapshot-id snap-old' "$AWS_CALLS" ||
      [ "$(grep -Ec '^ec2 (deregister-image|delete-snapshot) ' "$AWS_CALLS")" -ne 2 ]; then
      failed=true
    fi
  elif grep -Eq '^ec2 (deregister-image|delete-snapshot) ' "$AWS_CALLS"; then
    failed=true
  fi

  if [ "$failed" = true ]; then
    echo "FAIL: $scenario (exit $result)" >&2
    cat "$workdir/stdout" "$workdir/stderr" "$AWS_CALLS" >&2
    failures=$((failures + 1))
  else
    echo "PASS: $scenario"
  fi
done

[ "$failures" -eq 0 ]
