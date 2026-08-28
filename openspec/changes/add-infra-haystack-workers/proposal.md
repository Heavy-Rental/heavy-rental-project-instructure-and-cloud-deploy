# Proposal: Haystack sync/populate workers from Fast API devcontainer

## Why

Estate compose ran SoR → Haystack RDS sync and Neo4j populate as `python -m` on the uvicorn image with `restart: on-failure`. Those modules are often missing, so the graph and Haystack RDS never filled. The working workers are shell + Python in the Haystack Fast API **devcontainer**. `postgres_fdw` also needs `sg-rds` self `:5432`.

## What Changes

- OpenSpec, OpenSPDD, ADR 0020.
- Ansible copies `sync-from-primary.sh` / `populate_neo4j.py` onto `asg-haystack`. Compose: `postgres:17` and `python:3.12-slim`, `unless-stopped`, 60s loops. No host/ALB `:8089`.
- `sg-rds` ingress/egress TCP 5432 to itself. `rds_logical` `CREATE EXTENSION postgres_fdw` (log + continue if denied).
- Haystack CD copies the same compose and files (Haystack ADR 0011).

## Capabilities

### New Capabilities

- `infra-haystack-workers`

### Modified Capabilities

- `infra-academy-ansible`: Haystack compose workers are dedicated images + scripts
- `infra-academy-estate-sg`: `sg-rds` may pair with itself on 5432 for FDW

## Impact

- `deploy-projects` / Haystack CD pull `postgres:17` and `python:3.12-slim` in addition to `HAYSTACK_IMAGE`.
- `configure.yml` still does not start workers.
- Stock `postgres:17` may skip post-sync HTTP (no curl); populate interval still runs.
