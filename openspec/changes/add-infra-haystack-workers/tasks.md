# Tasks: add-infra-haystack-workers

- [x] 1. `sg-rds` self TCP 5432 ingress/egress
- [x] 2. Copy Fast API devcontainer scripts into `ansible/roles/haystack/files/`
- [x] 3. Haystack compose: `postgres:17` + `python:3.12-slim`, `unless-stopped`
- [x] 4. Ansible copy scripts + env aliases (`SOURCE_USER`, `PG*`, trigger URL, 60s)
- [x] 5. `rds_logical` `CREATE EXTENSION postgres_fdw` (fail open)
- [x] 6. Mirror compose/files/aliases in Haystack CD; ADR 0020 / 0011; specs
