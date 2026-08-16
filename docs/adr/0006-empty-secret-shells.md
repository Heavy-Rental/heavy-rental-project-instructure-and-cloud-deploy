# ADR 0006: Empty Secrets Manager shells

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

App CD and Ansible need stable secret **ids** (`heavy-rental/portal`, …). Stripe, DB passwords, and PEMs must not live in `.tf` or in Terraform state as plaintext versions. `sync-secrets` is branch 3.

## Decision

Terraform creates `aws_secretsmanager_secret` shells (including `heavy-rental/ssh/*`) with `recovery_window_in_days = 0`. It does **not** create `aws_secretsmanager_secret_version`. RDS uses `var.db_master_password` from GitHub Environment `SPRING_DATASOURCE_PASSWORD` only so the instance can boot; that value is written to `heavy-rental/rest` later.

## Consequences

- App CD `describe-secret` succeeds; field checks fail until branch 3.
- Destroy can delete secrets immediately (no 7–30 day recovery window).
- RDS password exists in Terraform state (AWS provider). It is not echoed. It is not the Vocareum AWS keys.
