# REASONS Canvas: add-infra-academy-estate

**Input analysis:** [add-infra-academy-estate.md](../analysis/add-infra-academy-estate.md)  
**Behavior contract:** [OpenSpec change](../../openspec/changes/add-infra-academy-estate/)

When reality diverges, fix this prompt first — then update YAML / `.tf`.

---

## R — Requirements

- Academy / Vocareum only. Environment must be `academy`. Form keys unchanged.
- `action=plan` plans the estate. `action=apply` creates it.
- Three-tier VPC, **two NAT Gateways** (one per public AZ), §6.2 security groups, four ASGs at desired=2, three ALBs, **two Multi-AZ RDS**, Bolt NLB, SM shells, ECR.
- `LabInstanceProfile` only. No IAM role, NAT **instance**, Marketplace AMI, PEM in Terraform.
- RDS password from Environment `SPRING_DATASOURCE_PASSWORD`. Fail apply if missing.
- `configure-only` / `stop` / `destroy` fail on this branch.
- REST ALB scheme (internet-facing :8080) is **not** this canvas — see `add-infra-paid-pipeline` and ADR 0018.

## E — Entities

```mermaid
classDiagram
    class AcademyWorkflow {
      +action plan|bootstrap|apply
      +vocareum key inputs
    }
    class EstateStack {
      +vpc
      +natGatewayAz0
      +natGatewayAz1
      +asgPortal rest haystack neo4j
      +albPortal rest haystack
      +rdsSor
      +rdsHaystack
      +boltNlb
      +secretShells
    }
    class LabInstanceProfile {
      +dataSource
    }
    AcademyWorkflow --> EstateStack
    EstateStack --> LabInstanceProfile
```

## A — Approach

1. Data-source AMI (AL2023 SSM parameter) and `LabInstanceProfile`.
2. VPC + routes; two NAT Gateways + EIP; per-AZ private route tables; S3 gateway endpoint.
3. Security groups as separate ingress/egress rules (avoid cycles).
4. Launch templates + ASGs (desired=2); Neo4j in data subnets; EC2 health on app ASGs.
5. ALBs + target groups (register, but ASG health stays EC2). Bolt NLB :7687.
6. Two RDS `db.t3.micro` Multi-AZ + empty SM secrets + ECR.
7. Workflow: remove branch-1 apply refuse; pass `TF_VAR_db_master_password`.

## S — Structure

```
terraform/academy/{variables,data,vpc,nat,security_groups,alb,compute,rds,secrets,ecr,outputs}.tf
.github/workflows/aws-infra-academy.yml
openspec/changes/add-infra-academy-estate/
spdd/{analysis,prompt}/add-infra-academy-estate.md
docs/adr/0005–0008, 0010
```

## O — Operations

| action | This branch |
| --- | --- |
| plan | init + plan estate |
| bootstrap | backend only |
| apply | init + plan + apply |
| configure-only / stop / destroy | fail closed |

## N — Norms

- Mask Vocareum keys and the DB password. `set +x` on credential steps.
- Do not print `SecretString` or `sk_`.
- Public portal ALB DNS may appear in the step summary.
- Bind `github.*` / `inputs.*` through `env:` in `run:` scripts.

## S — Safeguards

- No `aws_iam_role`, NAT **instance**, `tls_private_key`, `key_name`, `aws_secretsmanager_secret_version`.
- NAT **is** two `aws_nat_gateway` (ADR 0010). Do not reintroduce `aws_instance` used as NAT.
- No Vocareum keys in SM or on the guest.
- No paid workflow / OIDC on this branch.
- Apply refuses empty or plan-only DB password.
- ASG health = EC2 (ADR 0008). Compose later did **not** switch to ELB health.

## Negative space

Do not invent: IAM roles, NAT **instance**, Marketplace Neo4j CFT, HTTPS listener, Ansible, `put-secret-value` of app fields, ELB health replacement, `destroy` on this branch, a third RDS for the sync worker.
