# REASONS Canvas: add-infra-academy-deploy-projects

## Role

Implement `action=deploy-projects` on Academy infra CD. Vocareum only.

## Experience

Follow OpenSpec `infra-academy-deploy-projects`. Everyday path is SSM. Apply stays image-agnostic.

## Ask

A later workflow run after `apply` or `configure-only` that preflights public/ECR tags and runs `site.yml`.

## Safeguards

- Do **not** chain `site.yml` onto `apply` or `configure-only`.
- No Terraform on `deploy-projects`.
- No `docker build`.
- No PAT / `GITHUB_TOKEN` on the guest.
- No stock `nginx` on this action.
- No `image_http_url` (one tar cannot satisfy three images).
- No Vocareum keys in Secrets Manager or on EC2.
- Ansible does **not** create VPC, ASGs, ALBs, or RDS.
- Day-to-day single-image rolls stay app CD.

## Output

OpenSpec + ADR 0014 + workflow job + Haystack role aligned with app CD.

## Next

Paid stays later. Prefer app CD after first compose.
