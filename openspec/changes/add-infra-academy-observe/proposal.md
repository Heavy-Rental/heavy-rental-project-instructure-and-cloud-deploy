# Proposal: Add Academy Operate / Monitor (CloudWatch + CloudTrail)

## Why

Deploy already creates the estate. DevSecOps **Operate** (SSM, `stop`, `destroy`) exists. **Monitor** does not: there is no CloudTrail, no CloudWatch dashboard or alarms, and no durable access/flow logs. AWS study §2.1 says CD **creates** those watchers; operators **use** them after go-live.

## What Changes

- OpenSpec, OpenSPDD, and ADR 0015 for Academy observe (no new IAM).
- Terraform in `terraform/academy/observe.tf`: S3 observe bucket, CloudTrail (S3 only), VPC flow logs (S3), ALB access logs, CloudWatch alarms + dashboard, empty log groups, optional SNS email.
- Workflow passes optional Environment `ALARM_EMAIL`. Apply summary prints dashboard / trail / bucket.
- Reconcile/sweep know the new unique names so apply/destroy stay repeatable on Vocareum.

## Capabilities

### New Capabilities

- `infra-academy-observe`

### Modified Capabilities

- `infra-academy-scope`: apply now provisions Monitor resources; still no `aws_iam_role`

## Impact

- **This repo:** first CloudWatch / CloudTrail objects on `action=apply`. Optional Environment variable `ALARM_EMAIL`.
- **Vocareum:** only `LabRole` / `LabInstanceProfile` (data sources). Trail and flow logs go to S3 (bucket policy). No trail → CloudWatch Logs. No RDS enhanced monitoring.
- **Not in this change:** CloudWatch Agent on guests, X-Ray, AMP, OpenSearch, GuardDuty, Config, Budgets, paid OIDC.
