# Spec: infra-haystack-workers

## Purpose

SoR → Haystack RDS and Haystack SQL → Neo4j run as **estate workers** from the Fast API devcontainer scripts, not as `python -m` on the uvicorn image.

## ADDED Requirements

### Requirement: Sync worker is postgres:17 + sync-from-primary.sh
On `deploy-projects` (and Haystack CD), `postgres-haystack-sync` SHALL use image `postgres:17`, bind-mount `sync-from-primary.sh`, `restart: unless-stopped`, and SHALL NOT use the Haystack API image or `python -m postgres_haystack_sync`.

#### Scenario: Sync sidecar image
- GIVEN Haystack compose is rendered
- WHEN the `postgres-haystack-sync` service is read
- THEN its image is `postgres:17`
- AND it has no `command` of `python -m postgres_haystack_sync`

### Requirement: Populate worker is python:3.12-slim + populate_neo4j.py
`neo4j-populate` SHALL use `python:3.12-slim` and `populate_neo4j.py`, `restart: unless-stopped`. `:8089` SHALL listen on the Compose network only. It SHALL NOT be a host port or Haystack ALB listener. No security-group rule for 8089.

#### Scenario: Populate is not on the ALB
- GIVEN Haystack compose is rendered
- WHEN ports for `neo4j-populate` are listed
- THEN there is no `8089:8089` host mapping

### Requirement: Workers start with Haystack compose, not configure.yml
`configure.yml` SHALL NOT start sync/populate. `site.yml` / Haystack CD SHALL copy scripts under `/opt/heavy-rental/workers/` before `compose up`.

#### Scenario: apply does not start workers
- GIVEN `action` is `apply` or `configure-only`
- WHEN Ansible runs
- THEN it invokes `configure.yml`
- AND haystack compose (uvicorn + workers) does not run

### Requirement: postgres_fdw for Haystack RDS
`rds_logical` SHALL attempt `CREATE EXTENSION IF NOT EXISTS postgres_fdw` on Haystack RDS from a haystack guest. Failure SHALL be logged and SHALL NOT fail the play by itself. `sg-rds` SHALL allow TCP 5432 from and to `sg-rds`.

#### Scenario: RDS self pairing
- GIVEN the estate is applied
- WHEN `sg-rds` rules are listed
- THEN ingress TCP 5432 from `sg-rds` is present
- AND egress TCP 5432 to `sg-rds` is present
- AND `0.0.0.0/0` is not a source on 5432
