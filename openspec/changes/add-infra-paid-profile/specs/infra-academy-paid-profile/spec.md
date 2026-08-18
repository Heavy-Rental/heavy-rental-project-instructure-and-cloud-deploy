# Delta for infra-academy-paid-profile

## Purpose

The same GitHub Action can target Vocareum (`academy`) or a billed account (`paid`) without mixing credentials or Terraform state.

## ADDED Requirements

### Requirement: Environment is academy or paid
`aws_environment` SHALL be exactly `academy` or `AWS_ACTUAL`. Any other Environment name SHALL fail before Terraform.

#### Scenario: Unknown Environment refused
- GIVEN the operator selects an Environment that is not `academy` or `AWS_ACTUAL`
- WHEN the workflow starts
- THEN assert fails
- AND no terraform apply runs

### Requirement: Academy still uses Vocareum and LabRole
When `aws_environment` is `academy`, the workflow SHALL authenticate with Vocareum form keys or Environment `AWS_*` session credentials. Guests SHALL use `LabInstanceProfile` → `LabRole`. Terraform SHALL NOT create `aws_iam_role`.

#### Scenario: Academy apply does not create IAM
- GIVEN Environment `academy` and a live Start Lab session
- WHEN `action=plan` or `apply` runs
- THEN the plan does not create `aws_iam_role`
- AND launch templates use `LabInstanceProfile`

### Requirement: Paid uses OIDC and created profiles
When `aws_environment` is `AWS_ACTUAL`, the workflow SHALL assume `vars.AWS_ROLE_TO_ASSUME` with GitHub OIDC. It SHALL fail if Environment `AWS_ACTUAL` has `AWS_ACCESS_KEY_ID` or if Vocareum form keys are non-empty. Guests SHALL use Terraform-created instance profiles named `hr-paid-{portal,rest,haystack,neo4j}`. Terraform SHALL NOT look up `LabRole`.

#### Scenario: AWS_ACTUAL refuses Vocareum keys
- GIVEN Environment `AWS_ACTUAL` and a non-empty form `aws_access_key_id`
- WHEN the workflow starts
- THEN assert fails
- AND OIDC assume-role is not used to apply

#### Scenario: Paid apply creates instance profiles
- GIVEN Environment `AWS_ACTUAL`, `AWS_ROLE_TO_ASSUME`, and no Vocareum keys
- WHEN `action=apply` succeeds
- THEN instance profile `hr-paid-portal` exists
- AND `asg-portal` uses that profile, not `LabInstanceProfile`

### Requirement: Separate state
The estate state bucket SHALL be `heavy-rental-tfstate-<account>-academy` or `heavy-rental-tfstate-<account>-actual`. Environment `AWS_ACTUAL` maps to suffix `actual` because S3 names cannot contain uppercase. The two profiles SHALL NOT share a state object.

#### Scenario: AWS_ACTUAL bucket suffix
- GIVEN a successful AWS_ACTUAL assert
- THEN the backend bucket name ends with `-actual`
