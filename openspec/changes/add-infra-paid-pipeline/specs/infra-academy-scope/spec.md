# Delta for infra-academy-scope (two Actions)

## MODIFIED Requirements

### Requirement: Academy workflow is Vocareum-only
`.github/workflows/aws-infra-academy.yml` SHALL accept GitHub Environment `academy` only. It SHALL fail before Terraform if `aws_environment` is not `academy`. It SHALL keep Vocareum key inputs (`aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`). Paid/OIDC SHALL live on `aws-infra-paid.yml`. This requirement **replaces** “Two profiles on one workflow” from `add-infra-paid-profile`.

#### Scenario: AWS_ACTUAL refused on academy Action
- GIVEN the operator selects Environment `AWS_ACTUAL` on `aws-infra-academy.yml`
- WHEN the workflow starts
- THEN assert fails
- AND no terraform apply runs

#### Scenario: Operator can select AWS_ACTUAL on paid Action
- GIVEN GitHub Environment `AWS_ACTUAL` exists
- WHEN the operator runs `aws-infra-paid.yml` with `aws_environment=AWS_ACTUAL`
- THEN assert uses the OIDC path
- AND academy LabRole preflight does not run

#### Scenario: Academy form still has Vocareum keys
- GIVEN an operator opens Run workflow on `aws-infra-academy.yml`
- THEN the form has Vocareum access-key fields
- AND `aws_environment` must be `academy`
