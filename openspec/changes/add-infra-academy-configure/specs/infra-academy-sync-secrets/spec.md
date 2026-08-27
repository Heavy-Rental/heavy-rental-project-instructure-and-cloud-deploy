# Delta for infra-academy-sync-secrets

> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-academy-sync-secrets/spec.md) / [ADR 0018](../../../../../docs/adr/0018-public-rest-alb.md): `APP_CORS_ALLOWED_ORIGINS` is `http://<portal_alb_dns>,http://<rest_alb_dns>:8080`, not the portal origin alone.

## Purpose

`sync-secrets` writes required JSON into the empty Secrets Manager shells. It does not write Vocareum AWS keys or SSH PEMs.

## ADDED Requirements

### Requirement: Required app fields
On `action=apply` and `action=configure-only`, after Terraform has created the shells (or they already exist), the workflow SHALL `put-secret-value` for `heavy-rental/{portal,rest,haystack,neo4j}` with the fields in AWS study §8.2.

#### Scenario: Portal and REST URLs come from Terraform
- GIVEN estate outputs exist
- WHEN `sync-secrets` runs
- THEN `heavy-rental/portal` contains `REST_BASE_URL`, `STRIPE_PUBLISHABLE_KEY`, and `VITE_STRIPE_PUBLISHABLE_KEY` (same `pk_` value)
- AND `heavy-rental/rest` contains `POSTGRES_*`, `SPRING_DATASOURCE_*`, Spring aliases `POSTGRES_HOSTNAME` / `POSTGRES_DB` / `POSTGRES_USER`, `HAYSTACK_BASE_URL`, `APP_CORS_ALLOWED_ORIGINS` (`http://` + public portal ALB DNS), the Stripe trio, and `APP_JWT_SECRET` (≥ 32 characters)

### Requirement: Optional OneMap credentials from Environment
If Environment secrets `ONEMAP_EMAIL` and `ONEMAP_PASSWORD` are both set, `sync-secrets` SHALL write them into `heavy-rental/rest`. If only one is set, the job SHALL fail. If both are empty, those keys SHALL be omitted.

#### Scenario: Both OneMap secrets set
- GIVEN Environment `ONEMAP_EMAIL` and `ONEMAP_PASSWORD` are set
- WHEN `sync-secrets` writes `heavy-rental/rest`
- THEN both keys are present
- AND the password is not printed
- AND `heavy-rental/portal` does not contain `STRIPE_API_KEY` or `STRIPE_WEBHOOK_SECRET`

### Requirement: APP_JWT_SECRET is created or reused
`sync-secrets` SHALL set `APP_JWT_SECRET` in `heavy-rental/rest` to a string of at least 32 characters. If Environment secret `APP_JWT_SECRET` is set, that value SHALL be used (and SHALL fail if shorter than 32). Otherwise, if SM already has a value of at least 32 characters that is not the Spring default `change-me-to-a-long-random-secret-key!!`, that value SHALL be reused. Otherwise `sync-secrets` SHALL generate a new secret (`openssl rand -base64 48`) and write it. It SHALL NOT print the secret. It SHALL NOT generate a new value on every run when a valid one already exists in SM.

#### Scenario: First apply generates
- GIVEN `heavy-rental/rest` has no `APP_JWT_SECRET`
- AND Environment `APP_JWT_SECRET` is unset
- WHEN `sync-secrets` runs
- THEN `heavy-rental/rest` contains `APP_JWT_SECRET` with length ≥ 32

#### Scenario: Reconfigure keeps the same secret
- GIVEN `heavy-rental/rest` already has `APP_JWT_SECRET` of length ≥ 32
- AND Environment `APP_JWT_SECRET` is unset
- WHEN `sync-secrets` runs again
- THEN the same `APP_JWT_SECRET` is written
- AND issued JWTs remain valid

### Requirement: Haystack secret includes SoR and Haystack RDS endpoints
`heavy-rental/haystack` SHALL include Haystack RDS `POSTGRES_*` / aliases / `DATABASE_URL`, `SOURCE_HOST` / `SOURCE_PORT` / `SOURCE_DATABASE` pointing at the SoR RDS (`heavy_rental`), `TARGET_HOST` / `TARGET_PORT` / `TARGET_DATABASE` pointing at the Haystack RDS, `FLEET_BACKEND=sql`, `NEO4J_BACKEND=bolt`, and `NEO4J_POPULATE_URL` equal to `http://neo4j-populate:8089/v1/populate` (the compose worker on `asg-haystack`; not a public ALB). It SHALL NOT invent a third database or a `SOURCE_USER` (credentials reuse `POSTGRES_USERNAME` / `POSTGRES_PASSWORD`). Ansible SHALL NOT create these keys; it only maps SM → `.env`.

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
