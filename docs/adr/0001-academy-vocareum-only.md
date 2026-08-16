# ADR 0001: Academy / Vocareum only on the first pipeline

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-bootstrap`

## Context

Heavy Rental has two AWS destinations: Vocareum Learner Lab (Academy) and a billed account (paid). Academy cannot create IAM roles or an OIDC provider. Paid must not receive Vocareum access keys.

## Decision

The first infrastructure workflow is **AWS Academy / Vocareum only** (`.github/workflows/aws-infra-academy.yml`). It requires GitHub Environment `academy` and refuses any other Environment name. A paid/OIDC workflow is a later branch and MUST NOT be added here.

## Consequences

- Class can run `plan` with Start Lab credentials without standing up OIDC.
- Mixing academy keys with a billed account is a failed `assert-lab`, not a silent apply.
- Paid operators wait for a separate workflow and state key.
