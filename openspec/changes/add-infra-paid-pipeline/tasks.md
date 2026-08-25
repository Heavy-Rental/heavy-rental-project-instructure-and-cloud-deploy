# Tasks: add-infra-paid-pipeline

## 1. Specs

- [x] 1.1 OpenSpec proposal, design, tasks, paid-pipeline + REST ALB + scope/sg deltas
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADR 0017 (two Actions), ADR 0018 (public REST ALB); update 0001 / 0016
- [x] 1.4 Raise specs to estate bar: paid-profile / sync-secrets / observe deltas; canonical REASONS; thicken ADRs and `specification/pipelines/infra-paid.md`

## 2. Terraform

- [x] 2.1 REST ALB internet-facing in public subnets; SG :8080 from internet; keep portal → REST
- [x] 2.2 Paid SSM transfer bucket; guest GetObject/ListBucket; output name
- [x] 2.3 CloudTrail / dashboard name `heavy-rental-${var.deployment}` (academy string unchanged)

## 3. Workflows

- [x] 3.1 Each Action owns its jobs; `aws-infra-estate.yml` removed (ADR 0019)
- [x] 3.2 Academy workflow: Vocareum keys, LabRole preflight, refuse non-academy, no `id-token: write`
- [x] 3.3 `aws-infra-paid.yml`: OIDC only, refuse non-AWS_ACTUAL and Vocareum keys
- [x] 3.4 Paid Ansible uses SSM bucket; academy keeps tfstate bucket
- [x] 3.5 Reconcile/sweep observe names follow `DEPLOYMENT`

## 4. Docs

- [x] 4.1 BOOTSTRAP / OPERATOR-GUIDE / ARCHITECTURE / README / VERSIONS / spec index
- [x] 4.2 Sample OIDC trust + runner policy JSON
