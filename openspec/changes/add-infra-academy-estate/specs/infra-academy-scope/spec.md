# Delta for infra-academy-scope (branch 2)

> **Later modified by** [`add-infra-academy-configure`](../../../add-infra-academy-configure/specs/infra-academy-scope/spec.md): `configure-only` and `stop` run; `destroy` is the confirm gate.  
> **Later modified by** [`add-infra-academy-deploy-projects`](../../../add-infra-academy-deploy-projects/specs/infra-academy-scope/spec.md): `deploy-projects` is in scope.  
> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-academy-scope/spec.md): paid is a different Action (`aws-infra-paid.yml`).

## Purpose

This delta: estate apply is in scope. Guest configure, stop, destroy, paid, and app CD were not. **Current:** those later changes added them (banners).

## MODIFIED Requirements

### Requirement: No configure, stop, or destroy on this branch
`action=configure-only`, `action=stop`, and `action=destroy` SHALL fail closed.

#### Scenario: Operate actions are not implemented
- GIVEN the operator selects `configure-only`, `stop`, or `destroy`
- WHEN the workflow runs
- THEN a job fails stating those actions belong to `feat/infra-academy-configure` (branch 3)
- AND no ASG desired-capacity change or `terraform destroy` of the estate runs

## ADDED Requirements

### Requirement: No Ansible or secret values
This change SHALL NOT add Ansible playbooks or `put-secret-value` of application fields.

#### Scenario: Apply does not compose
- GIVEN `action=apply` finishes
- THEN no job runs `ansible-playbook`
- AND guests have no required Docker compose from this branch
