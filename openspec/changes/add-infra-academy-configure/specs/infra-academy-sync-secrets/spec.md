# Delta for infra-academy-sync-secrets

## Purpose

`sync-secrets` writes required JSON into the empty Secrets Manager shells. It does not write Vocareum AWS keys or SSH PEMs.

## ADDED Requirements

### Requirement: Required app fields
On `action=apply` and `action=configure-only`, after Terraform has created the shells (or they already exist), the workflow SHALL `put-secret-value` for `heavy-rental/{portal,rest,haystack,neo4j}` with the fields in AWS study §8.2.

#### Scenario: Portal and REST URLs come from Terraform
- GIVEN estate outputs exist
- WHEN `sync-secrets` runs
- THEN `heavy-rental/portal` contains `REST_BASE_URL` and `STRIPE_PUBLISHABLE_KEY`
- AND `heavy-rental/rest` contains `POSTGRES_*`, `SPRING_DATASOURCE_*`, `HAYSTACK_URL`, and the Stripe trio
- AND `heavy-rental/portal` does not contain `STRIPE_SECRET_KEY` or `STRIPE_WEBHOOK_SECRET`

#### Scenario: Missing host fails closed
- GIVEN RDS hostname, database, password, or port is empty
- WHEN `sync-secrets` runs
- THEN the job fails
- AND Vocareum `AWS_*` keys are not written to Secrets Manager
