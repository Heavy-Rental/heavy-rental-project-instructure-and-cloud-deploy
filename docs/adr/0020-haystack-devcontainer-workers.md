# ADR 0020: Haystack workers are Fast API devcontainer scripts, not uvicorn `-m`

- **Status:** Accepted
- **Date:** 2026-08-28
- **Change:** `add-infra-haystack-workers`
- **Related:** [0013](0013-haystack-source-target-in-sync-secrets.md), [0014](0014-deploy-projects-after-configure.md)
- **Amends:** estate Haystack compose that used `uv run python -m postgres_haystack_sync` / `neo4j_populate`

## Context

`asg-haystack` compose started two sidecars on the **Haystack Release image** with `restart: on-failure` and `python -m`. App `develop` often lacks those packages, so the sidecars crash-loop. Verify still passed on uvicorn `:8000/health`. SoR → Haystack RDS and SQL → Neo4j did not run.

The working implementation is in [Haystack-Fast-API `.devcontainer`](https://github.com/Heavy-Rental/heavy-rental-devcontainer-configuration/tree/develop/Haystack-Fast-API/.devcontainer): `sync-from-primary.sh` (`postgres:17`, 60s `postgres_fdw` merge) and `populate_neo4j.py` (`python:3.12-slim`, 60s loop + compose HTTP `:8089`).

`postgres_fdw` connections originate on the **Haystack RDS ENI**, not the guest. Both RDS instances use `sg-rds`, which did not allow `sg-rds` → `sg-rds` on `:5432`.

## Decision

1. Ansible copies those scripts onto `asg-haystack` (`/opt/heavy-rental/workers/`). Compose uses public `postgres:17` and `python:3.12-slim`, bind-mounts the scripts, `restart: unless-stopped`. No guest `docker build`. No uvicorn `-m`.
2. Workers start on **`deploy-projects` / Haystack CD** (`site.yml` / haystack role), not `configure.yml`.
3. `:8089` stays on the Compose network. It is not published on the host or Haystack ALB. No SG rule for 8089.
4. `sg-rds` allows TCP 5432 **to/from itself** so FDW can reach SoR RDS. `rds_logical` `CREATE EXTENSION IF NOT EXISTS postgres_fdw` on Haystack RDS; if Vocareum denies it, log and continue (sync cycles fail until FDW exists).
5. Endpoints stay infra `sync-secrets` (ADR 0013). Ansible aliases `SOURCE_USER` / `SOURCE_DB` / `PG*` from existing SM keys. `NEO4J_POPULATE_TRIGGER_URL` defaults to `http://neo4j-populate:8089/v1/populate`.

## Alternatives

1. **Keep `python -m` on the API image.** Rejected: modules missing; `on-failure` is not a 60s loop.
2. **Guest-side copy without FDW.** Deferred: more script change; FDW matches the reference. Revisit if `postgres_fdw` is blocked on Vocareum.
3. **Start workers on `configure.yml`.** Rejected for this change: that play does not pull worker/Haystack images.

## Consequences

- First-compose needs `postgres:17` and `python:3.12-slim` pulls via NAT plus `HAYSTACK_IMAGE` for uvicorn.
- Stock `postgres:17` has no `curl`; post-sync HTTP trigger may skip; populate still runs on its interval.
- Haystack CD compose must stay in sync (copy, ADR 0003 / Haystack ADR 0011).
- NLB still has no SG; Bolt populate uses existing `sg-haystack` → NLB / `sg-neo4j` :7687.
