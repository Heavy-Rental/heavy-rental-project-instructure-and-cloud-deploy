# Delta for infra-academy-sync-secrets

## Purpose

`sync-secrets` writes required JSON into the empty Secrets Manager shells. It does not write Vocareum AWS keys or SSH PEMs.

## ADDED Requirements

### Requirement: Required app fields
On `action=apply` and `action=configure-only`, after Terraform has created the shells (or they already exist), the workflow SHALL `put-secret-value` for `heavy-rental/{portal,rest,haystack,neo4j}` with the fields in AWS study §8.2.

#### Scenario: Portal and REST URLs come from Terraform
- GIVEN estate outputs exist
- WHEN `sync-secrets` runs
- THEN `heavy-rental/portal` contains `REST_BASE_URL`, `STRIPE_PUBLISHABLE_KEY`, and `VITE_STRIPE_PUBLISHABLE_KEY` (same `pk_` value)
- AND `heavy-rental/rest` contains `POSTGRES_*`, `SPRING_DATASOURCE_*`, Spring aliases `POSTGRES_HOSTNAME` / `POSTGRES_DB` / `POSTGRES_USER`, `HAYSTACK_BASE_URL`, and the Stripe trio
- AND `heavy-rental/portal` does not contain `STRIPE_API_KEY` or `STRIPE_WEBHOOK_SECRET`

### Requirement: Haystack secret includes SoR and Haystack RDS endpoints
`heavy-rental/haystack` SHALL include Haystack RDS `POSTGRES_*` / aliases / `DATABASE_URL`, `SOURCE_HOST` / `SOURCE_PORT` / `SOURCE_DATABASE` pointing at the SoR RDS (`heavy_rental`), `TARGET_HOST` / `TARGET_PORT` / `TARGET_DATABASE` pointing at the Haystack RDS, `FLEET_BACKEND=sql`, and `NEO4J_BACKEND=bolt`. It SHALL NOT invent a third database or a `SOURCE_USER` (credentials reuse `POSTGRES_USERNAME` / `POSTGRES_PASSWORD`). Ansible SHALL NOT create these keys; it only maps SM → `.env`.

#### Scenario: Sync endpoints written
- GIVEN both RDS endpoints exist
- WHEN `sync-secrets` writes `heavy-rental/haystack`
- THEN `SOURCE_HOST` is the SoR RDS hostname
- AND `TARGET_HOST` is the Haystack RDS hostname
- AND `TARGET_DATABASE` is `haystack`

#### Scenario: Missing host fails closed
- GIVEN RDS hostname, database, password, or port is empty
- WHEN `sync-secrets` runs
- THEN the job fails
- AND Vocareum `AWS_*` keys are not written to Secrets Manager
