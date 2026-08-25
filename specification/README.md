# Specification (Academy infra CD)

This folder is the **human index** for the estate in `heavy-rental-project-instructure-and-cloud-deploy/`.

**Terraform** creates AWS architecture and resources. **Ansible** only configures guests that already exist. App CD (Haystack / REST / portal images) is not specified here — it lives in `heavy-rental-project-pipeline-development`.

Reference studies: `heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/` (`AWS-INFRASTRUCTURE-FEASIBILITY.md`, `TERRAFORM-PROCESS.md`, `ANSIBLE-PROCESS.md`).

## Pipeline boundaries

| Concern | This repo? |
| --- | --- |
| VPC, subnets, NAT Gateways, ASGs, ALBs, RDS, NLB, SM shells | Yes — Terraform |
| Fill SM JSON, guest Docker / `.env` / compose, PEMs after InService | Yes — scripts + Ansible (configuration) |
| Redeploy a new portal / REST / Haystack CI image | Day-to-day: app CD. Optional first-compose: `action=deploy-projects` (after apply) |
| Public AWS | Yes — `aws-infra-paid.yml`, Environment `AWS_ACTUAL`, OIDC (ADR 0017) |
| Operate after go-live | SSM, `stop`, `destroy` |
| Monitor (CloudWatch / CloudTrail) | Yes — Terraform on `apply` (ADR 0015). Trail and flow logs are S3-only. Academy: LabRole only. Paid trail/dashboard `heavy-rental-actual`. |

## How to read the three frameworks

| Framework | Path | Role |
| --- | --- | --- |
| **OpenSpec** | [`../openspec/`](../openspec/) | Observable behavior: SHALL + GIVEN/WHEN/THEN |
| **OpenSPDD** | [`../spdd/`](../spdd/) | REASONS Canvas (how to implement, what not to invent) |
| **ADR** | [`../docs/adr/`](../docs/adr/) | Why: Vocareum-only, two Actions, public REST ALB, two NAT Gateways, SSM |

Conflict order: **OpenSpec scenarios → OpenSPDD Safeguards → ADR → YAML / Terraform**. If code cannot satisfy a scenario without breaking a safeguard, update the spec first.

## Operator docs

- Beginner walkthrough: [`../OPERATOR-GUIDE.md`](../OPERATOR-GUIDE.md)
- Everyday run: [`../docs/BOOTSTRAP.md`](../docs/BOOTSTRAP.md)
- Layout: [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md)
- Program plan: [`../docs/IMPLEMENTATION-PLAN.md`](../docs/IMPLEMENTATION-PLAN.md)

## Walkthroughs

- [`pipelines/infra-academy.md`](pipelines/infra-academy.md) — Vocareum Action
- [`pipelines/infra-paid.md`](pipelines/infra-paid.md) — billed OIDC Action
- [`pipelines/infra-secrets.md`](pipelines/infra-secrets.md) — Secrets Manager JSON

## Changes

| Change | Role |
| --- | --- |
| [`../openspec/changes/add-infra-academy-bootstrap/`](../openspec/changes/add-infra-academy-bootstrap/) | Auth + remote state |
| [`../openspec/changes/add-infra-academy-estate/`](../openspec/changes/add-infra-academy-estate/) | Terraform estate |
| [`../openspec/changes/add-infra-academy-configure/`](../openspec/changes/add-infra-academy-configure/) | `sync-secrets`, Ansible configure, stop |
| [`../openspec/changes/add-infra-academy-deploy-projects/`](../openspec/changes/add-infra-academy-deploy-projects/) | `deploy-projects` later run of `site.yml` |
| [`../openspec/changes/add-infra-academy-observe/`](../openspec/changes/add-infra-academy-observe/) | CloudWatch + CloudTrail on apply (LabRole, S3 trail) |
| [`../openspec/changes/add-infra-paid-profile/`](../openspec/changes/add-infra-paid-profile/) | Dual profile on one Action (superseded in part by paid-pipeline) |
| [`../openspec/changes/add-infra-paid-pipeline/`](../openspec/changes/add-infra-paid-pipeline/) | Dedicated paid Action + public REST ALB; separate job graphs (ADRs 0017–0019) |

SPDD: [`../spdd/analysis/`](../spdd/analysis/). ADRs 0001–0019: [`../docs/adr/`](../docs/adr/).
