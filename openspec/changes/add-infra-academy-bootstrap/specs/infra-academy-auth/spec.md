# Delta for infra-academy-auth

## Purpose

The Academy infra workflow authenticates as a Vocareum Learner Lab session. Paid / OIDC is out of scope.

## ADDED Requirements

### Requirement: Vocareum credentials from Environment secrets only
The workflow SHALL read `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` only from Environment `academy` secrets. It SHALL NOT declare those values as `workflow_dispatch` inputs. It SHALL NOT write them to `$GITHUB_ENV`.

#### Scenario: Operator set Environment secrets after Start Lab
- GIVEN a live Vocareum Start Lab
- AND Environment `academy` has the three AWS secrets set from AWS Details
- WHEN the operator runs the Academy workflow
- THEN `assert-lab` calls `sts get-caller-identity` successfully
- AND the run Inputs page does not list access key, secret access key, or session token
- AND the three values are masked in job logs (`::add-mask::`)

#### Scenario: Environment secrets unset
- GIVEN Environment `academy` AWS secrets are unset
- WHEN `assert-lab` runs
- THEN the job fails with a message to Start Lab and set the three Environment secrets
- AND it tells the operator not to put keys on the Run form

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
