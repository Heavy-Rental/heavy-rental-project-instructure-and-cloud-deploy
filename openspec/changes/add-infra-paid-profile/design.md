# Design: academy | paid profile on one Action

## Context

ADR 0001 made `aws-infra-academy.yml` Vocareum-only so lab keys could not hit a billed account. Operators now need to **select** Vocareum vs public AWS on that same Action. Feasibility §6P: paid is another account + state + OIDC; guests must not use `LabRole`.

## Goals / Non-Goals

**Goals:**

- `aws_environment` = `academy` | `paid` only.
- Academy: existing keys + `LabInstanceProfile` / `LabRole`. No `aws_iam_role` created.
- Paid: OIDC role from Environment `AWS_ROLE_TO_ASSUME`. Four instance profiles. No Vocareum form keys and no `AWS_ACCESS_KEY_ID` on Environment `paid`.
- Separate state buckets: `heavy-rental-tfstate-<account>-<profile>`.
- Same actions (`plan` / `apply` / …) on both profiles.

**Non-Goals:**

- A second YAML workflow as the operator’s entry point
- Mandatory ACM HTTPS (optional `PORTAL_ACM_ARN` later)
- Sharing one Terraform state between profiles
- Marketplace Neo4j CFT

## Decisions

1. **One workflow, two GitHub Environments.** Display name `AWS infrastructure`.
2. **Paid auth is OIDC only.** Vocareum key inputs stay on the form (GitHub cannot hide them) but paid **fails** if they are non-empty.
3. **One Terraform root** (`terraform/academy`) with `var.deployment`. IAM **resources** exist only when `deployment == paid`.
4. **Concurrency** per Environment so academy and paid can run together.
5. **Conflict order:** OpenSpec → OpenSPDD → ADR 0016 + 0005 → YAML / `.tf`.

## Risks

- Single root could plan IAM on academy. Mitigate with `for_each` + academy preflight.
- Operators might paste lab keys on a paid run — fail closed.
- Paid OIDC role must be created out of band; apply cannot create the GitHub trust role it is using.
