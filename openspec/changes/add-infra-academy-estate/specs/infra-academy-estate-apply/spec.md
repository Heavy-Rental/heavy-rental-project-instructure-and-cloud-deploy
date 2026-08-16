# Delta for infra-academy-estate-apply

## Purpose

The Academy workflow may now apply the estate. Configure, stop, and destroy wait for branch 3.

## ADDED Requirements

### Requirement: apply is init, plan, apply
On `action=apply`, after `assert-lab` and `ensure-backend`, the workflow SHALL run `terraform init`, `terraform plan`, and `terraform apply` in `terraform/academy/` against `estate/terraform.tfstate`.

#### Scenario: Apply creates the estate
- GIVEN a live Vocareum session, Environment `academy`, and `SPRING_DATASOURCE_PASSWORD`
- WHEN the operator runs `action=apply`
- THEN Terraform apply exits 0
- AND `asg-portal` exists

### Requirement: Vocareum auth unchanged
`action=apply` SHALL use the same form-or-Environment Vocareum keys as `plan` and SHALL refuse `aws_environment` ≠ `academy`.

#### Scenario: Paid Environment still refused
- GIVEN `aws_environment` is not `academy`
- WHEN apply is requested
- THEN `assert-lab` fails
- AND `terraform apply` does not run

### Requirement: Operate actions still fail
`action=configure-only`, `action=stop`, and `action=destroy` SHALL fail closed on this branch.

#### Scenario: Destroy is not implemented
- GIVEN the operator selects `destroy`
- WHEN the workflow runs
- THEN a job fails stating those actions belong to branch 3
- AND `terraform destroy` is not invoked
