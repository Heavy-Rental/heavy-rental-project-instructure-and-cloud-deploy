# Design: Haystack workers from Fast API devcontainer

## Context

ADR 0013 already puts `SOURCE_*` / `TARGET_*` / `NEO4J_URI` / `NEO4J_POPULATE_URL` in `sync-secrets`. Compose used the wrong runtime (`python -m` on uvicorn). Fast API `.devcontainer` is the source of truth for merge-sync and KG-2 populate.

## Goals / Non-Goals

**Goals:** 60s SoR → Haystack RDS merge via `sync-from-primary.sh`; 60s + compose `:8089` populate via `populate_neo4j.py`; FDW path on `sg-rds`; CD compose stays a copy of estate.

**Non-Goals:** Workers on `configure.yml`; `sg-nlb-neo4j`; guest `docker build`; publishing `:8089`; DMS.

## Decisions

1. Bind-mount scripts from Ansible `files/` (no GHCR worker image in this change).
2. FDW + `sg-rds` self; if extension fails, log (do not fail `site.yml`).
3. Conflict order: OpenSpec → OpenSPDD → ADR 0020 → compose / Terraform.

## Risks

- Vocareum may deny `postgres_fdw`.
- `postgres:17` client vs Academy PG 12 server is supported; FDW runs **on** Haystack RDS.
- First populate image start runs `pip install` (needs NAT).
