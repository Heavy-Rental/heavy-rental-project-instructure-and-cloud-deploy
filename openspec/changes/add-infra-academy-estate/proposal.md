# Proposal: Add Academy / Vocareum estate (`action=apply`)

## Why

Branch 1 proved Vocareum auth and remote Terraform state. The class still has no VPC. Branch 2 (`feat/infra-academy-estate`, delivered on `HR-161`) must create the three-tier Academy estate from GitHub Actions `action=apply` so later configure / app CD have ASGs, ALBs, RDS, and empty Secrets Manager shells.

## What Changes

- OpenSpec, OpenSPDD, and ADRs 0004–0008 for this branch.
- Replace `terraform/academy/` placeholder with the §6 estate (VPC, NAT **instance**, SGs, four ASGs, three ALBs, one RDS, SM shells, ECR).
- Enable `action=apply` on `aws-infra-academy.yml` (`init` → `plan` → `apply`). Vocareum form keys unchanged.
- `configure-only` / `stop` / `destroy` stay fail-closed.

## Capabilities

### New Capabilities

- `infra-academy-estate-vpc`
- `infra-academy-estate-sg`
- `infra-academy-estate-compute`
- `infra-academy-estate-data`
- `infra-academy-estate-secrets-shells`
- `infra-academy-estate-apply`

### Modified Capabilities

- `infra-academy-plan`: plan now describes the estate (VPC/ALB/RDS/ASG), not a placeholder
- `infra-academy-scope`: `apply` of the estate is allowed; configure / stop / destroy still are not

## Impact

- **This repo:** first billable Academy resources. Operators add Environment secret `SPRING_DATASOURCE_PASSWORD` before `apply`.
- **Not in this change:** `sync-secrets` values, SSH PEMs, Ansible compose, `stop` / `destroy`, paid OIDC, app CD.
