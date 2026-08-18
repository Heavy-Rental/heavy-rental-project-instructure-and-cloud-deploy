# Specification (Academy infra CD)

This folder is the **human index** for the estate in `heavy-rental-project-instructure-and-cloud-deploy/`.

**Terraform** creates AWS architecture and resources. **Ansible** only configures guests that already exist. App CD (Haystack / REST / portal images) is not specified here — it lives in `heavy-rental-project-pipeline-development`.

Reference studies: `heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/` (`AWS-INFRASTRUCTURE-FEASIBILITY.md`, `TERRAFORM-PROCESS.md`, `ANSIBLE-PROCESS.md`).

## Pipeline boundaries

| Concern | This repo? |
| --- | --- |
| VPC, subnets, NAT Gateways, ASGs, ALBs, RDS, NLB, SM shells | Yes — Terraform |
| Fill SM JSON, guest Docker / `.env` / compose, PEMs after InService | Yes — scripts + Ansible (configuration) |
| Redeploy a new portal / REST / Haystack CI image | No — app CD |
| Paid / OIDC | No — later |
| Operate after go-live (CloudWatch day-to-day) | Knowledge only; `stop` / `destroy` are infra actions |

## How to read the three frameworks

| Framework | Path | Role |
| --- | --- | --- |
| **OpenSpec** | [`../openspec/`](../openspec/) | Observable behavior: SHALL + GIVEN/WHEN/THEN |
| **OpenSPDD** | [`../spdd/`](../spdd/) | REASONS Canvas (how to implement, what not to invent) |
| **ADR** | [`../docs/adr/`](../docs/adr/) | Why: Vocareum-only, two NAT Gateways, SSM, `SOURCE_*` / `TARGET_*` |

Conflict order: **OpenSpec scenarios → OpenSPDD Safeguards → ADR → YAML / Terraform**. If code cannot satisfy a scenario without breaking a safeguard, update the spec first.

## Operator docs

- Everyday run: [`../docs/BOOTSTRAP.md`](../docs/BOOTSTRAP.md)
- Layout: [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md)
- Program plan: [`../docs/IMPLEMENTATION-PLAN.md`](../docs/IMPLEMENTATION-PLAN.md)

## Walkthroughs

- [`pipelines/infra-academy.md`](pipelines/infra-academy.md) — `plan` / `apply` / `configure-only` / `stop` / `destroy` / `bootstrap`
- [`pipelines/infra-secrets.md`](pipelines/infra-secrets.md) — Secrets Manager JSON

## Changes

| Change | Role |
| --- | --- |
| [`../openspec/changes/add-infra-academy-bootstrap/`](../openspec/changes/add-infra-academy-bootstrap/) | Auth + remote state |
| [`../openspec/changes/add-infra-academy-estate/`](../openspec/changes/add-infra-academy-estate/) | Terraform estate |
| [`../openspec/changes/add-infra-academy-configure/`](../openspec/changes/add-infra-academy-configure/) | `sync-secrets`, Ansible configure, stop |

SPDD: [`../spdd/analysis/`](../spdd/analysis/). ADRs 0001–0013: [`../docs/adr/`](../docs/adr/).
