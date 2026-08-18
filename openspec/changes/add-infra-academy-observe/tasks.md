# Tasks: add-infra-academy-observe

## 1. OpenSpec + OpenSPDD + ADR

- [x] 1.1 Proposal, design, tasks, `infra-academy-observe` + scope delta
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADR 0015 (S3 trail / flow logs; LabRole only)
- [x] 1.4 Update `specification/README.md`, `docs/adr/README.md`, `OPERATOR-GUIDE.md`, `BOOTSTRAP.md`, `ARCHITECTURE.md`

## 2. Terraform observe (`terraform/academy/`)

- [x] 2.1 Observe bucket + lifecycle + service-principal policy (no IAM role)
- [x] 2.2 CloudTrail S3-only; no `cloud_watch_logs_*`
- [x] 2.3 VPC flow log → S3; ALB access logs on portal/REST/Haystack
- [x] 2.4 Alarms + dashboard + log-group shells + optional SNS
- [x] 2.5 ASG `enabled_metrics`; `LabRole` data source unchanged
- [x] 2.6 Outputs; `terraform fmt` / `validate` (no backend)

## 3. Workflow + reuse

- [x] 3.1 `TF_VAR_alarm_email` from Environment `ALARM_EMAIL`
- [x] 3.2 Apply summary: dashboard, trail, bucket, LabRole
- [x] 3.3 Reconcile import + destroy sweep of named observe objects
