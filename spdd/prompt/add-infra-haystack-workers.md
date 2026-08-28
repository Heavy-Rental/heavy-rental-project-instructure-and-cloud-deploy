# REASONS Canvas: add-infra-haystack-workers

Copy Fast API `.devcontainer` `scripts/sync-from-primary.sh` and `populate_neo4j.py` into `ansible/roles/haystack/files/`. Compose those workers on `postgres:17` / `python:3.12-slim` with bind mounts, `unless-stopped`, 60s. Ansible aliases SOURCE/PG keys from SM. `sg-rds` self :5432. `rds_logical` postgres_fdw fail-open.

**Do not:** guest docker build; uvicorn `-m`; host/ALB 8089; SG 8089; configure.yml workers; invent SOURCE hosts; NLB SG for populate.
