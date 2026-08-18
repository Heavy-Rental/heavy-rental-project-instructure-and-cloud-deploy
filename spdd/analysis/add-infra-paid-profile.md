# SPDD Analysis: add-infra-paid-profile

**Status:** Active  
**Companion:** [REASONS Canvas](../prompt/add-infra-paid-profile.md) · [OpenSpec](../../openspec/changes/add-infra-paid-profile/proposal.md)

## Problem

Operators cannot select a billed AWS account on the infra Action. ADR 0001 blocked `paid` entirely. Feasibility §6P still forbids mixing Vocareum keys with that account.

## Concepts

| Concept | Meaning |
| --- | --- |
| Profile | `academy` (Vocareum) or `paid` (public AWS) |
| OIDC role | Environment `AWS_ROLE_TO_ASSUME` — GitHub Actions in the billed account |
| LabRole | Vocareum-only guest identity |
| hr-paid-* | Terraform-created instance profiles on paid |
| State suffix | `-academy` vs `-paid` on the tfstate bucket |

## Risks

1. Creating IAM on academy — `for_each` empty + preflight.
2. Pasting lab keys on paid — fail if form keys or `AWS_ACCESS_KEY_ID` present.
3. Looking up LabRole on paid — data source `count = 0`.
4. Shared state — bucket name includes profile.

## Success

- Selecting `academy` still applies with LabRole and no IAM resources.
- Selecting `paid` with OIDC applies `hr-paid-*` profiles and a `-paid` state bucket.
- Cross-wired secrets fail assert.
