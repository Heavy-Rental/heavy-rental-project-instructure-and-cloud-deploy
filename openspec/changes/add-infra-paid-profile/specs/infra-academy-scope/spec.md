# Delta for infra-academy-scope

> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-academy-scope/spec.md) / [ADR 0017](../../../../../docs/adr/0017-two-actions-academy-paid.md): “Two profiles on one workflow” is **replaced**. Academy YAML is Vocareum-only; paid is `aws-infra-paid.yml`.

## MODIFIED Requirements

### Requirement: Two profiles on one workflow
The Academy workflow file SHALL accept GitHub Environment `academy` (Vocareum) and `AWS_ACTUAL` (public AWS). It SHALL NOT treat `AWS_ACTUAL` as Vocareum.

#### Scenario: Operator can select AWS_ACTUAL
- GIVEN GitHub Environment `AWS_ACTUAL` exists
- WHEN the operator runs the workflow with `aws_environment=AWS_ACTUAL`
- THEN assert uses the OIDC path
- AND academy LabRole preflight does not run
