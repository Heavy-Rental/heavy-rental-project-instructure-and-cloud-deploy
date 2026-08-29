#!/usr/bin/env bash
# Emit TF_VAR_bastion_ssh_cidrs=JSON from Environment BASTION_SSH_CIDRS
# (comma-separated IPv4 CIDRs). Empty → []. Never print secrets.
set -euo pipefail
raw="${BASTION_SSH_CIDRS:-}"
if [ -z "${raw// }" ]; then
  echo "TF_VAR_bastion_ssh_cidrs=[]"
  exit 0
fi
json="$(printf '%s\n' "${raw}" | tr ',' '\n' | awk '
  BEGIN { n = 0 }
  {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 == "") next
    if (n++) printf(",")
    printf("\"%s\"", $0)
  }
')"
echo "TF_VAR_bastion_ssh_cidrs=[${json}]"
