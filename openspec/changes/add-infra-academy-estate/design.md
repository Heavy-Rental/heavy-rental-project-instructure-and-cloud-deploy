# Design: Academy / Vocareum estate

## Context

AWS study §6 / §8.1 and `TERRAFORM-PROCESS.md` define a three-tier VPC on Vocareum: public portal ALB only, internal REST and Haystack ALBs, one RDS, one Neo4j ASG (`max=1`), `LabInstanceProfile` on every guest, NAT **instance** (not Gateway). Branch 1 left `terraform/academy/` as a placeholder so `plan` could succeed without spending credits.

## Goals / Non-Goals

**Goals:**

- `action=plan` shows add/change of VPC, ASGs, ALBs, RDS, SM shells.
- `action=apply` creates those resources in the estate state key from branch 1.
- Outputs: public + internal ALB DNS, RDS endpoint, Neo4j private IP, secret ARNs, ASG names.
- Academy legal: no `aws_iam_role`, no NAT Gateway, no Marketplace AMI, no Multi-AZ, no `tls_private_key`.

**Non-Goals:**

- Filling Secrets Manager JSON (`sync-secrets` is branch 3)
- Docker / compose / nginx `/api` (Ansible, branch 3)
- `action=stop` / `action=destroy`
- Paid / OIDC, HTTPS on the portal ALB, ELB health replacement (empty guests would flap)

## Decisions

1. **NAT instance `t3.nano`** in a public subnet; private app and data routes use its ENI. ADR 0004.
2. **`LabInstanceProfile` data source** on NAT + four launch templates. ADR 0005.
3. **Empty SM shells** (`recovery_window_in_days = 0`). No `secret_version`. ADR 0006.
4. **Dedicated ENI for `asg-neo4j`** so Bolt IP is a Terraform output. ADR 0007.
5. **ASG health = EC2** on portal / REST / Haystack until compose. Target groups still register. ADR 0008.
6. **RDS password** from Environment `SPRING_DATASOURCE_PASSWORD` (`TF_VAR_db_master_password`). Not on the Run form. Not written to SM on this branch.
7. **Conflict order:** OpenSpec → OpenSPDD Safeguards → ADR → `.tf` / YAML.

## Risks / Trade-offs

- Three ALBs + RDS + `t3.large` Neo4j spend lab credits. Session end does not stop them.
- Empty guests: public ALB returns 502 until branch 3. ASG will not replace them (EC2 health).
- Shared `LabRole` can read every secret once values exist. Isolation stays convention (Ansible).
- Dedicated Neo4j ENI pins the graph host to one data subnet (still `max=1`).
