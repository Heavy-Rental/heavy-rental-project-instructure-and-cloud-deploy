# ADR 0009: Vocareum keys on the Run form, masked in logs

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `HR-161-implement-aws-infrastructure-academy-by-building-resources`
- **Supersedes:** [0002](0002-vocareum-keys-on-dispatch.md)
- **Amended:** form fields restored; logs must not dump plaintext

## Context

ADR 0002 put Vocareum AWS Details on `workflow_dispatch`. GitHub has no secret-typed dispatch input. Putting `inputs.*` in a step `env:` block prints them in the **env:** dump *before* `::add-mask::` runs (seen in Academy run #6). Interpolating `${{ inputs.aws_* }}` into the `run:` script prints them in the **Run** group.

Operators still need to paste a fresh session after each Start Lab.

## Decision

**Academy workflows SHALL declare** optional `aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token` on `workflow_dispatch`.

Resolve order: form if **all three** are set, else Environment `academy` secrets, else fail.

Read form values from `$GITHUB_EVENT_PATH` with `jq`. **Do not** put form values in `env:` or in `${{ inputs.aws_* }}`. `::add-mask::` before writing `$GITHUB_ENV`. Then `configure-aws-credentials` uses `env.AWS_*`. `set +x`. Environment `secrets.*` may sit in `env:` (GitHub already masks them).

The run **Inputs** page may still show the three strings. That is a GitHub limitation. This ADR only requires **job logs** to show `***`.

`SPRING_DATASOURCE_PASSWORD` stays an Environment secret (never a Run-form field).

**Paid workflows MUST NOT declare these inputs.**

## Consequences

- Operators can paste AWS Details on Run workflow.
- Job logs do not dump `FORM_KEY` / `FORM_SECRET` / `FORM_TOKEN`.
- Anyone who can view the run may still see the Inputs panel.
- Never write these values to Secrets Manager or onto EC2 (`LabRole` is the guest).
