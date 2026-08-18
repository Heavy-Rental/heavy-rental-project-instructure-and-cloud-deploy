# Delta for infra-academy-deploy-projects

## Purpose

Opt-in first-compose of portal + REST + Haystack on an estate that `apply` or `configure-only` already prepared. SHALL run as a **later workflow run**, not chained onto those actions.

## ADDED Requirements

### Requirement: deploy-projects is a later run
`action=deploy-projects` SHALL NOT run Terraform. It SHALL run after a successful `apply` or `configure-only` in a separate `workflow_dispatch`. It SHALL refresh `sync-secrets` and `sync-ssh-keys`, then preflight images, then invoke `playbooks/site.yml` only.

#### Scenario: no terraform on deploy-projects
- GIVEN the operator selects `deploy-projects`
- WHEN the workflow runs
- THEN `ensure-backend` and estate `terraform apply` do not run
- AND `playbooks/configure.yml` is not invoked
- AND `playbooks/site.yml` is invoked

#### Scenario: missing estate fails before compose
- GIVEN `asg-portal` does not exist
- WHEN `deploy-projects` preflight runs
- THEN the job fails
- AND the error tells the operator to run `apply` first
- AND Ansible does not run

### Requirement: image preflight fails closed
The runner SHALL resolve `PORTAL_IMAGE`, `REST_IMAGE` (or Run `image_ref`), and `HAYSTACK_IMAGE` (or Run `image_ref`) before SSM. Stock `nginx` SHALL be refused. A non-empty `image_http_url` / `IMAGE_HTTP_URL` SHALL be refused. Each `ghcr.io/*` tag SHALL be readable with an anonymous GHCR pull token (HTTP 200). 401/403 SHALL fail without putting a PAT on the guest.

#### Scenario: empty REST image
- GIVEN `REST_IMAGE` and `image_ref` are empty
- WHEN `deploy-projects` preflight runs
- THEN the job fails
- AND Ansible does not run

#### Scenario: stock nginx forbidden
- GIVEN `PORTAL_IMAGE` is `nginx` or empty
- WHEN `deploy-projects` preflight runs
- THEN the job fails
- AND Ansible does not run

#### Scenario: private GHCR
- GIVEN `PORTAL_IMAGE` is a `ghcr.io/*` tag whose manifest returns 401 or 403
- WHEN `deploy-projects` preflight runs
- THEN the job fails
- AND the guest is not given a GitHub token

#### Scenario: tar URL refused
- GIVEN `image_http_url` or `IMAGE_HTTP_URL` is non-empty
- WHEN `deploy-projects` preflight runs
- THEN the job fails
- AND no guest `docker load`s that tar

### Requirement: site.yml composes all three apps
On a successful preflight, Ansible SHALL run `guest_base` + portal + neo4j + rest + haystack + `rds_logical`. Haystack SHALL NOT start a Neo4j container. Portal SHALL proxy `/api` to `REST_BASE_URL`. `rds_logical` SHALL `CREATE EXTENSION IF NOT EXISTS vector` on Haystack RDS via a haystack guest.

#### Scenario: rds_logical runs
- GIVEN preflight succeeded and haystack guests have `POSTGRES_*` for database `haystack`
- WHEN `site.yml` finishes
- THEN `CREATE EXTENSION IF NOT EXISTS vector` ran on Haystack RDS
- AND the Actions runner did not open `:5432`
