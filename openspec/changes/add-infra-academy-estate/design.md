# Design: Academy / Vocareum estate

## Context

AWS study §6 / §8.1 and `TERRAFORM-PROCESS.md` define a three-tier VPC on Vocareum: two Multi-AZ RDS (`heavy_rental` + `haystack`), four ASGs at desired=2, `LabInstanceProfile` on every guest, **two NAT Gateways** (one per public AZ). The study’s internal REST ALB is **not** the live scheme — REST public :8080 is later [`add-infra-paid-pipeline`](../add-infra-paid-pipeline/proposal.md) / ADR 0018. Branch 1 left `terraform/academy/` as a placeholder so `plan` could succeed without spending credits.

## Goals / Non-Goals

**Goals:**

- `action=plan` shows add/change of VPC, ASGs, ALBs, RDS, SM shells.
- `action=apply` creates those resources in the estate state key from branch 1.
- Outputs: ALB DNS, both RDS endpoints, `neo4j_uri` (Bolt NLB), secret ARNs, ASG names.
- Academy legal: no `aws_iam_role`, no Marketplace AMI, no `tls_private_key`. NAT is two Gateways (ADR 0010). App/RDS/Neo4j are Multi-AZ.

**Non-Goals:**

- Filling Secrets Manager JSON (`sync-secrets` is branch 3)
- Docker / compose / nginx `/api` (Ansible, branch 3)
- `action=stop` / `action=destroy`
- Paid / OIDC, HTTPS on the portal ALB, ELB health replacement (empty guests would flap)

## Decisions

1. **Two NAT Gateways** (one per public AZ) + per-AZ private route tables. ADR 0010 (supersedes 0004).
2. **`LabInstanceProfile` data source** on the four launch templates. ADR 0005.
3. **Empty SM shells** (`recovery_window_in_days = 0`). No `secret_version`. ADR 0006.
4. **Two Neo4j guests + internal Bolt NLB.** `neo4j_uri` is `bolt://<nlb-dns>:7687`. ADR 0007 (supersedes a single dedicated ENI).
5. **ASG health = EC2** on portal / REST / Haystack until compose. Target groups still register. ADR 0008.
6. **RDS password** from Environment `SPRING_DATASOURCE_PASSWORD` (`TF_VAR_db_master_password`). Not on the Run form. Not written to SM on this branch.
7. **Conflict order:** OpenSpec → OpenSPDD Safeguards → ADR → `.tf` / YAML.

## Risks / Trade-offs

- Three ALBs + RDS + `t3.large` Neo4j spend lab credits. Session end does not stop them.
- Empty guests: public ALB returns 502 until branch 3. ASG will not replace them (EC2 health).
- Shared `LabRole` can read every secret once values exist. Isolation stays convention (Ansible).
- Two Neo4j guests sit behind the Bolt NLB (`asg-neo4j` desired=2). They are not a causal cluster.
