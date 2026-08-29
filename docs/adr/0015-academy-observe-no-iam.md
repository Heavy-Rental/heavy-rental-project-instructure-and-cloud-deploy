# ADR 0015: Academy observe uses LabRole and S3 — no logging IAM

- **Status:** Accepted (amended: guest Docker `awslogs`)
- **Date:** 2026-08-18
- **Amended:** 2026-08-29
- **Branch:** `HR-183-update-on-aws-infrastructure-pipeline-to-reuse-possible-aws-resource-during-creation`
- **Related:** [0005](0005-labinstanceprofile-only.md), [0017](0017-two-actions-academy-paid.md)

## Context

DevSecOps Monitor on Academy needs CloudTrail, CloudWatch alarms, and durable access/flow logs. Vocareum **cannot create IAM roles**. Every guest already uses **`LabInstanceProfile` → `LabRole`**.

CloudTrail delivery to CloudWatch Logs, and VPC flow logs to CloudWatch Logs, both require an IAM role whose **trust policy** allows `cloudtrail.amazonaws.com` or `vpc-flow-logs.amazonaws.com`. LabRole is trusted by **EC2** (and SSM). We must not create a second role, and we must not rewrite LabRole’s trust policy.

AWS study §2.1 also says Vocareum **cannot** enable CloudWatch logging on the trail. RDS enhanced monitoring is off the allow-list.

## Decision

1. Data-source **`LabRole`** and **`LabInstanceProfile`** only (ADR 0005). Observe adds no IAM resource. Plan still fails unless the profile’s role is `LabRole`.
2. CloudTrail `heavy-rental-academy` writes **only to S3** (bucket policy, CloudTrail service principal). Do **not** set `cloud_watch_logs_group_arn` or `cloud_watch_logs_role_arn`. Do **not** pass LabRole as the trail’s CloudWatch role. Paid (ADR 0017) names the trail `heavy-rental-actual`; the academy string is unchanged so apply does not replace it.
3. VPC flow logs use **`log_destination_type = s3`**. Do **not** set `iam_role_arn` (including LabRole).
4. ALB access logs use the same observe bucket (ELB service principal).
5. CloudWatch **metric** alarms and a dashboard use the AWS/ApplicationELB, AWS/RDS, and AWS/AutoScaling namespaces. No extra role.
6. Create log groups `/heavy-rental/{portal,rest,haystack,neo4j}`. Do **not** install the CloudWatch Agent. Guest Docker uses the **`awslogs` log driver** (dockerd on the host, instance profile) so container stdout lands in that app’s group. Ansible probes `logs:CreateLogStream` first; if LabRole denies it, guests stay on `json-file` so compose still starts. Paid `hr-paid-*` roles get `logs:CreateLogStream` / `logs:PutLogEvents` on their own group only. Still no new IAM on Academy.

## Consequences

- Apply works under the Vocareum federated user without CreateRole.
- Audit and flow logs are in S3, not Logs Insights, until a paid account can attach a purpose-built role.
- Operators watch the `heavy-rental-academy` dashboard and alarms (paid: `heavy-rental-actual`). Email needs `ALARM_EMAIL` plus a confirm click. Still no CloudTrail → CloudWatch Logs on either profile.
- Guest app logs: CloudWatch Logs `/heavy-rental/{app}` when the instance profile can put events; otherwise `docker logs` over SSM. LabRole permissions stay whatever Vocareum attached.
