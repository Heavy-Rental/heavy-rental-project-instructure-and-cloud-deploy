# Proposal: Academy `deploy-projects`

## Why

`apply` and `configure-only` only install Docker and compose Neo4j. Operators still need one infra action to first-compose portal + REST + Haystack on the existing estate without putting `site.yml` back on apply (private GHCR fails). App CD remains the day-to-day single-image roll.

## What Changes

- New `workflow_dispatch` action `deploy-projects`.
- That action is a **later run** after a successful `apply` or `configure-only`. It is not chained onto those actions.
- Image preflight on the runner, then `playbooks/site.yml` over SSM.
- OpenSpec capability, OpenSPDD REASONS, ADR 0014.
- Infra Haystack role matches app CD (env aliases + `uv run` sidecars).

## Capabilities

### New Capabilities

- `infra-academy-deploy-projects`

### Modified Capabilities

- `infra-academy-scope`: `deploy-projects` is an allowed action
- `infra-academy-ansible`: apply/configure-only still MUST NOT invoke `site.yml`; `deploy-projects` MUST

## Impact

- Operators set Environment `academy` variables `PORTAL_IMAGE`, `REST_IMAGE`, `HAYSTACK_IMAGE` (public GHCR or ECR) on **this** repo.
- **Not in this change:** Terraform, paid/OIDC, GHCR PAT on the guest, auto-run after apply.
