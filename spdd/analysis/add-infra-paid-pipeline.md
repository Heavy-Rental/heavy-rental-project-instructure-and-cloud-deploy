# SPDD Analysis: add-infra-paid-pipeline

**Status:** Active  
**Audience:** Implementers of the dedicated paid infra Action and public REST ALB  
**Companion:** [REASONS Canvas](../prompt/add-infra-paid-pipeline.md) · [OpenSpec change](../../openspec/changes/add-infra-paid-pipeline/proposal.md)

## Problem

Paid was selectable on the academy Action (ADR 0016), so Vocareum form keys exist on a billed-account path. Feasibility §6P specified `aws-infra-paid.yml`. Operators cannot apply the same estate through OIDC without seeing lab-key fields.

A later shared `workflow_call` still ran one process for both profiles. Leftover scripts looked up `heavy-rental-academy` observe names on paid destroy.

`hr-alb-rest` is internal, so Spring is not reachable from the internet (direct clients, mobile, webhooks). REST instances already have NAT egress.

Paid Ansible over SSM must not give guests write on `estate/terraform.tfstate`.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Paid Action | `aws-infra-paid.yml` — OIDC, Environment `AWS_ACTUAL`, own jobs, no Vocareum inputs |
| Academy Action | `aws-infra-academy.yml` — Vocareum only; own jobs; refuses non-`academy` |
| SSM bucket | `heavy-rental-ssm-<account>-actual` — Ansible file transfer; not tfstate |
| Public REST ALB | `hr-alb-rest` internet-facing in public subnets, TCP :8080 |
| Observe name | `heavy-rental-academy` or `heavy-rental-actual` (trail / dashboard / flow-log tag) |
| Isolation (0016) | OIDC vs Vocareum, separate state, `hr-paid-*` — still required |

## Stakeholders

- Class operators (academy Action unchanged)
- Paid operators (billed account, OIDC role created out of band)
- App CD (still academy-only; paid first-compose is infra `deploy-projects`)
- Branch `add-infra-paid-profile` (one Action, two profiles — superseded in part)

## Risks

1. **Shared job graph** — billed run executes Vocareum leftover lookups. Separate YAML (ADR 0019).
2. **Guests writing tfstate** — dedicated SSM bucket + GetObject only.
3. **REST ALB replacement** — `internal` / subnet change issues a new DNS. `sync-secrets` after apply.
4. **Exposing Tomcat :8080** — Haystack/RDS/Bolt stay private; REST instances have no public IP; no public 8000/5432/7687.
5. **Academy IAM create** — paid `iam.tf` must stay `count`/`for_each` on `deployment == actual`. Academy jq still refuses `aws_iam_role`.
6. **Job-graph drift** — terraform_version / Ansible pins must be updated in both YAML files.
7. **Unset DEPLOYMENT** — reconcile/sweep fail closed rather than defaulting to academy names.

## Strategy

1. Specify behavior (OpenSpec capabilities on this change).
2. Bind safeguards in the REASONS Canvas and ADRs 0017–0019.
3. Two full job graphs; public REST ALB; paid SSM bucket; deployment-scoped observe leftovers.
4. Leave paid app CD, ACM, and CloudTrail → Logs failing / out of scope.

## Success

- Academy Action refuses `AWS_ACTUAL` before Terraform. Academy YAML has no `id-token: write` and no `workflow_call`.
- Paid Action has no Vocareum inputs and refuses `AWS_ACCESS_KEY_ID` or empty `AWS_ROLE_TO_ASSUME`.
- `aws-infra-estate.yml` does not exist.
- Paid apply creates `hr-paid-*`, `-actual` state, and `heavy-rental-ssm-<account>-actual`.
- `hr-alb-rest` is internet-facing; REST instances stay private with NAT egress.
- `heavy-rental/rest` CORS includes portal and REST ALB origins.
- Academy trail remains `heavy-rental-academy` (no replace). Paid trail is `heavy-rental-actual`. Paid sweep does not query `heavy-rental-academy` trail/dashboard/flow.
