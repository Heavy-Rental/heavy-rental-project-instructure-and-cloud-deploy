# ADR 0003: Remote Terraform state outside the estate

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-bootstrap`

## Context

The GitHub runner is ephemeral. A local `terraform.tfstate` is gone when the job ends. The S3 bucket that holds estate state cannot be a resource in that same state (chicken-and-egg; `destroy` would delete the bucket).

## Decision

Use two Terraform roots:

1. `terraform/backend/` — S3 bucket `heavy-rental-tfstate-<account>-academy` + DynamoDB table `heavy-rental-tfstate-lock-academy`. Applied once with local state; object copied to `s3://…/backend/terraform.tfstate`.
2. `terraform/academy/` — estate. Backend key `estate/terraform.tfstate`. Branch 1 is a placeholder (no VPC).

No `aws_iam_role` in either root on Academy.

## Consequences

- `action=plan` can init the estate backend after the first `ensure-backend`.
- Estate `destroy` (branch 3) empties `estate/terraform.tfstate` and does not delete the bucket.
- Vocareum **Reset** still wipes the account; `.tf` stays in git and is re-applied.
