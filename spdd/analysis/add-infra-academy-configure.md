# SPDD Analysis: add-infra-academy-configure

**Status:** Active  
**Audience:** Implementers of Academy configure (`HR-162`)  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-configure.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-configure/proposal.md)

## Problem

The estate exists. Shells are empty. Guests have no Docker compose. Operators cannot pause RDS without `destroy`.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Terraform | Creates architecture and resources. Not guest Docker. |
| Ansible | Configures existing guests only. No VPC/ASG/RDS create. |
| sync-secrets | `put-secret-value` from Terraform outputs + Environment app secrets, including Haystack `SOURCE_*` / `TARGET_*` |
| sync-ssh-keys | PEMs after InService; public key via SSM |
| First compose | Ansible on all four groups **after** Terraform apply |
| configure-only | No Terraform apply. Docker all guests; compose **Neo4j only** |
| stop | Pause: ASG desired=0 + stop both RDS. Not destroy |
| Image | CI tar or registry tag. No `docker build` |

## Stakeholders

- Class operators (configure-only after Start Lab; stop at end of day)
- App CD (same playbook, one group; lives in pipeline-development; must not run Terraform)

## Risks

1. **Vocareum keys in SM** — never write `AWS_*`.
2. **PEM in logs / on portal** — `set +x`; portal never fetches `sk_` or PEMs.
3. **Missing REST/Haystack image** — fail closed.
4. **ELB health too early** — keep ADR 0008 EC2 health.
5. **NAT Gateway after stop** — still bills; say so in the summary.

## Strategy

1. Specify OpenSpec capabilities.
2. ADRs 0011–0012.
3. Scripts + Ansible + workflow jobs on `HR-162`.

## Success

- `apply` runs Terraform (architecture) then `sync-secrets` (including Haystack `SOURCE_*` / `TARGET_*`) then the **same** Ansible as configure-only (`configure.yml`).
- `apply` and `configure-only` install Docker on all guests and compose **Neo4j only**. They do not pull portal/REST/Haystack images.
- `stop` pauses ASGs + both RDS; Gateways remain.
- `destroy` still requires `confirm_destroy=destroy`.
- Ansible never creates VPC/ASG/RDS.
