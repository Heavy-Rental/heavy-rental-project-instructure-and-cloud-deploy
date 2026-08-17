# Delta for infra-academy-estate-compute

## Purpose

Every compute role is a launch template + Auto Scaling group with `LabInstanceProfile`. No new IAM.

## ADDED Requirements

### Requirement: Four named ASGs
Terraform SHALL create `asg-portal`, `asg-rest`, `asg-haystack` in both private-app subnets and `asg-neo4j` in both private-data subnets.

#### Scenario: Describe returns the groups
- GIVEN `action=apply` succeeded
- WHEN `describe-auto-scaling-groups` is called for those four names
- THEN each group exists
- AND portal/rest/haystack have min=2 desired=2 max=2
- AND `asg-neo4j` has min=2 desired=2 max=2 across both data AZs

### Requirement: LabInstanceProfile only
Launch templates SHALL attach the existing instance profile named `LabInstanceProfile`. That profile SHALL use the existing IAM role named `LabRole`. The configuration SHALL NOT contain `aws_iam_role` or `aws_iam_instance_profile` resources (data sources only).

#### Scenario: No IAM create
- GIVEN `terraform/academy/` is validated
- WHEN resources are listed
- THEN there is no `aws_iam_role` resource

#### Scenario: Profile uses LabRole
- GIVEN Vocareum pre-created `LabInstanceProfile` and `LabRole`
- WHEN `action=plan` runs
- THEN plan fails unless `LabInstanceProfile` role is `LabRole`

### Requirement: No SSH key in Terraform
Launch templates SHALL NOT set `key_name`. The configuration SHALL NOT contain `tls_private_key`.

#### Scenario: PEMs wait for branch 3
- GIVEN `action=apply` completes
- THEN no job writes a PEM to Secrets Manager
- AND launch templates have no `key_name`

### Requirement: EC2 health until compose
`asg-portal`, `asg-rest`, and `asg-haystack` SHALL use `health_check_type = EC2` so empty guests are not replaced.

#### Scenario: Unhealthy target does not kill the instance
- GIVEN containers are not installed
- WHEN the target group marks the instance unhealthy
- THEN the ASG does not terminate it for ELB health
