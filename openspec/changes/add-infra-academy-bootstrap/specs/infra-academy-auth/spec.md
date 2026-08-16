# Delta for infra-academy-auth

## Purpose

The Academy infra workflow authenticates as a Vocareum Learner Lab session. Paid / OIDC is out of scope.

## ADDED Requirements

### Requirement: Vocareum credentials from form or Environment
The workflow SHALL accept `aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token` on `workflow_dispatch` and SHALL fall back to Environment `academy` secrets when those inputs are empty.

#### Scenario: Operator pastes AWS Details
- GIVEN a live Vocareum Start Lab
- WHEN the operator runs the Academy workflow and pastes the three AWS Details values
- THEN `assert-lab` calls `sts get-caller-identity` successfully
- AND the three values are masked in job logs (`::add-mask::`)

#### Scenario: Empty form uses Environment
- GIVEN Environment `academy` has the three secrets set
- WHEN the operator leaves the three form fields empty
- THEN the job uses `secrets.AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`

#### Scenario: Neither form nor Environment
- GIVEN the form fields are empty and Environment secrets are unset
- WHEN `assert-lab` runs
- THEN the job fails with a message to Start Lab and paste AWS Details

### Requirement: Refuse non-academy Environment
The workflow SHALL run only with GitHub Environment `academy`.

#### Scenario: paid Environment selected
- GIVEN `aws_environment` is not `academy`
- WHEN the workflow starts
- THEN `assert-lab` fails
- AND no AWS mutating call is made

### Requirement: Keys stay off the guest and out of Secrets Manager
The workflow SHALL NOT write Vocareum access keys or the session token into AWS Secrets Manager or onto an EC2 instance.

#### Scenario: sync-secrets is not this branch
- GIVEN branch 1 jobs complete
- THEN no job puts `AWS_ACCESS_KEY_ID` into a Secrets Manager secret
