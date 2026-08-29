# Delta for infra-academy-estate-compute (bastion)

## MODIFIED Requirements

### Requirement: Four named ASGs
The four app ASGs (`asg-portal`, `asg-rest`, `asg-haystack`, `asg-neo4j`) SHALL remain `min=2 desired=2 max=2`. Terraform SHALL **not** create `asg-bastion` or `lt-bastion`.

#### Scenario: Bastion is not an ASG
- GIVEN `action=apply` succeeded
- WHEN `describe-auto-scaling-groups` is called for `asg-bastion`
- THEN the group does not exist
- AND instance `hr-bastion` (`tag:Name=hr-bastion`) exists
