#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$AWS_CALLS"

case "$1 $2" in
  'ec2 describe-instances')
    case "$SCENARIO" in
      instance-error)
        echo "synthetic instance lookup failure" >&2
        exit 1
        ;;
      in-use) echo "ami-old" ;;
      *) echo "None" ;;
    esac
    ;;
  'ec2 describe-images')
    case "$SCENARIO" in
      image-error)
        echo "synthetic image lookup failure" >&2
        exit 1
        ;;
      invalid-json) echo '{' ;;
      invalid-images) echo '{"Images":null}' ;;
      empty) echo '{"Images":[]}' ;;
      *)
        cat << 'EOF'
{"Images":[
  {"ImageId":"ami-old","Name":"old","CreationDate":"2026-01-01T00:00:00Z","BlockDeviceMappings":[{"DeviceName":"/dev/xvda","Ebs":{"SnapshotId":"snap-old"}}]},
  {"ImageId":"ami-new","Name":"new","CreationDate":"2026-02-01T00:00:00Z","BlockDeviceMappings":[{"DeviceName":"/dev/xvda","Ebs":{"SnapshotId":"snap-new"}}]}
]}
EOF
        ;;
    esac
    ;;
  'ec2 deregister-image' | 'ec2 delete-snapshot') ;;
  *)
    echo "unexpected AWS call: $*" >&2
    exit 1
    ;;
esac
