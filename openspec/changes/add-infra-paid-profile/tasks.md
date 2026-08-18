# Tasks: add-infra-paid-profile

## 1. Specs

- [x] 1.1 OpenSpec proposal, design, tasks, scope + paid-profile specs
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADR 0016; update ADR 0001 status

## 2. Terraform

- [x] 2.1 `var.deployment` academy|paid; LabRole data sources only on academy
- [x] 2.2 Paid `iam.tf` instance profiles; launch templates use local profile name
- [x] 2.3 Observe / state bucket suffix from deployment

## 3. Workflow + scripts

- [x] 3.1 Profile assert; OIDC on paid; Vocareum on academy
- [x] 3.2 `TF_VAR_deployment`; LabRole preflight academy-only
- [x] 3.3 Reconcile/sweep/backend names use profile suffix
- [x] 3.4 OPERATOR-GUIDE / BOOTSTRAP / ARCHITECTURE / spec index
