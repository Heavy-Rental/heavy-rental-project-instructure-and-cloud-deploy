# ADR 0005: LabInstanceProfile only — never create IAM

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

AWS Academy cannot create IAM users, groups, or roles. Vocareum pre-creates `LabRole` / `LabInstanceProfile`. GitHub OIDC is also forbidden on this account.

## Decision

Every launch template **data-source** `LabInstanceProfile` by name and **data-source** `LabRole`. Plan fails unless the profile’s role is `LabRole`. Terraform SHALL NOT contain `aws_iam_role` / `aws_iam_instance_profile` **resources**, or an OIDC provider. NAT Gateways have no instance profile.

## Consequences

- Apply works under the Vocareum federated user.
- All guests share `LabRole` (Academy accepted risk). Per-secret isolation waits for paid instance profiles.
- If the profile name differs in a future lab image, apply fails at plan — operators fix the data source, they do not create IAM.
