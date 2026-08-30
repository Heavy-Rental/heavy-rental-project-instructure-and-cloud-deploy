# SPDD Analysis: add-infra-bastion

**Status:** Active  
**Companion:** [prompt](../prompt/add-infra-bastion.md) · [OpenSpec](../../openspec/changes/add-infra-bastion/proposal.md) · [ADR 0021](../../docs/adr/0021-maintenance-bastion-ssh.md)

## Problem

Private app guests cannot be reached with SSH from the internet, and opening `:22` from `0.0.0.0/0` is forbidden. Operators still need a jump path.

## Concepts

| Concept | Meaning |
| --- | --- |
| Bastion | `hr-bastion` single EC2 in a public subnet |
| Hop key | `heavy-rental/ssh/bastion` `private_key_pem` (**private** key). Public line on app guests + bastion `authorized_keys`. Private file `id_ed25519` on `hr-bastion` only |
| Role keys | `heavy-rental/ssh/{portal,rest,haystack,neo4j}` `private_key_pem` in SM **and** copies on the bastion as `id_{role}`. Never a private key on app disks |
| CIDR SSH | Optional `BASTION_SSH_CIDRS`; never `0.0.0.0/0` |

## Safeguards

- Do not open app `:22` from `0.0.0.0/0`.
- Do not put hop or role **private** keys on portal / REST / Haystack / Neo4j disks.
- Do not compose Docker on the bastion.
- Do not wrap `hr-bastion` in an ASG or raise guest count above 9.
- Do not add `tls_private_key` / `key_name` to Terraform.
