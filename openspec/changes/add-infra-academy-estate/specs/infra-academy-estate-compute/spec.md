# Delta for infra-academy-estate-compute

> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-estate-rest-alb/spec.md) / [ADR 0018](../../../../../docs/adr/0018-public-rest-alb.md): `hr-alb-rest` is internet-facing in the **public** subnets. Haystack ALB stays internal. App ASGs stay in private-app subnets.

## Purpose

Every compute role is a launch template + Auto Scaling group with `LabInstanceProfile`. No new IAM.

## ADDED Requirements

### Requirement: Four named ASGs
Terraform SHALL create `asg-portal` (React/nginx), `asg-rest` (Spring Boot), `asg-haystack` in both private-app subnets and `asg-neo4j` in both private-data subnets. Each of those four groups SHALL be Multi-AZ: `min=2 desired=2 max=2`, `vpc_zone_identifier` spanning both subnets of that tier, and balanced AZ distribution so one guest lands in each AZ.

#### Scenario: Describe returns the groups
- GIVEN `action=apply` succeeded
- WHEN `describe-auto-scaling-groups` is called for those four names
- THEN each group exists
- AND portal/rest/haystack have min=2 desired=2 max=2 across both app AZs
- AND `asg-neo4j` has min=2 desired=2 max=2 across both data AZs

### Requirement: App load balancers span both AZs
The public portal ALB SHALL register both public subnets. As of this delta, the REST and Haystack ALBs SHALL register both private-app subnets (REST was internal). The Bolt NLB SHALL register both private-data subnets. **Current:** REST ALB is internet-facing in the public subnets (banner above); Haystack stays internal.

#### Scenario: Each ALB has two subnets
- GIVEN `action=apply` succeeded
- WHEN each load balancer is described
- THEN it lists two subnets in two different AZs

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

> **ALB probes (later):** `tg-rest` is `GET <instance>:8080/actuator/health` matcher `200-299`. `tg-haystack` is `GET <instance>:8000/health` matcher `200-299`. Those checks do **not** replace instances (this requirement). See [`add-infra-paid-pipeline` / `infra-estate-rest-alb`](../../../add-infra-paid-pipeline/specs/infra-estate-rest-alb/spec.md).

#### Scenario: Unhealthy target does not kill the instance
- GIVEN containers are not installed
- WHEN the target group marks the instance unhealthy
- THEN the ASG does not terminate it for ELB health
