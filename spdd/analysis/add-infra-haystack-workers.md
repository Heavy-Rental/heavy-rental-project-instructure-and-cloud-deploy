# SPDD Analysis: add-infra-haystack-workers

**Status:** Active  
**Companion:** [prompt](../prompt/add-infra-haystack-workers.md) · [OpenSpec](../../openspec/changes/add-infra-haystack-workers/proposal.md) · [ADR 0020](../../docs/adr/0020-haystack-devcontainer-workers.md)

## Problem

Uvicorn `-m` sidecars did not implement the Fast API 60s FDW merge or HTTP populate. Workers crash-looped; verify still passed.

## Concepts

| Concept | Meaning |
| --- | --- |
| Sync script | `sync-from-primary.sh` on `postgres:17` |
| Populate script | `populate_neo4j.py` on `python:3.12-slim` |
| FDW | `postgres_fdw` on Haystack RDS; client is RDS ENI → SoR (`sg-rds` self :5432) |
| Compose :8089 | Docker DNS `neo4j-populate`; not instance/ALB/SG |

## Safeguards

- Do not `docker build` on the guest.
- Do not publish `:8089` or add SG 8089.
- Do not invent RDS hostnames (ADR 0013).
- Do not start workers on `configure.yml`.
- Do not put a Neo4j container on `asg-haystack`.
- Fail-open if `postgres_fdw` is denied; do not fail closed on vector-only labs.
