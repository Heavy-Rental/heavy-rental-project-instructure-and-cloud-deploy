# Delta for infra-academy-paid-profile (bastion)

## MODIFIED Requirements

### Requirement: Paid uses OIDC and created profiles
When `deployment` is `actual`, Terraform SHALL create instance profile `hr-paid-bastion` in addition to `hr-paid-{portal,rest,haystack,neo4j}`. `hr-bastion` SHALL use `hr-paid-bastion` (SSM + describe hop targets). That profile SHALL NOT attach ECR pull or app secret `GetSecretValue`.

#### Scenario: Paid bastion profile exists
- GIVEN Environment `AWS_ACTUAL` and a successful apply
- WHEN instance profiles are listed
- THEN `hr-paid-bastion` exists
- AND `aws_instance.bastion` uses that profile, not `LabInstanceProfile`
