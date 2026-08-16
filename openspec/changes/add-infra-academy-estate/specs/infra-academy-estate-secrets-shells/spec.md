# Delta for infra-academy-estate-secrets-shells

## Purpose

Terraform creates Secrets Manager **shells**. Values are branch 3 (`sync-secrets` / `sync-ssh-keys`).

## ADDED Requirements

### Requirement: Required secret ids exist
Terraform SHALL create secrets named `heavy-rental/portal`, `heavy-rental/rest`, `heavy-rental/haystack`, `heavy-rental/neo4j`, and `heavy-rental/ssh/{portal,rest,haystack,neo4j}` with `recovery_window_in_days = 0`.

#### Scenario: Shells exist without application fields
- GIVEN `action=apply` succeeded
- WHEN `describe-secret` is called for `heavy-rental/portal`
- THEN the secret exists
- AND there is no `SecretString` containing `REST_BASE_URL` from this branch

### Requirement: No secret versions in Terraform
The configuration SHALL NOT contain `aws_secretsmanager_secret_version`.

#### Scenario: Validate has no versions
- GIVEN `terraform/academy/` is searched
- THEN `aws_secretsmanager_secret_version` is absent

### Requirement: Vocareum keys never land in SM
Apply SHALL NOT `put-secret-value` the three Vocareum AWS keys.

#### Scenario: Keys stay on the runner
- GIVEN `action=apply` completes
- THEN no secret named `heavy-rental/*` contains `AWS_ACCESS_KEY_ID` or `AWS_SESSION_TOKEN`
