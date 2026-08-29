# Delta for infra-academy-scope (branch 3)

> **Later modified by** [`add-infra-academy-deploy-projects`](../../../add-infra-academy-deploy-projects/specs/infra-academy-scope/spec.md): `deploy-projects` is in scope.  
> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-academy-scope/spec.md): paid is a different Action.  
> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-stop/spec.md): `stop` also `stop-instances` on `hr-bastion`.

## Purpose

This delta: configure and stop are in scope. Paid and app CD were not. **Current:** later changes added `deploy-projects`, the paid Action, and bastion stop (banners).

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
