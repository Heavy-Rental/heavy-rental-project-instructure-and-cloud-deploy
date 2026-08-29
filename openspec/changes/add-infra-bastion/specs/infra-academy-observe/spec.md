# Delta for infra-academy-observe (bastion status)

## MODIFIED Requirements

### Requirement: CloudWatch alarms and dashboard
Apply SHALL keep `GroupInServiceInstances` alarms on `asg-portal`, `asg-rest`, `asg-haystack`, and `asg-neo4j`. Apply SHALL create alarm `hr-bastion-status` on `StatusCheckFailed` for instance `hr-bastion`. Apply SHALL NOT create `GroupInServiceInstances` for a bastion ASG.

#### Scenario: Bastion status alarm exists
- GIVEN `action=apply` succeeded
- WHEN CloudWatch alarms are listed
- THEN `hr-bastion-status` exists
- AND `hr-asg-bastion-inservice` does not exist
