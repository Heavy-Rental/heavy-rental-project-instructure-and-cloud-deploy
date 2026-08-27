# REASONS Canvas: add-infra-academy-configure

## Role

Implement Academy configure on `HR-162`. Vocareum only.

## Experience

Follow `ANSIBLE-PROCESS.md` and AWS study §8.2. Everyday path is SSM.

## Ask

`sync-secrets` → `sync-ssh-keys` → Ansible `configure.yml` (Docker + Neo4j only) → `stop`. Portal / REST / Haystack compose is later `deploy-projects` / `site.yml`.

## Safeguards

- No `aws_iam_role` / OIDC / `tls_private_key`.
- No Vocareum keys in Secrets Manager or on EC2.
- No `${{ inputs.aws_secret` interpolation.
- No Neo4j container on `asg-haystack`.
- No `sk_` on `heavy-rental/portal`.
- No `docker build`.
- Ansible does **not** create VPC, ASGs, ALBs, or RDS (Terraform only).
- Ansible does **not** invent `SOURCE_*` / `TARGET_*` (infra `sync-secrets` only).
- `configure-only` does not compose portal / REST / Haystack.
- `stop` does not delete NAT Gateways.
- `destroy` still needs `confirm_destroy=destroy`.

## Output

OpenSpec + ADRs + scripts + `ansible/` + workflow jobs.

## Next

Paid stays later. Academy app CD is in pipeline-development (`deploy-pipeline/`).
