# Proposal: Dedicated paid infra Action + internet-facing REST ALB

## Why

ADR 0016 put academy (Vocareum) and paid (OIDC) on the same Action so operators could pick the Environment. Vocareum key inputs stay visible on that form (GitHub cannot hide them), so lab keys can be aimed at a billed account. Feasibility §6P specified a **second** workflow file (`aws-infra-paid.yml`) with OIDC only.

The Spring Boot REST API and `hr-alb-rest` must be reachable from the internet (direct clients, mobile, Stripe webhooks). At the time of this change that ALB was internal in the app subnets. REST **instances** already had NAT egress on :80/:443.

Paid Ansible over SSM must not reuse the Terraform state bucket: guests would be able to write `estate/terraform.tfstate`.

## What Changes

- New operator Action `.github/workflows/aws-infra-paid.yml` (OIDC, Environment `AWS_ACTUAL` only, no Vocareum inputs). Own job graph (ADR 0019).
- `aws-infra-academy.yml` is an academy-only Action with its own job graph (Vocareum keys; refuses non-`academy`; no `id-token: write`).
- No `aws-infra-estate.yml`. Leftover observe names follow `DEPLOYMENT`.
- Paid-only SSM transfer bucket + guest `s3:GetObject` (Ansible over SSM must not use the tfstate bucket).
- REST ALB is internet-facing in public subnets; TCP 8080 from `0.0.0.0/0`. Haystack stays internal. Portal `/api` still proxies to `REST_BASE_URL` (public DNS; hairpin via NAT). `sg-portal` egresses TCP 8080 to `0.0.0.0/0` as well as to `sg-alb-rest`.
- `sync-secrets` CORS includes the public REST origin. Observe names are `heavy-rental-academy` or `heavy-rental-actual`.
- OpenSpec, OpenSPDD, ADR 0017 (two Actions) and ADR 0018 (public REST ALB).

## Capabilities

### New Capabilities

- `infra-paid-pipeline`
- `infra-estate-rest-alb`

### Modified Capabilities

- `infra-academy-scope`: academy workflow is Vocareum-only again; paid is a different file
- `infra-academy-paid-profile`: isolation remains; “one Action, two profiles” is retired
- `infra-academy-estate-sg`: REST ALB may accept internet :8080; `sg-portal` egress TCP 8080 to `0.0.0.0/0` for the NAT hairpin; still no public 8000/5432/7687
- `infra-academy-sync-secrets`: `APP_CORS_ALLOWED_ORIGINS` includes portal and REST ALB origins
- `infra-academy-observe`: trail / dashboard / flow-log name follows `deployment` (`heavy-rental-academy` unchanged on academy)

## Impact

- Operators run **AWS infrastructure (paid)** against Environment `AWS_ACTUAL`.
- Academy class path is unchanged if they keep using the academy Action.
- **Diverges from feasibility §6P:** Environment name stays `AWS_ACTUAL` (not `paid`); REST ALB is internet-facing :8080 (study said internal / no public 8080). Recorded in ADR 0017 / 0018.
- **Not in this change:** portal HTTPS/ACM, CloudTrail → CloudWatch Logs, Marketplace Neo4j, a second Terraform root, renaming Environment `AWS_ACTUAL` to `paid`. Paid **app** CD is a later change in `heavy-rental-project-pipeline-development` (`add-*-cd-paid-deploy`); this Action’s first-compose stays `deploy-projects`.
