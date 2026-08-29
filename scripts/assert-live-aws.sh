#!/usr/bin/env bash
# STS GetCallerIdentity still works after Vocareum attaches voc-cancel-cred.
# Probe a real service call so plan/bootstrap fail before CreateBucket.
set -euo pipefail

voc_cancel_msg() {
  echo "::error::Vocareum cancelled this session (identity policy voc-cancel-cred). Start Lab and paste fresh AWS Details on the Run form. Do not reuse Environment academy AWS_* secrets from a previous Start Lab. sts get-caller-identity can still succeed; s3:CreateBucket cannot."
}

set +e
out="$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text 2>&1)"
rc=$?
set -e

if [ "${rc}" -eq 0 ]; then
  echo "AWS session is live (ec2:${out})."
  exit 0
fi

if printf '%s' "${out}" | grep -qi 'voc-cancel-cred'; then
  voc_cancel_msg
  printf '%s\n' "${out}"
  exit 1
fi

echo "::error::AWS session cannot call EC2. Start Lab and paste fresh AWS Details if this is Academy. ${out}"
exit 1
