# Pinned versions (Academy estate)

Contract: `heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/` — AWS study §4.3 / §6.1 / §6.4 / §6.4a / §7.1, `TERRAFORM-PROCESS.md`, `ANSIBLE-PROCESS.md`.

Recorded **2026-08-16**. Terraform CLI is the live pin. Ansible and compose image rows are **branch 3** (not installed in `aws-infra-academy.yml` yet).

## Toolchain

| Component | Design source | Recorded version | Where pinned |
| --- | --- | --- | --- |
| Terraform CLI | `TERRAFORM-PROCESS.md` | **1.15.8** (latest stable, 8 Jul 2026) | `.github/workflows/aws-infra-academy.yml` (`terraform_version`); `terraform/{backend,academy}/versions.tf` (`required_version >= 1.15.8`) |
| hashicorp/aws provider | estate `.tf` | `~> 5.0` (do not bump; latest is 6.60.0) | `terraform/{backend,academy}/versions.tf` |
| hashicorp/setup-terraform | Actions | **v4.0.1** | `aws-infra-academy.yml` |
| actions/checkout | Actions | **v7.0.1** | `aws-infra-academy.yml` |
| aws-actions/configure-aws-credentials | Actions | **v6.2.3** | `aws-infra-academy.yml` |
| Ansible community package | `ANSIBLE-PROCESS.md` / study §7.1a | **14.3.1** (depends on ansible-core **2.21.3**) | `aws-infra-academy.yml` (`pip install ansible==14.3.1`) |
| amazon.aws collection | ansible `_text` deprecation | **>=11.3.0,<12** (uses `common.text.converters`) | `ansible/requirements.yml` |

## Estate runtime

| Component | Design source | Recorded version |
| --- | --- | --- |
| Guest AMI | study §6.2b / `terraform/academy/data.tf` | Amazon Linux 2023 via `aws_ami` (`al2023-ami-*-kernel-*-x86_64`, owner `amazon`). Not the public SSM parameter (often AccessDenied on Vocareum). |
| RDS PostgreSQL | study §6.1 / `rds.tf` | Two instances: SoR `heavy_rental` + Haystack `haystack`. Prefer engine **12.22**, then 11.22. |
| RDS class | study §6.4 | `db.t3.micro` (both) |
| Neo4j | study §6.1 / ANSIBLE §4.4 | `neo4j:5` (branch 3 compose) |
| REST image | study §4.3 | `tomcat:10.1-jdk21` (branch 3 compose) |
| Haystack runtime | study §4.3 | Python **3.12** + uv + uvicorn (branch 3 compose) |
| pgvector fallback | study §6.1 | `pgvector/pgvector:pg17` (branch 3, only if RDS cannot `CREATE EXTENSION vector`) |
| Portal | study §6.4a | nginx (no numeric tag in the study; branch 3 compose) |
| Instance types | study §6.4 | NAT Gateway **x2** (not EC2); portal `t3.micro` **x2**; rest/haystack `t3.small` **x2**; neo4j `t3.large` **x2** (8 EC2) |
