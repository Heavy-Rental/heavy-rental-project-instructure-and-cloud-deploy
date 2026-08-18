# SPDD Analysis: add-infra-academy-deploy-projects

**Status:** Active  
**Audience:** Implementers of Academy `deploy-projects`  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-deploy-projects.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-deploy-projects/proposal.md)

## Problem

`apply` / `configure-only` leave portal / REST / Haystack uncomposed so private GHCR cannot break those actions. Operators still need one infra button to first-compose all three apps plus `rds_logical`. Running `site.yml` from a laptop lacks Vocareum/SSM setup. Putting `site.yml` back on apply reintroduces pull access denied.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Later run | A second `workflow_dispatch` after apply or configure-only succeeded. Not a job `needs:` of apply. |
| Preflight | Runner checks ASGs + public GHCR/ECR tags before SSM |
| site.yml | Full compose: guest_base + portal + neo4j + rest + haystack + rds_logical |
| App CD | Per-app image roll after first compose |

## Stakeholders

- Class operators (one-shot compose after the estate is up)
- App CD (still owns later portal / REST / Haystack tags)

## Risks

1. **Chaining onto apply** — private GHCR fails apply again. Separate action only.
2. **Stock nginx** — would downgrade a CI portal. Refuse on this action.
3. **One tar** — `image_http_url` would `docker load` onto every group. Refuse.
4. **After app CD** — re-run resets all three guests to infra Environment tags. Document that.

## Strategy

1. Specify OpenSpec + ADR 0014.
2. New workflow job; keep configure Ansible job unchanged.
3. Align infra Haystack role with app CD.

## Success

- `deploy-projects` runs only when selected, after apply/configure-only in a **separate** run.
- Preflight fails on missing ASGs, empty REST/Haystack, `nginx` portal, private GHCR, or a tar URL.
- `site.yml` composes the three apps and `rds_logical`.
- `apply` / `configure-only` still never invoke `site.yml`.
