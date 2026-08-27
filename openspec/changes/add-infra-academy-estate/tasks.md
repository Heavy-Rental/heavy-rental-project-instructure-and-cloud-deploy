# Tasks: add-infra-academy-estate

## 1. OpenSpec + OpenSPDD + ADR

- [x] 1.1 Proposal, design, tasks, six new capability specs + plan/scope deltas
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADRs 0004–0008
- [x] 1.4 Update `specification/README.md`, `docs/adr/README.md`, `BOOTSTRAP.md`, `IMPLEMENTATION-PLAN.md`

## 2. Terraform estate (`terraform/academy/`)

- [x] 2.1 VPC, three subnet tiers (2 AZs), IGW, two NAT Gateways, S3 gateway endpoint
- [x] 2.2 Security groups per AWS study §6.2
- [x] 2.3 Four launch templates + ASGs (`LabInstanceProfile`, no `key_name`)
- [x] 2.4 Public portal ALB + REST/Haystack ALBs (REST internet-facing :8080 is later `add-infra-paid-pipeline` / ADR 0018)
- [x] 2.5 Two Multi-AZ RDS in the data subnet group; Bolt NLB; `asg-neo4j` desired=2
- [x] 2.6 Empty SM shells + ECR repos; outputs
- [x] 2.7 `terraform validate`; no IAM role / NAT instance / PEM resources

## 3. Workflow

- [x] 3.1 `action=apply` runs `init` → `plan` → `apply`
- [x] 3.2 Vocareum form keys unchanged; refuse Environment ≠ `academy`
- [x] 3.3 `TF_VAR_db_master_password` from `SPRING_DATASOURCE_PASSWORD`; refuse apply if unset
- [x] 3.4 `configure-only` / `stop` / `destroy` still fail closed
