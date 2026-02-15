#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <instance-id> <command...>" >&2
  exit 2
fi

instance_id="$1"
shift

# Join remaining args into a single shell command.
cmd="$*"

params_json="$(jq -cn --arg c "${cmd}" '{commands: [$c]}')"

command_id="$(aws ssm send-command \
  --instance-ids "${instance_id}" \
  --document-name "AWS-RunShellScript" \
  --comment "clawdinators deploy" \
  --parameters "${params_json}" \
  --query 'Command.CommandId' \
  --output text)"

echo "ssm command id: ${command_id} (instance: ${instance_id})" >&2

status=""
# Wait for invocation to exist + finish.
for _ in $(seq 1 300); do
  status="$(aws ssm list-command-invocations \
    --command-id "${command_id}" \
    --details \
    --query 'CommandInvocations[0].Status' \
    --output text 2>/dev/null || true)"

  case "${status}" in
    Success|Cancelled|TimedOut|Failed)
      break
      ;;
    Pending|InProgress|Delayed|Cancelling|None|"")
      sleep 2
      ;;
    *)
      echo "unknown SSM status: ${status}" >&2
      sleep 2
      ;;
  esac
done

invocation_json="$(aws ssm get-command-invocation \
  --command-id "${command_id}" \
  --instance-id "${instance_id}" \
  --output json)"

stdout="$(jq -r '.StandardOutputContent // ""' <<<"${invocation_json}")"
stderr="$(jq -r '.StandardErrorContent // ""' <<<"${invocation_json}")"
final_status="$(jq -r '.Status' <<<"${invocation_json}")"

if [ -n "${stdout}" ]; then
  echo "${stdout}"
fi
if [ -n "${stderr}" ]; then
  echo "--- stderr ---" >&2
  echo "${stderr}" >&2
fi

if [ "${final_status}" != "Success" ]; then
  echo "ssm command failed: status=${final_status}" >&2
  exit 1
fi
