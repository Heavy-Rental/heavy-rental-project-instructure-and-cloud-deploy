# ADR 0017: Two Actions (academy Vocareum / paid OIDC)

- **Status:** Accepted
- **Date:** 2026-08-19
- **Supersedes (in part):** [0016](0016-dual-profile-academy-paid.md) — isolation rules stand; one Action becomes two files
- **Related:** [0001](0001-academy-vocareum-only.md), [0005](0005-labinstanceprofile-only.md), [0009](0009-academy-keys-in-environment-secrets.md), [0012](0012-ansible-over-ssm.md)
- **Change:** `add-infra-paid-pipeline`

## Context

ADR 0016 put academy and paid on `aws-infra-academy.yml` so operators could pick the Environment. Vocareum key inputs stay visible on that form (GitHub cannot hide optional inputs). Feasibility §6P specified a **second** workflow (`aws-infra-paid.yml`) with OIDC only. Operators asked for a billed-account Action with nowhere to paste lab keys.

Isolation still required: different GitHub Environment, different Terraform state, Vocareum keys never on paid, academy still cannot create IAM. Environment name `AWS_ACTUAL` and S3 suffix `-actual` already shipped in 0016 (S3 cannot contain uppercase `AWS_ACTUAL`). Feasibility’s Environment name `paid` is **not** revived.

Ansible over SSM (ADR 0012) uploads modules to S3. Academy LabRole already uses the tfstate bucket. Paid guests must not write `estate/terraform.tfstate`.

## Alternatives

1. **Keep one Action (ADR 0016).** Fail if form keys are set on `AWS_ACTUAL`. Rejected: the keys remain on the form; a billed run can still receive them.
2. **Copy the job graph into two YAML files.** Rejected: terraform/ansible steps would drift.
3. **Two dispatcher files + one reusable job graph.** Chosen.

## Decision

1. `.github/workflows/aws-infra-academy.yml` is Vocareum-only (Environment `academy`). It refuses any other Environment before Terraform. Vocareum key inputs stay on this file. It SHALL NOT set `id-token: write`. Each Action owns its jobs (ADR 0019).
2. `.github/workflows/aws-infra-paid.yml` is OIDC-only (Environment `AWS_ACTUAL`). It SHALL NOT declare Vocareum key inputs. It fails if `AWS_ACCESS_KEY_ID` is set or `AWS_ROLE_TO_ASSUME` is empty. It sets `id-token: write`.
3. ~~Shared job graph in `aws-infra-estate.yml`.~~ **Superseded by [0019](0019-separate-job-graphs.md):** each Action owns its jobs. Concurrency groups stay `aws-infra-academy-<repository>` and `aws-infra-paid-<repository>` (`cancel-in-progress: false`).
4. State suffix stays `-academy` / `-actual`. Environment name stays `AWS_ACTUAL` (not feasibility’s `paid`).
5. Same Terraform root (`var.deployment`). Paid guests use `hr-paid-*`. Academy still creates no IAM.
6. Paid Ansible SSM uses `heavy-rental-ssm-<account>-actual` (guest `s3:GetObject` / `ListBucket` only). Academy keeps the tfstate bucket for SSM transfer.
7. OIDC provider + IAM role are created **out of band**. Sample: `docs/samples/github-oidc-paid.json`. Trust `repo:ORG/REPO:*`. Reusable-workflow `job_workflow_ref` coverage is no longer required (ADR 0019). Estate apply cannot create the role it assumes.

## Consequences

- Lab keys cannot be aimed at the billed account from the academy Action; the paid Action has nowhere to paste them.
- Academy class path is unchanged if operators keep using the academy Action.
- App CD remains academy-only until a later change; paid first-compose is `deploy-projects` on the paid Action.
- Observe trail/dashboard names follow `deployment` (`heavy-rental-academy` unchanged; paid `heavy-rental-actual`). Sweep/reconcile leftover observe names follow `DEPLOYMENT` (ADR 0019).
