# Delta for infra-academy-scope (`deploy-projects`)

> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-paid-pipeline/spec.md): the paid Action has the same `deploy-projects` action. Day-to-day app CD stays in `heavy-rental-project-pipeline-development`.

## Purpose

`deploy-projects` is in scope as a later compose action. This delta did not add paid or day-to-day app CD. **Current:** paid first-compose is the same action on `aws-infra-paid.yml` (banner).

## MODIFIED Requirements

### Requirement: deploy-projects is implemented
`action=deploy-projects` SHALL run its jobs. It SHALL NOT replace `apply` or `configure-only`.

#### Scenario: deploy-projects skips terraform apply
- GIVEN the operator selects `deploy-projects`
- WHEN the workflow runs
- THEN `ensure-backend` and estate `terraform apply` do not run
- AND `sync-secrets`, `sync-ssh-keys`, image preflight, and `site.yml` run
