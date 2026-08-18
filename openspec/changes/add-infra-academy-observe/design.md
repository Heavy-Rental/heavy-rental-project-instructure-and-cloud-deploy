# Design: Academy Operate / Monitor

## Context

`AWS-INFRASTRUCTURE-FEASIBILITY.md` §2.1 lists Monitor services for Academy: CloudWatch Logs/Metrics/Alarms, SNS, CloudTrail, lab budget UI. Vocareum cannot create IAM roles (ADR 0005). The same study forbids CloudTrail → CloudWatch Logs and RDS enhanced monitoring.

Guests already run as **`LabInstanceProfile` → `LabRole`**. Observe must keep that pairing. It must not invent a logging role.

## Goals / Non-Goals

**Goals:**

- `action=apply` creates a CloudTrail (management events → S3), VPC flow logs → S3, ALB access logs → S3, CloudWatch metric alarms, one dashboard, four log-group shells.
- The only IAM identity in the estate remains **`LabRole`** (data source). Launch templates stay on `LabInstanceProfile`.
- Optional SNS email when Environment `ALARM_EMAIL` is set (operator confirms the subscription).
- Re-apply after lost state imports named observe objects. Destroy + sweep remove them.

**Non-Goals:**

- `aws_iam_role` / changing LabRole’s trust policy
- CloudTrail `cloud_watch_logs_role_arn` (Vocareum deny + needs a role CloudTrail can assume; LabRole trusts EC2, not CloudTrail)
- VPC flow logs → CloudWatch Logs (needs `vpc-flow-logs.amazonaws.com` trust; we cannot edit LabRole)
- CloudWatch Agent / `awslogs` Docker driver (LabRole may lack `logs:PutLogEvents`; guests keep `docker logs` over SSM)
- RDS `monitoring_interval` / Performance Insights
- X-Ray, AMP/Grafana, OpenSearch, GuardDuty, Config, AWS Budgets
- A new workflow `action`

## Decisions

1. **One observe bucket** `heavy-rental-observe-<account>-academy` with service-principal policies (CloudTrail, ELB, `delivery.logs.amazonaws.com`). No IAM role. 14-day expiry.
2. **CloudTrail `heavy-rental-academy`** writes prefix `cloudtrail/`. No CloudWatch Logs group or role on the trail (ADR 0015).
3. **VPC flow logs to S3** (`vpc-flow/`). S3 destination does not use `iam_role_arn`.
4. **Alarms** on ALB 5xx / unhealthy hosts, RDS CPU / free storage, ASG `GroupInServiceInstances`. Standard 5-minute metrics.
5. **Dashboard** `heavy-rental-academy` for the same signals (including p99 target response time).
6. **Log group shells** `/heavy-rental/{portal,rest,haystack,neo4j}` only. No agent.
7. **`LabRole` check:** Terraform continues to data-source `LabRole` / `LabInstanceProfile` and fails plan unless the profile’s role is `LabRole`. Observe creates no other role.
8. **Conflict order:** OpenSpec → OpenSPDD Safeguards → ADR 0005 + 0015 → `.tf` / YAML.

## Risks / Trade-offs

- CloudTrail + flow logs + ALB logs use S3 (small vs two NAT Gateways). Session end does not stop them.
- Some Vocareum images cap trails at one. Unique name + reconcile import; if CreateTrail is denied, skip is not allowed — operator sees the error.
- SNS email stays unconfirmed until the operator clicks AWS’s mail. Alarms still exist without a subscription.
- Shared LabRole is unchanged: guests can theoretically read secrets; observe does not widen IAM.
