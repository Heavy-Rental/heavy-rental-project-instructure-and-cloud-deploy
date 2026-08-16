# Delta for infra-academy-scope (branch 2)

## Purpose

Estate apply is in scope. Guest configure, stop, destroy, paid, and app CD are not.

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
