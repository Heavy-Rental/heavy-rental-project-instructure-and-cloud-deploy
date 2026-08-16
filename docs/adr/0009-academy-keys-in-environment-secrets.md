# ADR 0009: Vocareum keys live in Environment secrets only

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `HR-161-implement-aws-infrastructure-academy-by-building-resources`
- **Supersedes:** [0002](0002-vocareum-keys-on-dispatch.md)

## Context

ADR 0002 put Vocareum AWS Details on `workflow_dispatch` so operators could paste a fresh session without editing Environment secrets. GitHub has no secret-typed dispatch input. Every string input is printed on the run **Inputs** page. Writing those values to `GITHUB_ENV` also risked showing them in step logs.

## Decision

**Academy workflows MUST NOT declare** `aws_access_key_id`, `aws_secret_access_key`, or `aws_session_token` on `workflow_dispatch`.

Read the three values only from Environment **`academy`** secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). Pass them straight into `aws-actions/configure-aws-credentials`. Do **not** echo them into `$GITHUB_ENV`. Fail if any secret is empty. Still `set +x` and `::add-mask::`.

Operators update the Environment secrets after each Start Lab. `SPRING_DATASOURCE_PASSWORD` stays an Environment secret (never a Run-form field).

**Paid workflows MUST NOT declare these inputs either.**

## Consequences

- The run Inputs page shows only `action`, `aws_environment`, and `confirm_destroy`.
- GitHub redacts `secrets.*` in logs. There is no plaintext copy in `GITHUB_ENV`.
- Each Start Lab requires updating three Environment secrets (slower than paste-on-run; accepted to keep keys off the run page).
- Never write these values to Secrets Manager or onto EC2 (`LabRole` is the guest).
