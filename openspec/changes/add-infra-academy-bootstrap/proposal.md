# Proposal: Add Academy / Vocareum infra CD bootstrap

## Why

This repo must become the CD home for Heavy Rental on **AWS Academy Learner Lab (Vocareum)**. Vocareum sessions are temporary: access key, secret, and session token change every Start Lab. GitHub Actions runners are ephemeral, so Terraform cannot use a local state file.

Branch 1 (`feat/infra-academy-bootstrap`) must prove the pipeline can authenticate and `terraform plan` **before** any VPC, ALB, or RDS spends lab credits. Paid / OIDC is a later account and MUST NOT appear on this workflow.

## What Changes

- Add OpenSpec (behavior), OpenSPDD (REASONS Canvas), and ADRs for this branch.
- Add `.github/workflows/aws-infra-academy.yml`: Vocareum form keys or Environment `academy` fallback; refuse any other Environment.
- Add `terraform/backend/` (S3 + DynamoDB lock, not in the estate state).
- Add `terraform/academy/` placeholder with remote backend; `action=plan` only. `apply` of the estate waits for branch 2.

## Capabilities

### New Capabilities

- `infra-academy-auth`: Vocareum credentials from Run workflow or Environment `academy`; mask; refuse paid
- `infra-academy-backend`: S3 bucket + lock table if missing; no IAM role
- `infra-academy-plan`: `init` + `plan` of the empty estate; no VPC/ALB/RDS
- `infra-academy-scope`: this branch does not apply the estate, configure guests, stop, destroy, or ship a paid pipeline

### Modified Capabilities

- None (greenfield for this repo).

## Impact

- **This repo:** first CD workflow and state backend. Operators create GitHub Environment `academy` (see `BOOTSTRAP.md`).
- **Not in this change:** three-tier VPC, ASGs, Ansible, Secrets Manager values, portal/REST/Haystack app CD, paid OIDC.
