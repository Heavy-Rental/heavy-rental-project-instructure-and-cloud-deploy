# Proposal: Dual profile — Vocareum academy and paid public AWS

> **Superseded in part by** [`add-infra-paid-pipeline`](../add-infra-paid-pipeline/proposal.md) / [ADR 0017](../../../docs/adr/0017-two-actions-academy-paid.md) / [ADR 0019](../../../docs/adr/0019-separate-job-graphs.md). Isolation stands (OIDC vs Vocareum, separate state, `hr-paid-*`). Live names: GitHub Environment **`AWS_ACTUAL`**, S3 suffix **`-actual`**, two Actions. Do not use Environment `paid` or suffix `-paid`.

## Why

The Run form already asks for `aws_environment`, but the workflow refuses anything except `academy`. Operators cannot apply the same estate to a billed AWS account. Feasibility §6P requires a **separate Environment, state key, and auth** (OIDC), never Vocareum keys on paid.

## What Changes

- Same workflow file: operator picks Environment **`academy`** or **`paid`**.
- Academy path unchanged (Vocareum keys, `LabRole`).
- Paid path: GitHub OIDC (`AWS_ROLE_TO_ASSUME`), created instance profiles, state bucket suffix `-paid`.
- Fail closed if the wrong secret style is present (keys on paid, missing LabRole on academy).
- OpenSpec, OpenSPDD, ADR 0016 (partially supersedes ADR 0001).

## Capabilities

### New Capabilities

- `infra-academy-paid-profile`

### Modified Capabilities

- `infra-academy-scope`: `aws_environment` may be `academy` or `paid`

## Impact

- **Operators** create a paid GitHub Environment and an OIDC role once. **Current name:** `AWS_ACTUAL` (not `paid`).
- **Academy** class path is unchanged if they keep selecting `academy`.
- **Not in this change:** required HTTPS, CloudTrail→Logs on paid, a second workflow file.
