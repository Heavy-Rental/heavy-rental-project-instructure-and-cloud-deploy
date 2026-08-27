# Design: Two infra Actions + public REST ALB

## Context

ADR 0016 put academy and paid on `aws-infra-academy.yml` so operators could pick Environment `academy` or `AWS_ACTUAL`. Vocareum key inputs stay on that form. Feasibility §6P and operators want a **second** file with no lab keys. Isolation (OIDC vs Vocareum, separate state, `hr-paid-*` guests) still holds.

`hr-alb-rest` is internal in the app subnets. The portal reaches Spring only via that private DNS (`REST_BASE_URL`). Direct clients, mobile, and Stripe webhooks cannot hit Tomcat. REST **instances** already use NAT egress on :80/:443. Internet-facing ALBs must use public subnets; changing `internal` or subnets **replaces** the ALB (new DNS).

Ansible `amazon.aws.aws_ssm` uploads modules to S3. Academy LabRole already uses the tfstate bucket. Paid guests must not write `estate/terraform.tfstate`.

## Goals / Non-Goals

**Goals:**

- Dedicated `aws-infra-paid.yml` (OIDC, Environment `AWS_ACTUAL`, state suffix `-actual`).
- Academy Action refuses non-`academy` before Terraform. Vocareum key inputs stay on that Action only. Academy YAML has no `id-token: write`.
- Same Terraform root (`terraform/academy/`, `var.deployment`), same actions (`plan` / `bootstrap` / `apply` / `configure-only` / `deploy-projects` / `stop` / `destroy`).
- Each Action owns its jobs (no `workflow_call`, ADR 0019). Distinct concurrency groups so the two Actions cannot cancel each other.
- REST ALB internet-facing, public subnets, :8080 from the internet. REST guests stay private with NAT. Haystack / Bolt / RDS stay internal. Portal ALB stays the only public :80.
- Paid Ansible SSM uses `heavy-rental-ssm-<account>-actual` (GetObject / ListBucket). Academy keeps the tfstate bucket.
- Observe names: academy string `heavy-rental-academy` unchanged; paid `heavy-rental-actual`.

**Non-Goals:**

- HTTPS/ACM on portal or REST
- CloudTrail → CloudWatch Logs
- A second VPC design or a second Terraform root
- Paid portal/REST/Haystack **app** CD YAML (authored in `heavy-rental-project-pipeline-development`; this Action’s first-compose stays `deploy-projects`)
- Renaming Environment `AWS_ACTUAL` to feasibility’s `paid`

## Decisions

1. **Separate job graphs (ADR 0019).** Each Action contains its jobs. Do not share `aws-infra-estate.yml`. Drift is accepted so a billed run never executes Vocareum leftover lookups.
2. **Environment remains `AWS_ACTUAL` / `actual`.** S3 cannot use uppercase; ADR 0016 already shipped this mapping. Do not rename to `paid`.
3. **OIDC role is out of band.** Sample trust policy in `docs/samples/github-oidc-paid.json`. Estate apply cannot create the role it assumes. Trust `repo:ORG/REPO:*` (no reusable `job_workflow_ref`).
4. **Paid YAML SHALL NOT declare Vocareum key inputs.** Fail if `AWS_ACCESS_KEY_ID` is set or `AWS_ROLE_TO_ASSUME` is empty. Academy SHALL NOT receive `id-token: write`.
5. **REST ALB `internal = false`, `subnets = public`.** Listener stays :8080 so `REST_BASE_URL=http://<dns>:8080` stays valid. Portal nginx still proxies `/api`. `sync-secrets` CORS includes both ALB origins. Haystack ALB stays internal. ADR 0018.
6. **Paid SSM bucket** `heavy-rental-ssm-<account>-actual`. Guest IAM GetObject/ListBucket only. Not the tfstate bucket (ADR 0012 consequence).
7. **Conflict order:** OpenSpec → OpenSPDD Safeguards → ADR 0017/0018/0019 → YAML / `.tf`.

## Risks / Trade-offs

- Replacing the REST ALB (scheme/subnet change) issues a new DNS name; `sync-secrets` must run after apply.
- Portal in a private subnet reaches the public REST ALB via NAT (hairpin). Covered by 0.0.0.0/0 on :8080.
- Public Tomcat :8080. Blast radius stays REST ALB only: no public 8000/5432/7687; REST instances have no public IP.
- HTTP only. Stripe webhooks that require HTTPS still need a later listener.
- Paid first-compose is `deploy-projects` on the paid Action. Day-to-day paid rolls are the app-CD paid callers in the other repo.
- Feasibility §6P still says internal REST and Environment `paid`. This change records the divergence in ADR 0017 / 0018; it does not edit the study.
