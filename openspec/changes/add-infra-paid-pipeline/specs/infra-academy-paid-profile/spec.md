# Delta for infra-academy-paid-profile (two Actions)

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-paid-profile/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): paid also creates `hr-paid-bastion`. App profiles stay `hr-paid-{portal,rest,haystack,neo4j}`.

## Purpose

Isolation between Vocareum and billed AWS remains. The operator entry point is two Actions, not one workflow with two Environments.

## MODIFIED Requirements

### Requirement: Two Actions, not two profiles on one workflow
Paid SHALL NOT be selectable on `.github/workflows/aws-infra-academy.yml`. Vocareum key inputs SHALL NOT appear on `.github/workflows/aws-infra-paid.yml`. Isolation that still holds: OIDC vs Vocareum, separate state buckets (`-academy` / `-actual`), Terraform-created `hr-paid-*` on paid, no `AWS_ACCESS_KEY_ID` on Environment `AWS_ACTUAL`. This requirement **replaces** “Environment is academy or paid” and “Paid uses OIDC and created profiles” as they were written for a single Action.

#### Scenario: Paid form cannot receive lab keys
- GIVEN an operator opens Run workflow on `aws-infra-paid.yml`
- THEN `aws_access_key_id` is not an input
- AND pasting Vocareum keys into that Action is not possible

#### Scenario: Isolation still uses separate state
- GIVEN a successful paid apply and a successful academy apply in different accounts or sessions
- THEN the paid backend bucket name ends with `-actual`
- AND the academy backend bucket name ends with `-academy`
- AND the two profiles do not share a state object

### Requirement: Academy still uses Vocareum and LabRole
When the academy Action runs, the workflow SHALL authenticate with Vocareum form keys or Environment `AWS_*` session credentials. Guests SHALL use `LabInstanceProfile` → `LabRole`. Terraform SHALL NOT create `aws_iam_role` when `deployment` is `academy`.

#### Scenario: Academy apply does not create IAM
- GIVEN Environment `academy` and a live Start Lab session
- WHEN `action=plan` or `apply` runs on `aws-infra-academy.yml`
- THEN the plan does not create `aws_iam_role`
- AND launch templates use `LabInstanceProfile`
