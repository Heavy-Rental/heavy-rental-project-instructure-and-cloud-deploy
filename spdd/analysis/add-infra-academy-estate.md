# SPDD Analysis: add-infra-academy-estate

**Status:** Active (NAT and data plane match ADRs 0010 / 0007; REST ALB scheme is later `add-infra-paid-pipeline` / ADR 0018)  
**Audience:** Implementers of the Academy / Vocareum estate (`action=apply`)  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-estate.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-estate/proposal.md)

## Problem

Branch 1 can `terraform plan` an empty estate. The class still cannot reach a portal ALB or an RDS endpoint. Creating guest compose in the same change would hide a bad VPC behind Ansible noise. This change creates the AWS resources only.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Estate | Three-tier VPC + two NAT Gateways + four ASGs (desired=2) + three ALBs + two Multi-AZ RDS + Bolt NLB + SM shells + ECR |
| NAT Gateway | `aws_nat_gateway` + EIP in each public AZ; private route tables are per-AZ. **Not** a NAT instance (ADR 0010 supersedes 0004) |
| LabInstanceProfile | Pre-created Vocareum profile; **never** create IAM |
| Secret shell | `aws_secretsmanager_secret` with no version |
| Bolt NLB | Internal NLB :7687 in front of two Neo4j guests (`asg-neo4j` desired=2). `neo4j_uri` is `bolt://<nlb-dns>:7687` |
| EC2 health | ASG does not replace empty nginx/Tomcat/uvicorn guests |
| REST ALB (this change) | Dedicated ALB :8080. **Later** `add-infra-paid-pipeline` makes it internet-facing in public subnets (ADR 0018) |
| Paid | Another workflow / state key (`add-infra-paid-pipeline`) |

## Stakeholders

- Class operators (`apply` after Start Lab; watch credits)
- Branch 3 (`sync-secrets`, Ansible, stop, destroy)
- App CD (discover `asg-*` + secret ids)

## Risks

1. **IAM create** — Vocareum rejects `aws_iam_role`. Data-source the profile.
2. **NAT Gateway hours** — two Gateways bill until `destroy`; session end and `stop` do not pause them. Operator-accepted (ADR 0010).
3. **ELB health on empty guests** — ASG would loop replace. Use EC2 health.
4. **Password in logs** — mask `TF_VAR_db_master_password`; never echo it.
5. **RDS/ALB/NAT after session end** — still bill. Operator must later `stop`/`destroy`.
6. **Marketplace Neo4j** — rejected. Host is Amazon Linux + later `neo4j:5`.

## Strategy

1. Specify behavior (OpenSpec capabilities above).
2. Bind safeguards in the REASONS Canvas and ADRs 0005–0008 and **0010** (not 0004 as the live NAT decision).
3. Replace `terraform/academy/` placeholder; enable workflow `apply`.
4. Leave configure / stop / destroy failing on this branch (later `add-infra-academy-configure`).

## Success

- `action=apply` after Start Lab creates `asg-portal|rest|haystack|neo4j` at desired=2.
- Two NAT Gateways, two Multi-AZ RDS (`heavy_rental` + `haystack`), internal Bolt NLB.
- `terraform validate` is green. No `aws_iam_role` / NAT **instance** / `tls_private_key` / `aws_secretsmanager_secret_version`.
- `configure-only` still exits 1 on this branch.
