# ADR 0002: Vocareum session keys on Run workflow

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-bootstrap`

## Context

Vocareum AWS Details (access key, secret, session token) **change every Start Lab**. Updating GitHub Environment secrets each session is slow. GitHub has no secret-typed `workflow_dispatch` input; values can appear on the run Inputs page.

## Decision

**Academy workflows only** accept optional inputs `aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token`. Resolve order: form if all three set, else Environment `academy` secrets, else fail. Mask with `::add-mask::`. `set +x`. Never write these values to Secrets Manager or onto EC2 (`LabRole` is the guest).

**Paid workflows MUST NOT declare these inputs.**

## Consequences

- Operators paste fresh tokens after Start Lab without editing Environment settings.
- Anyone who can view the workflow run may see the Inputs panel — use a private repo and Environment reviewers.
- Environment secrets remain a fallback for unattended retries in the same session.
