# Delta for infra-academy-plan

## Purpose

`action=plan` proves Terraform can init the estate backend and plan without creating the VPC.

## ADDED Requirements

### Requirement: Plan the academy placeholder
On `action=plan`, after `assert-lab` and `ensure-backend`, the workflow SHALL run `terraform init` and `terraform plan` in `terraform/academy/`.

#### Scenario: Plan is green without a VPC
- GIVEN a live Vocareum session and an existing state bucket
- WHEN `action=plan` completes
- THEN `terraform plan` exits 0
- AND the configuration contains no `aws_vpc`, `aws_lb`, `aws_db_instance`, or `aws_autoscaling_group`

### Requirement: Apply is refused on this branch
`action=apply` SHALL NOT apply the estate on `feat/infra-academy-bootstrap`.

#### Scenario: Apply fails closed
- GIVEN the operator selects `action=apply`
- WHEN the terraform job runs
- THEN the job fails with a message that the estate belongs to `feat/infra-academy-estate`
- AND `terraform apply` is not invoked on `terraform/academy/`
