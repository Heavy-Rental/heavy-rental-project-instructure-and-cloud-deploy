#!/usr/bin/env bash
# One-time: GitHub OIDC provider + role github-actions-infra in the billed account.
# Run locally (or CloudShell) with an admin AWS principal. Not a GitHub Action.
#
#   GITHUB_ORG=Heavy-Rental ./scripts/bootstrap-github-oidc-paid.sh
#
# Then paste the printed ARN into GitHub Environment AWS_ACTUAL as
# variable or secret AWS_ROLE_TO_ASSUME. See docs/OIDC-PAID.md.
set -euo pipefail

REPO="${GITHUB_REPO:-heavy-rental-project-instructure-and-cloud-deploy}"
ROLE_NAME="${OIDC_ROLE_NAME:-github-actions-infra}"
THUMB1="6938fd4d98bab03faadb97b34396831e3780aea1"
THUMB2="1c58a3a8518e8759bf075b76b750d4f2df264fcd"

if [ -z "${GITHUB_ORG:-}" ]; then
  echo "::error::Set GITHUB_ORG to the GitHub org or user that owns ${REPO}."
  echo "Example: GITHUB_ORG=Heavy-Rental $0"
  exit 1
fi

if ! command -v aws >/dev/null; then
  echo "::error::aws CLI not found."
  exit 1
fi

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
PROVIDER_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}"
SUB="repo:${GITHUB_ORG}/${REPO}:*"

echo "Account ${ACCOUNT} region ${REGION}"
echo "Trust sub ${SUB}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${PROVIDER_ARN}" >/dev/null 2>&1; then
  echo "OIDC provider already exists."
else
  echo "Creating OIDC provider token.actions.githubusercontent.com"
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "${THUMB1}" "${THUMB2}" >/dev/null
fi

TRUST="$(mktemp)"
trap 'rm -f "${TRUST}"' EXIT
cat > "${TRUST}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubOidcThisRepo",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "${SUB}"
        }
      }
    }
  ]
}
EOF

if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "Updating trust on existing role ${ROLE_NAME}"
  aws iam update-assume-role-policy --role-name "${ROLE_NAME}" --policy-document "file://${TRUST}"
else
  echo "Creating role ${ROLE_NAME}"
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${TRUST}" \
    --description "GitHub Actions OIDC for ${GITHUB_ORG}/${REPO} paid infra" >/dev/null
fi

echo "Attaching AdministratorAccess (runner only; guests use hr-paid-*)"
aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo
echo "Role ARN (put this on GitHub Environment AWS_ACTUAL):"
echo "  ${ROLE_ARN}"
echo
echo "GitHub:"
echo "  1. Settings → Environments → New environment → name AWS_ACTUAL"
echo "  2. Variable AWS_ROLE_TO_ASSUME = ${ROLE_ARN}"
echo "     or Secret AWS_ROLE_TO_ASSUME = ${ROLE_ARN} (same name; either works)"
echo "  3. Variable AWS_REGION = ${REGION}"
echo "  4. App secrets only (SPRING_DATASOURCE_PASSWORD, NEO4J_PASSWORD, Stripe trio)."
echo "     Do NOT add AWS_ACCESS_KEY_ID."
echo "  5. Actions → AWS infrastructure (paid) → aws_environment=AWS_ACTUAL → action=plan"
echo
echo "Guide: docs/OIDC-PAID.md"
