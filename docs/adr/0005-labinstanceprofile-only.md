# ADR 0005: LabInstanceProfile only — never create IAM

- **Status:** Accepted for **Academy**. Paid IAM is [0016](0016-dual-profile-academy-paid.md) / [0017](0017-two-actions-academy-paid.md) (`hr-paid-*` when `deployment=actual`, including `hr-paid-bastion` in [0021](0021-maintenance-bastion-ssh.md)). This file still forbids `aws_iam_role` on Vocareum.
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

AWS Academy cannot create IAM users, groups, or roles. Vocareum pre-creates `LabRole` / `LabInstanceProfile`. GitHub OIDC is also forbidden on this account.

## Decision

On Academy (`deployment=academy`), every launch template **data-source** `LabInstanceProfile` by name and **data-source** `LabRole`. Plan fails unless the profile’s role is `LabRole`. Academy Terraform SHALL NOT contain `aws_iam_role` / `aws_iam_instance_profile` **resources**, or an OIDC provider. NAT Gateways have no instance profile. Paid (`deployment=actual`) is the exception in ADR 0016 / 0017.

## Consequences

- Apply works under the Vocareum federated user.
- All guests share `LabRole` (Academy accepted risk). Per-secret isolation waits for paid instance profiles.
- If the profile name differs in a future lab image, apply fails at plan — operators fix the data source, they do not create IAM.
- Monitor (CloudTrail / flow logs) also stays on this pairing; see [0015](0015-academy-observe-no-iam.md).
