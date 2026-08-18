# Delta for infra-academy-scope (`deploy-projects`)

## Purpose

`deploy-projects` is in scope as a later compose action. Paid and day-to-day app CD are not.

## MODIFIED Requirements

### Requirement: deploy-projects is implemented
`action=deploy-projects` SHALL run its jobs. It SHALL NOT replace `apply` or `configure-only`.

#### Scenario: deploy-projects skips terraform apply
- GIVEN the operator selects `deploy-projects`
- WHEN the workflow runs
- THEN `ensure-backend` and estate `terraform apply` do not run
- AND `sync-secrets`, `sync-ssh-keys`, image preflight, and `site.yml` run
