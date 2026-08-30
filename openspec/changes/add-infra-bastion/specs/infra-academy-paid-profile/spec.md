# Delta for infra-academy-paid-profile (bastion)

## MODIFIED Requirements

### Requirement: Paid uses OIDC and created profiles
When `deployment` is `actual`, Terraform SHALL create instance profile `hr-paid-bastion` in addition to `hr-paid-{portal,rest,haystack,neo4j}`. `hr-bastion` SHALL use `hr-paid-bastion` (SSM + describe hop targets + `GetSecretValue` on `heavy-rental/ssh/*` only). That profile SHALL NOT attach ECR pull or app secret `GetSecretValue` (`heavy-rental/{portal,rest,haystack,neo4j}`).

#### Scenario: Paid bastion profile exists
- GIVEN Environment `AWS_ACTUAL` and a successful apply
- WHEN instance profiles are listed
- THEN `hr-paid-bastion` exists
- AND `aws_instance.bastion` uses that profile, not `LabInstanceProfile`
- AND the profile allows `GetSecretValue` on `heavy-rental/ssh/*`
- AND the profile does not allow `GetSecretValue` on `heavy-rental/portal` or `heavy-rental/rest`
