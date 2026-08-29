# Delta for infra-academy-estate-apply

> **Later modified by** [`add-infra-academy-configure`](../../../add-infra-academy-configure/specs/infra-academy-estate-apply/spec.md): apply continues to `sync-secrets` → `sync-ssh-keys` → Ansible `configure.yml`. `configure-only` and `stop` run. `destroy` uses `confirm_destroy=destroy` (not fail-closed).  
> **Later modified by** [`add-infra-academy-deploy-projects`](../../../add-infra-academy-deploy-projects/specs/infra-academy-ansible/spec.md): apply Ansible does **not** compose portal/REST/Haystack and does **not** fail on missing app images. `site.yml` is a later `deploy-projects` run.

## Purpose

This delta: the Academy workflow may apply the estate. **Current:** configure, stop, destroy, and later `deploy-projects` are implemented (banners).

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
