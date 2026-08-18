# Design: Academy `deploy-projects`

## Context

`configure.yml` keeps apply image-agnostic. `site.yml` is the full compose playbook. App CD already deploys one app at a time. A class/lab shortcut should compose all three apps **after** the estate is ready, with fail-closed images.

## Goals / Non-Goals

**Goals:**

- Opt-in action `deploy-projects` that runs only `site.yml`.
- Operator sequence: `apply` or `configure-only` first (separate workflow run), then `deploy-projects`.
- Preflight: public GHCR or ECR tags; no stock nginx; no single tar; ASGs exist.
- `rds_logical` runs (`CREATE EXTENSION vector`).
- Haystack compose matches app CD aliases / `uv run`.

**Non-Goals:**

- Chaining `site.yml` onto `apply` / `configure-only`.
- Terraform on this action.
- A PAT on the guest.
- Replacing portal / REST / Haystack app CD.

## Decisions

1. Separate job, not an `if` branch inside the configure Ansible job (ADR 0014).
2. `sync-secrets` + `sync-ssh-keys` still run (same as configure-only) so `REST_BASE_URL` is current.
3. Terraform job stays `plan` / `apply` only.
4. `image_http_url` is refused: one tar cannot satisfy three images.
5. Conflict order: OpenSpec → OpenSPDD → ADR → YAML.

## Risks / Trade-offs

- Re-running `deploy-projects` after app CD resets all three guests to infra Environment tags.
- Private GHCR still cannot be pulled; preflight fails before SSM.
