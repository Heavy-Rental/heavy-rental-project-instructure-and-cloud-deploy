# Design: Academy / Vocareum infra CD bootstrap

## Context

Vocareum federates a short-lived `voclabs/…` principal. OIDC cannot be created on Academy. The GitHub runner is ephemeral. The estate Terraform state must live in S3 with a DynamoDB lock, but that bucket cannot be a resource *in* the same state it stores.

Application CI already builds images in another repo. This project only deploys to AWS. Branch 1 does not create the estate.

## Goals / Non-Goals

**Goals:**

- `action=plan` is green after Start Lab + three Vocareum keys.
- Credentials: form first (they change every session), else Environment `academy`.
- Remote state backend exists after the first successful `plan` or `bootstrap`.
- Workflow refuses Environment ≠ `academy`.

**Non-Goals:**

- Paid account, OIDC, `AWS_ROLE_TO_ASSUME`
- VPC, NAT Gateway, ALB, RDS, ASG, Marketplace Neo4j
- Ansible, `sync-secrets` values, app CD
- Creating GitHub Environments from git (manual: `BOOTSTRAP.md`)

## Decisions

1. **Vocareum-only workflow file.** No paid YAML on this branch. See ADR 0001.
2. **Form keys + Environment fallback.** See ADR 0002. Mask with `::add-mask::`. Never write keys to Secrets Manager or the guest.
3. **Backend stack is separate Terraform.** Local apply, then copy state into `s3://…/backend/terraform.tfstate`. Estate uses key `estate/terraform.tfstate`. See ADR 0003.
4. **`apply` fails on this branch.** Estate resources are `feat/infra-academy-estate`.
5. **Conflict order:** OpenSpec scenarios → OpenSPDD Safeguards → YAML / `.tf`.

## Risks / Trade-offs

- GitHub cannot secret-type dispatch inputs (visible on the run Inputs page). Mitigate: private repo, reviewers, mask, `set +x`.
- First `plan` creates a small S3 bucket + DynamoDB table (credit noise, not a VPC).
