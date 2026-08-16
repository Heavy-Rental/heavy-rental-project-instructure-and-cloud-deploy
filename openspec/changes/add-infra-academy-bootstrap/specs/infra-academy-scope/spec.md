# Delta for infra-academy-scope

## Purpose

Branch 1 only bootstraps Academy CD. It does not operate the estate, deploy apps, or target paid AWS.

## ADDED Requirements

### Requirement: No configure, stop, or destroy on this branch
`action=configure-only`, `action=stop`, and `action=destroy` SHALL fail closed.

#### Scenario: Operate actions are not implemented
- GIVEN the operator selects `configure-only`, `stop`, or `destroy`
- WHEN the workflow runs
- THEN a job fails stating those actions belong to a later branch
- AND no ASG desired-capacity change or `terraform destroy` of an estate runs

### Requirement: No paid pipeline
This change SHALL NOT add a paid or OIDC workflow.

#### Scenario: Single Academy workflow
- GIVEN this branch
- WHEN `.github/workflows/` is listed
- THEN the only infra workflow is `aws-infra-academy.yml`
- AND it does not declare `AWS_ROLE_TO_ASSUME` or `id-token: write`

### Requirement: No Ansible or app CD
This change SHALL NOT add Ansible playbooks or portal/REST/Haystack app CD workflows.

#### Scenario: No guest compose
- GIVEN branch 1 jobs finish
- THEN no job runs `ansible-playbook`
- AND no job targets `asg-portal`, `asg-rest`, or `asg-haystack`
