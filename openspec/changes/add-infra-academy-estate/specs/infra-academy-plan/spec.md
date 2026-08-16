# Delta for infra-academy-plan (branch 2)

## Purpose

`action=plan` now plans the real estate, not a placeholder.

## MODIFIED Requirements

### Requirement: Plan the academy estate
On `action=plan`, after `assert-lab` and `ensure-backend`, the workflow SHALL run `terraform init` and `terraform plan` in `terraform/academy/`.

#### Scenario: Plan lists VPC resources
- GIVEN a live Vocareum session and an existing state bucket
- WHEN `action=plan` completes
- THEN `terraform plan` exits 0
- AND the plan includes `aws_vpc`, load balancers, `aws_db_instance`, and Auto Scaling groups (to add, or already in state)

## REMOVED Requirements

### Requirement: Apply is refused on this branch
Superseded by `infra-academy-estate-apply`.
