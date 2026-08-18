# ADR 0014: `deploy-projects` is a later run, not part of apply

- **Status:** Accepted
- **Date:** 2026-08-18
- **Change:** `add-infra-academy-deploy-projects`

## Context

`apply` used to invoke `site.yml` and failed on private GHCR (`pull access denied`). Apply was changed to `configure.yml` (Docker + Neo4j only). Operators still need an infra path to first-compose portal + REST + Haystack and run `rds_logical`. App CD already deploys one app at a time.

Chaining `site.yml` onto the end of `apply` / `configure-only` in the same run would restore the apply failure whenever Environment image tags are missing or private.

## Decision

`action=deploy-projects` is a **separate** `workflow_dispatch`. Operators run it **after** a successful `apply` or `configure-only`, not in the same run. The action refreshes secrets, preflights public GHCR or ECR tags (no stock nginx, no tar URL, no PAT on the guest), then runs `playbooks/site.yml` only. Apply and configure-only stay on `configure.yml`. Day-to-day image rolls stay app CD.

## Consequences

- Apply remains image-agnostic.
- First compose is two clicks: apply (or configure-only), then deploy-projects.
- Re-running deploy-projects after app CD resets all three guests to the infra Environment tags.
- `rds_logical` no longer depends on a laptop `site.yml`.
