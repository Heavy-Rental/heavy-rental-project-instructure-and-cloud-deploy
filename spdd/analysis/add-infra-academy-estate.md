# SPDD Analysis: add-infra-academy-estate

**Status:** Active  
**Audience:** Implementers of the Academy / Vocareum estate (`action=apply`)  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-estate.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-estate/proposal.md)

## Problem

Branch 1 can `terraform plan` an empty estate. The class still cannot reach a portal ALB or an RDS endpoint. Creating guest compose in the same change would hide a bad VPC behind Ansible noise. This change creates the AWS resources only.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Estate | VPC + NAT instance + four ASGs + three ALBs + one RDS + SM shells + ECR |
| NAT instance | `t3.nano` Amazon Linux in a public subnet; source/dest check off |
| LabInstanceProfile | Pre-created Vocareum profile; **never** create IAM |
| Secret shell | `aws_secretsmanager_secret` with no version |
| Dedicated Neo4j ENI | Stable private IP for `NEO4J_URI` |
| EC2 health | ASG does not replace empty nginx/Tomcat/uvicorn guests |
| Paid | Still another workflow / state key |

## Stakeholders

- Class operators (`apply` after Start Lab; watch credits)
- Branch 3 (`sync-secrets`, Ansible, stop, destroy)
- App CD (discover `asg-*` + secret ids)

## Risks

1. **IAM create** — Vocareum rejects `aws_iam_role`. Data-source the profile.
2. **NAT Gateway** — hourly cost and sometimes blocked. Use a nano instance.
3. **ELB health on empty guests** — ASG would loop replace. Use EC2 health.
4. **Password in logs** — mask `TF_VAR_db_master_password`; never echo it.
5. **RDS/ALB after session end** — still bill. Operator must later `stop`/`destroy`.
6. **Marketplace Neo4j** — rejected. Host is Amazon Linux + later `neo4j:5`.

## Strategy

1. Specify behavior (OpenSpec capabilities above).
2. Bind safeguards in the REASONS Canvas and ADRs 0004–0008.
3. Replace `terraform/academy/` placeholder; enable workflow `apply`.
4. Leave configure / stop / destroy failing.

## Success

- `action=apply` after Start Lab creates `asg-portal|rest|haystack|neo4j`.
- `terraform validate` is green. No `aws_iam_role` / `aws_nat_gateway` / `tls_private_key` / `aws_secretsmanager_secret_version`.
- `configure-only` still exits 1.
