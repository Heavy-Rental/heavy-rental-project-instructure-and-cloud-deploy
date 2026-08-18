#!/usr/bin/env bash
# Drop a leftover S3 native lock from a previous runner. This workflow's
# concurrency group is one Terraform job at a time, so a lock that still
# exists when this job starts cannot belong to a live apply.
set -euo pipefail

BUCKET="${1:-${BUCKET:-}}"
if [ -z "${BUCKET}" ]; then
  echo "::error::estate-unlock: bucket name required."
  exit 1
fi

KEY="estate/terraform.tfstate.tflock"
if ! aws s3api head-object --bucket "${BUCKET}" --key "${KEY}" >/dev/null 2>&1; then
  echo "No ${KEY} in s3://${BUCKET}."
  exit 0
fi

LOCK_JSON="$(aws s3 cp "s3://${BUCKET}/${KEY}" - 2>/dev/null || true)"
LOCK_ID="$(printf '%s' "${LOCK_JSON}" | jq -r '.ID // .id // empty' 2>/dev/null || true)"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${LOCK_ID}" ] && [ -d "${ROOT}/terraform/academy/.terraform" ]; then
  echo "Force-unlocking leftover Terraform lock ${LOCK_ID}."
  (cd "${ROOT}/terraform/academy" && terraform force-unlock -force "${LOCK_ID}") || true
fi

if aws s3api head-object --bucket "${BUCKET}" --key "${KEY}" >/dev/null 2>&1; then
  echo "Removing leftover s3://${BUCKET}/${KEY}."
  aws s3 rm "s3://${BUCKET}/${KEY}" >/dev/null
fi
echo "State lock cleared."
