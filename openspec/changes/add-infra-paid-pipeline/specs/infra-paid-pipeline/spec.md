# Spec: infra-paid-pipeline

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-paid-profile/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): paid also creates `hr-paid-bastion`. App profiles stay `hr-paid-{portal,rest,haystack,neo4j}`.

## Purpose

A dedicated GitHub Action applies the same estate to a billed account via OIDC. It never accepts Vocareum keys. Academy and paid each own their jobs (ADR 0019); they SHALL NOT share `aws-infra-estate.yml` or `workflow_call`.

## ADDED Requirements

### Requirement: Paid workflow is a separate file
`action` values `plan`, `bootstrap`, `apply`, `configure-only`, `deploy-projects`, `stop`, and `destroy` SHALL be available on `.github/workflows/aws-infra-paid.yml`. That file SHALL NOT declare `aws_access_key_id`, `aws_secret_access_key`, or `aws_session_token` inputs. Display name SHALL be `AWS infrastructure (paid)`.

#### Scenario: Paid dispatch has no Vocareum inputs
- GIVEN an operator opens Run workflow on `aws-infra-paid.yml`
- THEN the form has no Vocareum access-key fields
- AND `aws_environment` must be `AWS_ACTUAL`

### Requirement: Paid refuses academy credentials
When `aws_environment` is not `AWS_ACTUAL`, or Environment `AWS_ACTUAL` has `AWS_ACCESS_KEY_ID`, or `AWS_ROLE_TO_ASSUME` is empty, the paid workflow SHALL fail before Terraform.

#### Scenario: Academy environment on paid Action
- GIVEN the operator selects Environment `academy` on `aws-infra-paid.yml`
- WHEN the workflow starts
- THEN assert fails
- AND no terraform apply runs

#### Scenario: Vocareum key on AWS_ACTUAL
- GIVEN Environment `AWS_ACTUAL` has secret `AWS_ACCESS_KEY_ID`
- WHEN the paid workflow starts
- THEN assert fails
- AND OIDC assume-role is not used to apply

#### Scenario: Empty OIDC role
- GIVEN Environment `AWS_ACTUAL` has no `AWS_ACCESS_KEY_ID`
- AND variable `AWS_ROLE_TO_ASSUME` is empty
- AND secret `AWS_ROLE_TO_ASSUME` is empty
- WHEN the paid workflow starts
- THEN assert fails
- AND no terraform apply runs

#### Scenario: Role ARN from Environment secret
- GIVEN Environment `AWS_ACTUAL` has secret `AWS_ROLE_TO_ASSUME` set to an IAM role ARN
- AND the Environment variable `AWS_ROLE_TO_ASSUME` is empty
- AND `AWS_ACCESS_KEY_ID` is unset
- WHEN the paid workflow starts
- THEN assert uses that ARN for OIDC
- AND terraform is not blocked for missing variable

### Requirement: Paid uses OIDC and created profiles
Paid apply SHALL assume `AWS_ROLE_TO_ASSUME` (Environment **variable** or **secret**) with GitHub OIDC (`id-token: write` on `aws-infra-paid.yml` only). App guests SHALL use `hr-paid-{portal,rest,haystack,neo4j}`. **Current:** `hr-bastion` uses `hr-paid-bastion` (banner). State bucket SHALL end with `-actual`. Terraform SHALL NOT look up `LabRole` or `LabInstanceProfile` when `deployment` is `actual`. The OIDC provider and runner role SHALL be created out of band (`docs/OIDC-PAID.md`); estate apply SHALL NOT create them.

#### Scenario: Paid apply creates instance profiles
- GIVEN Environment `AWS_ACTUAL`, `AWS_ROLE_TO_ASSUME`, and no Vocareum keys
- WHEN `action=apply` succeeds
- THEN instance profile `hr-paid-portal` exists
- AND `asg-portal` uses that profile, not `LabInstanceProfile`
- AND the backend bucket name ends with `-actual`

### Requirement: Paid Ansible SSM bucket is not tfstate
Paid guests SHALL GetObject from `heavy-rental-ssm-<account>-actual` only. They SHALL NOT have `s3:PutObject` on the Terraform state bucket. Academy SHALL keep using the tfstate bucket for Ansible SSM transfer.

#### Scenario: Guest cannot overwrite state
- GIVEN a paid apply
- WHEN the `hr-paid-rest` role policy is listed
- THEN it allows s3:GetObject on the SSM bucket
- AND it does not allow s3:PutObject on `heavy-rental-tfstate-<account>-actual/estate/*`

#### Scenario: Academy Ansible still uses tfstate bucket
- GIVEN an academy apply
- WHEN Ansible `configure.yml` runs
- THEN `ansible_aws_ssm_bucket_name` is the academy tfstate bucket
- AND bucket `heavy-rental-ssm-<account>-academy` is not required

### Requirement: Separate job graphs
`.github/workflows/aws-infra-paid.yml` and `.github/workflows/aws-infra-academy.yml` SHALL each contain their own jobs. Neither SHALL `workflow_call` the other. `.github/workflows/aws-infra-estate.yml` SHALL NOT exist. Concurrency groups SHALL be `aws-infra-academy-<repository>` and `aws-infra-paid-<repository>` (`cancel-in-progress: false`). `.github/workflows/aws-infra-academy.yml` SHALL NOT set `id-token: write`.

#### Scenario: deploy-projects exists on paid
- GIVEN a successful paid apply
- WHEN the operator runs `action=deploy-projects` on `aws-infra-paid.yml`
- THEN `playbooks/site.yml` runs
- AND Terraform apply is not invoked
- AND `.github/workflows/aws-infra-estate.yml` is not used

#### Scenario: Academy workflow has no OIDC token permission
- GIVEN `.github/workflows/aws-infra-academy.yml`
- WHEN permissions are listed
- THEN `id-token` is not `write`

#### Scenario: Concurrent academy and paid runs
- GIVEN an academy `apply` is in progress
- WHEN the operator starts `action=plan` on `aws-infra-paid.yml`
- THEN the paid run is not cancelled by the academy concurrency group

#### Scenario: Paid destroy sweeps actual observe leftovers
- GIVEN `DEPLOYMENT=actual` and a leftover CloudTrail `heavy-rental-actual`
- WHEN paid `action=destroy` sweeps
- THEN CloudTrail `heavy-rental-actual` is deleted
- AND CloudTrail `heavy-rental-academy` is not looked up

#### Scenario: Paid reconcile imports actual trail
- GIVEN `DEPLOYMENT=actual` and CloudTrail `heavy-rental-actual` exists
- WHEN paid `action=plan` reconciles
- THEN `aws_cloudtrail.academy` is imported from `heavy-rental-actual`
- AND `heavy-rental-academy` is not queried as the trail name
