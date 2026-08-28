# ADR 0013: SoR → Haystack sync endpoints live in infra `sync-secrets`

- **Status:** Accepted
- **Date:** 2026-08-18
- **Change:** `add-infra-academy-configure`
- **Related:** [0006](0006-empty-secret-shells.md)

## Context

`postgres-haystack-sync` on `asg-haystack` copies SoR (`heavy_rental`) to Haystack RDS. Runtime is `sync-from-primary.sh` on `postgres:17` (ADR 0020), not `python -m` on uvicorn. Terraform creates **two** RDS instances; it does not write connection JSON. App CD must not invent hostnames or run Terraform.

## Decision

`scripts/sync-secrets.sh` writes `SOURCE_HOST` / `SOURCE_PORT` / `SOURCE_DATABASE` (SoR) and `TARGET_HOST` / `TARGET_PORT` / `TARGET_DATABASE` (Haystack RDS) into `heavy-rental/haystack`. Ansible and Haystack app CD only map that secret to `.env`. Same Academy master password as `POSTGRES_*`; no `SOURCE_USER`. No third RDS.

## Consequences

- Feasibility `ANSIBLE-PROCESS.md` §4.3 and Haystack CD specs stay aligned.
- Changing RDS endpoints is infra `configure-only` / `apply`, not an app-CD invent.
