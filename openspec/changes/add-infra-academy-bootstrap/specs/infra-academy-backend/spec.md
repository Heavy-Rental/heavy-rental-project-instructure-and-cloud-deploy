# Delta for infra-academy-backend

## Purpose

Terraform estate state lives in S3 with native S3 locking (`use_lockfile`). That backend is not part of the estate state.

## ADDED Requirements

### Requirement: Backend exists before estate plan
`action=plan` and `action=bootstrap` SHALL ensure an S3 bucket `heavy-rental-tfstate-<account>-academy` exists in `us-east-1`. Estate `terraform init` SHALL set `use_lockfile=true`.

#### Scenario: First plan creates the backend
- GIVEN the bucket does not exist
- WHEN `action=plan` or `action=bootstrap` runs after a successful `assert-lab`
- THEN Terraform in `terraform/backend/` creates the bucket
- AND no VPC, ALB, or RDS is created

#### Scenario: Later plan skips create
- GIVEN the bucket already exists
- WHEN `ensure-backend` runs
- THEN it does not recreate the bucket
- AND estate `terraform init` can use that bucket

#### Scenario: Cancelled Vocareum keys fail closed
- GIVEN identity policy `voc-cancel-cred` is attached (lab ended, End Lab, or stale Environment `AWS_*` secrets)
- WHEN `ensure-backend` or `assert-lab` runs
- THEN the job fails with a message to Start Lab and paste fresh AWS Details
- AND it does not call `s3:CreateBucket` (HeadBucket 403 is not treated as "bucket missing")

### Requirement: Backend is not the estate state
The estate workspace SHALL store state at key `estate/terraform.tfstate` in that bucket. The backend stack SHALL NOT use that same key.

#### Scenario: Distinct keys
- GIVEN backend apply has succeeded
- WHEN estate `terraform init` runs
- THEN it uses `-backend-config=key=estate/terraform.tfstate`
- AND backend local state, if copied, uses `backend/terraform.tfstate`

### Requirement: No IAM role in the backend stack
`terraform/backend/` SHALL NOT declare `aws_iam_role` or an OIDC provider.

#### Scenario: Vocareum identity creates the bucket
- GIVEN the Vocareum federated user from `assert-lab`
- WHEN backend apply runs
- THEN only the S3 state bucket (and its encryption/versioning/public-access settings) is created
- AND LabRole is not replaced
