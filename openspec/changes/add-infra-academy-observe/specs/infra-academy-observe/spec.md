# Delta for infra-academy-observe

## Purpose

`action=apply` provisions Academy Monitor resources (CloudWatch + CloudTrail + S3 logs). Operate (`stop` / `destroy` / SSM) is unchanged. Vocareum IAM stays `LabRole` only.

## ADDED Requirements

### Requirement: Apply creates S3-backed audit and access logs
On a successful `action=apply`, Terraform SHALL create a CloudTrail named `heavy-rental-academy` that writes management events to the observe S3 bucket, VPC flow logs on `aws_vpc.academy` destined to that bucket, and ALB access logs on the portal, REST, and Haystack load balancers. The trail SHALL NOT set `cloud_watch_logs_group_arn` or `cloud_watch_logs_role_arn`.

#### Scenario: Trail and flow logs land in S3
- GIVEN a live Vocareum session and Environment `academy`
- WHEN the operator runs `action=apply`
- THEN CloudTrail `heavy-rental-academy` exists
- AND the trail has no CloudWatch Logs group
- AND a VPC flow log on the estate VPC uses destination type `s3`
- AND `hr-alb-portal` access logs are enabled on the observe bucket

### Requirement: CloudWatch alarms and dashboard
Apply SHALL create CloudWatch metric alarms for public and internal ALB 5xx and unhealthy hosts, both RDS CPU and free storage, and `GroupInServiceInstances` on `asg-portal`, `asg-rest`, `asg-haystack`, and `asg-neo4j`. Apply SHALL create dashboard `heavy-rental-academy`. RDS `monitoring_interval` SHALL remain `0`.

#### Scenario: Dashboard and ALB 5xx alarm exist
- GIVEN apply succeeded
- WHEN the operator opens CloudWatch
- THEN dashboard `heavy-rental-academy` exists
- AND alarm `hr-alb-portal-5xx` exists
- AND neither RDS instance has enhanced monitoring

### Requirement: Only LabRole
Observe Terraform SHALL NOT contain `aws_iam_role` or `aws_iam_instance_profile` resources. Launch templates SHALL keep `iam_instance_profile.name = LabInstanceProfile`. Plan SHALL fail unless that profile’s role is `LabRole`.

#### Scenario: No new IAM on observe apply
- GIVEN the observe module is in the estate root
- WHEN `terraform plan` runs
- THEN no create of `aws_iam_role` is planned
- AND `lab_role` output is `LabRole`

### Requirement: Optional SNS email
When `alarm_email` is empty, apply SHALL still create the SNS topic and alarms. When `alarm_email` is set, apply SHALL create an email subscription on that topic. Alarm descriptions SHALL use resource names, not internal REST or Haystack DNS.

#### Scenario: No email still creates alarms
- GIVEN Environment `ALARM_EMAIL` is unset
- WHEN apply succeeds
- THEN topic `hr-academy-alarms` exists
- AND no email subscription is required for apply to exit 0

### Requirement: Destroy removes observe leftovers
`action=destroy` SHALL destroy observe resources in state and sweep a leftover trail `heavy-rental-academy`, observe bucket, named alarms, dashboard, log groups, SNS topic, and VPC flow logs that were never in state.

#### Scenario: Destroy clears the trail
- GIVEN confirm_destroy is `destroy`
- WHEN destroy finishes
- THEN CloudTrail `heavy-rental-academy` is gone
- AND the observe bucket is gone or emptying
