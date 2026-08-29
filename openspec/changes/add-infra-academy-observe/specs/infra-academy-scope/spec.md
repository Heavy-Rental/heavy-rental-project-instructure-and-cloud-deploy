# Delta for infra-academy-scope

> **Later modified by** [`add-infra-paid-profile`](../../../add-infra-paid-profile/specs/infra-academy-paid-profile/spec.md) / [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-paid-pipeline/spec.md): paid creates `hr-paid-*`. Academy observe still creates no IAM.  
> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-observe/spec.md): alarm `hr-bastion-status`.

## Purpose

Monitor resources are in scope for `apply` / `destroy`. Creating IAM is still out of scope **on Academy**.

## ADDED Requirements

### Requirement: Observe is part of apply, not a new action
CloudWatch, CloudTrail, the observe bucket, and SNS SHALL be created by the existing `action=apply` Terraform estate. The workflow SHALL NOT add a separate `observe` action.

#### Scenario: Plan includes observe
- GIVEN `action=plan` after observe Terraform is merged
- WHEN plan succeeds
- THEN the plan describes CloudTrail and CloudWatch alarms (create or no-op)
- AND no job named only for observe runs

## MODIFIED Requirements

### Requirement: No IAM create remains
On **Academy**, the estate (including observe) SHALL NOT create IAM roles, users, groups, instance profiles, or an OIDC provider. Academy guests and guest-side logs SHALL use Vocareum **`LabRole`** via **`LabInstanceProfile`**. **Current:** paid creates `hr-paid-*` (banner).

#### Scenario: LabRole is the only role
- GIVEN apply is requested
- WHEN preflight and plan run
- THEN `LabInstanceProfile` exists and its role is `LabRole`
- AND Terraform does not plan `aws_iam_role`
