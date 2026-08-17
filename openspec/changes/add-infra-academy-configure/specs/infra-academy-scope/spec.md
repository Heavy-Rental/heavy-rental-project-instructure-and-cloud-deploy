# Delta for infra-academy-scope (branch 3)

## Purpose

Configure and stop are in scope. Paid and app CD are not.

## MODIFIED Requirements

### Requirement: Configure and stop are implemented
`action=configure-only` and `action=stop` SHALL run their jobs. `action=destroy` remains the branch-2 confirm gate.

#### Scenario: configure-only skips terraform apply
- GIVEN the operator selects `configure-only`
- WHEN the workflow runs
- THEN `ensure-backend` and estate `terraform apply` do not run
- AND `sync-secrets`, `sync-ssh-keys`, and Ansible run

#### Scenario: stop does not destroy
- GIVEN the operator selects `stop`
- WHEN the workflow runs
- THEN Ansible does not run
- AND `terraform destroy` does not run
