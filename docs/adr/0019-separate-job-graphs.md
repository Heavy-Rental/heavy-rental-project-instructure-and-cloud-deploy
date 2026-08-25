# ADR 0019: Separate job graphs (no reusable estate workflow)

- **Status:** Accepted
- **Date:** 2026-08-25
- **Change:** `add-infra-paid-pipeline`
- **Supersedes (in part):** [0017](0017-two-actions-academy-paid.md) decision 3 (shared `aws-infra-estate.yml`). Two Actions, OIDC vs Vocareum, `-actual` state, paid SSM bucket, and out-of-band OIDC **stand**.

## Context

ADR 0017 put academy and paid on two operator Actions but one `workflow_call` job graph so terraform/ansible steps would not drift. Leftover scripts (`reconcile-estate.sh`, `sweep-estate-orphans.sh`) still looked up CloudTrail / dashboard / flow-log `heavy-rental-academy`, so a paid destroy did not sweep `heavy-rental-actual`. A billed run and a Vocareum run shared a process.

Operators asked for each pipeline’s **process** to be independent. Terraform resource names (VPC tag, RDS identifiers, ASGs) stay shared because renaming them would replace data-plane objects.

## Alternatives

1. **Keep `workflow_call`.** Parameterize leftover names only. Rejected: a billed Action still runs the Vocareum job graph (LabRole preflight gated by `if`, voc-cancel-cred paths, reusable `job_workflow_ref`).
2. **Copy the job graph into each Action.** Chosen. Drift is accepted. Each file drops the other profile’s steps.
3. **Fork Terraform roots.** Rejected: RDS/VPC rename replaces databases.

## Decision

1. `.github/workflows/aws-infra-academy.yml` contains the full Vocareum job graph. No `workflow_call`. No `id-token: write`. LabRole preflight and `aws_iam_role` plan refuse stay here.
2. `.github/workflows/aws-infra-paid.yml` contains the full OIDC job graph. No Vocareum inputs. No LabRole preflight. Ansible uses the paid SSM bucket.
3. `.github/workflows/aws-infra-estate.yml` SHALL NOT exist.
4. Leftover observe names follow `DEPLOYMENT`: `heavy-rental-academy` vs `heavy-rental-actual` (trail, dashboard, flow-log tag). Scripts fail if `DEPLOYMENT` is unset.
5. VPC tag `heavy-rental-academy` and RDS identifiers `heavy-rental-academy` / `heavy-rental-haystack-academy` stay Terraform names on both profiles (different AWS accounts / state buckets).
6. OIDC trust no longer needs to cover a reusable workflow `job_workflow_ref`. `repo:ORG/REPO:*` is enough for `aws-infra-paid.yml`.

## Consequences

- A paid run cannot paste Vocareum keys and does not execute academy leftover lookups.
- Job-graph drift is possible; fix both files when a shared step (Ansible version, terraform_version) changes.
- `resolve-aws-profile` remains a shared **auth** helper, not the estate process.
