# SPDD Analysis: add-infra-academy-observe

**Status:** Active  
**Audience:** Implementers of Academy Monitor (CloudWatch / CloudTrail on `action=apply`)  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-observe.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-observe/proposal.md)

## Problem

The estate is deployed and can be stopped or destroyed. Operators have no CloudTrail, no CloudWatch dashboard/alarms, and no durable ALB or VPC logs. AWS study §2.1 says CD should **create** those watchers. Vocareum still forbids creating IAM.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Observe bucket | Account-scoped S3 `heavy-rental-observe-<account>-academy` for trail, ALB, flow logs |
| S3-only trail | CloudTrail management events; **no** CloudWatch Logs on the trail |
| LabRole | Pre-created Vocareum role inside `LabInstanceProfile`. **Never** create IAM. Do not attach LabRole to CloudTrail or flow-log delivery (wrong trust). |
| Alarm shells | CloudWatch alarms on ALB / RDS / ASG standard metrics |
| Log group shell | `/heavy-rental/{app}` with no agent writing to it |
| Paid | Still another workflow / state key |

## Stakeholders

- Class operators (`apply` after Start Lab; watch credits and the dashboard)
- Destroy / reconcile (named leftovers)
- App CD (unchanged; still no Terraform)

## Risks

1. **IAM create** — Vocareum rejects `aws_iam_role`. Data-source `LabRole` only.
2. **Trail → CloudWatch Logs** — Vocareum deny + needs a role CloudTrail can assume. LabRole trusts EC2. Use S3.
3. **Flow logs → CloudWatch Logs** — needs `vpc-flow-logs.amazonaws.com` on the role. Use S3.
4. **RDS enhanced monitoring** — allow-list and cost. Keep `monitoring_interval = 0`.
5. **Second trail** — some labs allow one trail. Unique name + import on re-apply.
6. **Observe S3 after session end** — still holds logs and bills a little until destroy.

## Strategy

1. Specify behavior (OpenSpec `infra-academy-observe`).
2. Bind safeguards in the REASONS Canvas and ADR 0015 (with ADR 0005).
3. Add `observe.tf`; enable ALB access logs and ASG group metrics; pass `ALARM_EMAIL`.
4. Extend reconcile/sweep for named observe objects.

## Success

- `action=apply` creates trail `heavy-rental-academy`, dashboard `heavy-rental-academy`, alarm `hr-alb-portal-5xx`.
- `terraform validate` is green. No `aws_iam_role`. No trail CloudWatch Logs arguments.
- Launch templates still use `LabInstanceProfile` / `LabRole`.
- `destroy` + sweep remove the trail and observe bucket.
