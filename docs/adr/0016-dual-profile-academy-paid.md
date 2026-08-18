# ADR 0016: One Action, two profiles (academy Vocareum / paid OIDC)

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes (in part):** [0001](0001-academy-vocareum-only.md) — paid may be **selected** on this workflow; isolation remains
- **Related:** [0005](0005-labinstanceprofile-only.md), [0009](0009-academy-keys-in-environment-secrets.md)

## Context

ADR 0001 kept `aws-infra-academy.yml` Vocareum-only so lab session keys could not be aimed at a billed account. Operators now need to choose **AWS Vocareum** or **AWS public (paid)** on that Action. Feasibility §6P still requires a different account, state key, and **OIDC** — never Vocareum keys on paid. Academy still cannot create IAM.

## Decision

1. The same workflow file accepts GitHub Environments **`academy`** and **`AWS_ACTUAL`** only.
2. **Academy:** form or Environment Vocareum keys. Guests **LabInstanceProfile** → **LabRole**. Terraform creates no IAM.
3. **AWS_ACTUAL:** `configure-aws-credentials` with `role-to-assume` = Environment `AWS_ROLE_TO_ASSUME`. Guests use Terraform-created `hr-paid-{app}` instance profiles. Fail if form keys are set or if Environment `AWS_ACTUAL` has `AWS_ACCESS_KEY_ID`.
4. State bucket `heavy-rental-tfstate-<account>-academy` or `…-actual`. S3 names cannot contain uppercase, so Environment `AWS_ACTUAL` maps to deployment `actual`. Never one state for both.
5. `var.deployment` (`academy` | `actual`) in the existing `terraform/academy` root switches data sources vs IAM resources.

## Consequences

- Operators pick the Environment on Run workflow.
- Mixing key styles fails assert, not a silent apply to the wrong account.
- Paid needs a one-time OIDC role in the billed account (not created by this apply).
- Academy class path is unchanged when they keep selecting `academy`.
