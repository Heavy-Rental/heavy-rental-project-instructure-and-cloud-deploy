#!/usr/bin/env bash
# Create the S3 Terraform state bucket if missing (S3 native lockfile).
# HeadBucket 403 / voc-cancel-cred is not "missing" — do not CreateBucket.
set -euo pipefail

BUCKET="${1:?bucket name required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

voc_cancel_msg() {
  echo "::error::Vocareum cancelled this session (identity policy voc-cancel-cred). Start Lab and paste fresh AWS Details on the Run form. Do not reuse Environment academy AWS_* secrets from a previous Start Lab. The Ensure S3 state backend job cannot CreateBucket until the lab is started."
}

"${ROOT}/scripts/assert-live-aws.sh"

set +e
head_out="$(aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>&1)"
head_rc=$?
set -e

if [ "${head_rc}" -eq 0 ]; then
  echo "State bucket ${BUCKET} already exists (S3 native lockfile)."
  exit 0
fi

if printf '%s' "${head_out}" | grep -qi 'voc-cancel-cred'; then
  voc_cancel_msg
  printf '%s\n' "${head_out}"
  exit 1
fi

if printf '%s' "${head_out}" | grep -qiE 'AccessDenied|Forbidden|\(403\)'; then
  echo "::error::head-bucket ${BUCKET} returned 403. Not creating the bucket (CreateBucket would also fail). If voc-cancel-cred is attached, Start Lab and paste fresh AWS Details. Otherwise the bucket may already exist and this caller cannot HeadBucket it."
  printf '%s\n' "${head_out}"
  exit 1
fi

if ! printf '%s' "${head_out}" | grep -qiE 'Not Found|\(404\)|NoSuchBucket'; then
  echo "::error::head-bucket ${BUCKET} failed (not 404). Refusing CreateBucket."
  printf '%s\n' "${head_out}"
  exit 1
fi

echo "Creating state backend (bucket=${BUCKET}; S3 native lockfile)."
cd "${ROOT}/terraform/backend"
terraform init -input=false
apply_log="$(mktemp)"
set +e
terraform apply -auto-approve -input=false 2>&1 | tee "${apply_log}"
apply_rc=${PIPESTATUS[0]}
set -e
if [ "${apply_rc}" -ne 0 ]; then
  if grep -qi 'voc-cancel-cred' "${apply_log}"; then
    voc_cancel_msg
  else
    echo "::error::terraform apply in terraform/backend/ failed for ${BUCKET}."
  fi
  exit "${apply_rc}"
fi

if [ -f terraform.tfstate ]; then
  aws s3 cp terraform.tfstate "s3://${BUCKET}/backend/terraform.tfstate"
fi
