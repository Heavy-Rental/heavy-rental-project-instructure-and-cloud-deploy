# Delta for infra-academy-observe

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-observe/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): alarm `hr-bastion-status` (`StatusCheckFailed` on the single instance). No `GroupInServiceInstances` for a bastion ASG.

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

### Requirement: Guest Docker logs to CloudWatch Logs
Ansible `guest_base` SHALL probe `logs:CreateLogStream` on `/heavy-rental/{portal,rest,haystack,neo4j}` using the instance profile (the same probe `apply`, `configure-only`, `deploy-projects`, and app CD use). When allowed, it SHALL set the Docker daemon log driver to `awslogs` for that group in `/etc/docker/daemon.json` using **Docker Engine** log-opts (`awslogs-region`, `awslogs-group`, `tag`; optional `mode` / `max-buffer-size`). It SHALL NOT set ECS-only option `awslogs-stream-prefix` (dockerd treats that as an unknown log-opt and will not start). It SHALL NOT install the CloudWatch Agent. It SHALL NOT create an IAM role on Academy. If the probe is denied, or if dockerd cannot start with `daemon.json`, guests SHALL keep the `json-file` driver so compose still starts, and Ansible SHALL NOT fail the play. Paid `hr-paid-*` roles SHALL allow `logs:CreateLogStream` and `logs:PutLogEvents` on their own log group.

#### Scenario: Awslogs when CreateLogStream is allowed
- GIVEN apply created `/heavy-rental/portal` and the guest instance profile can CreateLogStream
- WHEN `configure-only` or `deploy-projects` (or app CD `guest_base`) runs
- THEN `/etc/docker/daemon.json` uses `log-driver` `awslogs` and `awslogs-group` `/heavy-rental/portal`
- AND `log-opts` include Docker Engine `tag`
- AND `log-opts` do not include `awslogs-stream-prefix`

#### Scenario: Json-file when LabRole denies logs
- GIVEN CreateLogStream on `/heavy-rental/neo4j` is denied
- WHEN `guest_base` runs on a neo4j guest
- THEN Ansible does not fail the play
- AND the Docker log driver is not switched to `awslogs`

#### Scenario: Json-file when dockerd rejects daemon.json
- GIVEN `guest_base` wrote `/etc/docker/daemon.json` for `awslogs`
- AND dockerd cannot start with that file
- WHEN the play continues
- THEN Ansible does not fail the play
- AND Docker is running with the `json-file` driver so compose can start

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
