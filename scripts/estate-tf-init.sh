#!/usr/bin/env bash
# Init the estate backend. Fail closed if the bucket is missing (configure-only / stop).
set -euo pipefail

BUCKET="${1:?bucket name required}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "::error::State bucket ${BUCKET} is missing. Apply the estate first. Do not create a backend here."
  exit 1
fi

cd "${ROOT}/terraform/academy"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=estate/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
