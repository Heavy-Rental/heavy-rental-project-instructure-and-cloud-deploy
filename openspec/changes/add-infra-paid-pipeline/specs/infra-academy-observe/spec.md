# Delta for infra-academy-observe (deployment-scoped names)

## MODIFIED Requirements

### Requirement: Apply creates S3-backed audit and access logs
On a successful `action=apply`, Terraform SHALL create a CloudTrail that writes management events to the observe S3 bucket, VPC flow logs on `aws_vpc.academy` destined to that bucket, and ALB access logs on the portal, REST, and Haystack load balancers. The trail name SHALL be `heavy-rental-academy` when `var.deployment` is `academy` and `heavy-rental-actual` when `var.deployment` is `actual`. Academy SHALL keep the historical name so apply does not replace an existing academy trail. The trail SHALL NOT set `cloud_watch_logs_group_arn` or `cloud_watch_logs_role_arn`.

#### Scenario: Academy trail name is unchanged
- GIVEN a live Vocareum session and Environment `academy`
- WHEN the operator runs `action=apply`
- THEN CloudTrail `heavy-rental-academy` exists
- AND the trail has no CloudWatch Logs group

#### Scenario: Paid trail uses actual name
- GIVEN Environment `AWS_ACTUAL` and a successful paid apply
- WHEN CloudTrail is listed
- THEN CloudTrail `heavy-rental-actual` exists
- AND the trail has no CloudWatch Logs group

### Requirement: CloudWatch alarms and dashboard
Apply SHALL create CloudWatch metric alarms for public and internal ALB 5xx and unhealthy hosts, both RDS CPU and free storage, and `GroupInServiceInstances` on `asg-portal`, `asg-rest`, `asg-haystack`, and `asg-neo4j`. Apply SHALL create dashboard `heavy-rental-academy` when `deployment` is `academy` and `heavy-rental-actual` when `deployment` is `actual`. RDS `monitoring_interval` SHALL remain `0`.

#### Scenario: Paid dashboard name
- GIVEN a successful paid apply
- WHEN the operator opens CloudWatch
- THEN dashboard `heavy-rental-actual` exists

### Requirement: Only LabRole on academy observe
Observe Terraform SHALL NOT contain `aws_iam_role` or `aws_iam_instance_profile` resources when `deployment` is `academy`. Launch templates SHALL keep `iam_instance_profile.name = LabInstanceProfile`. Plan SHALL fail unless that profile’s role is `LabRole`. Paid IAM (`hr-paid-*`, guest GetObject on the SSM bucket) lives in `iam.tf`, not as CloudTrail → CloudWatch Logs.

#### Scenario: No new IAM on academy observe apply
- GIVEN Environment `academy`
- WHEN `terraform plan` runs
- THEN no create of `aws_iam_role` is planned
- AND `lab_role` output is `LabRole`

### Requirement: Destroy removes observe leftovers for this deployment
`action=destroy` SHALL destroy observe resources in Terraform state and SHALL sweep leftover trail / dashboard / flow-log names for **this** `DEPLOYMENT` only (`heavy-rental-academy` or `heavy-rental-actual`). Academy sweep SHALL NOT delete `heavy-rental-actual`. Paid sweep SHALL NOT delete `heavy-rental-academy`. Scripts SHALL fail if `DEPLOYMENT` is unset.

#### Scenario: Paid destroy sweeps the actual trail
- GIVEN `DEPLOYMENT` is `actual` and `confirm_destroy` is `destroy`
- WHEN destroy and sweep finish
- THEN CloudTrail `heavy-rental-actual` is gone
- AND CloudTrail `heavy-rental-academy` was not queried

#### Scenario: Unset DEPLOYMENT fails closed
- GIVEN `DEPLOYMENT` is empty
- WHEN `sweep-estate-orphans.sh` starts
- THEN the script exits 1
- AND no CloudTrail is deleted
