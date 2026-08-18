# Delta for infra-academy-scope

## MODIFIED Requirements

### Requirement: Two profiles on one workflow
The Academy workflow file SHALL accept GitHub Environment `academy` (Vocareum) and `AWS_ACTUAL` (public AWS). It SHALL NOT treat `AWS_ACTUAL` as Vocareum.

#### Scenario: Operator can select AWS_ACTUAL
- GIVEN GitHub Environment `AWS_ACTUAL` exists
- WHEN the operator runs the workflow with `aws_environment=AWS_ACTUAL`
- THEN assert uses the OIDC path
- AND academy LabRole preflight does not run
