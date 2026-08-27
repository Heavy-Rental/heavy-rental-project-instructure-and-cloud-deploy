# Tasks: add-infra-academy-bootstrap

## 1. OpenSpec + OpenSPDD + ADR

- [x] 1.1 `openspec/config.yaml`, proposal, design, tasks, four capability specs
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADRs 0001–0003
- [x] 1.4 `specification/README.md`

## 2. Workflow (Academy / Vocareum only)

- [x] 2.1 `aws-infra-academy.yml` with form keys + Environment fallback + mask
- [x] 2.2 Refuse `aws_environment` ≠ `academy`
- [x] 2.3 Real `assert-lab` (`sts get-caller-identity`)
- [x] 2.4 `ensure-backend` then `terraform plan` on placeholder
- [x] 2.5 `apply` / configure / stop / destroy fail closed

## 3. Terraform

- [x] 3.1 `terraform/backend/` S3 native lockfile (no DynamoDB, no IAM role)
- [x] 3.2 `terraform/academy/` remote backend + placeholder (no VPC)

## 4. Operator docs

- [x] 4.1 `BOOTSTRAP.md` — Environment `academy`, every Start Lab
- [x] 4.2 Point `IMPLEMENTATION-PLAN.md` at OpenSpec / SPDD / ADR
