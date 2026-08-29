# SPDD Analysis: add-infra-bastion

**Status:** Active  
**Companion:** [prompt](../prompt/add-infra-bastion.md) · [OpenSpec](../../openspec/changes/add-infra-bastion/proposal.md) · [ADR 0021](../../docs/adr/0021-maintenance-bastion-ssh.md)

## Problem

Private app guests cannot be reached with SSH from the internet, and opening `:22` from `0.0.0.0/0` is forbidden. Operators still need a jump path.

## Concepts

| Concept | Meaning |
| --- | --- |
| Bastion | `hr-bastion` single EC2 in a public subnet |
| Hop key | Bastion PEM; public on app guests + `hr-bastion`; private on `hr-bastion` only |
| CIDR SSH | Optional `BASTION_SSH_CIDRS`; never `0.0.0.0/0` |

## Safeguards

- Do not open app `:22` from `0.0.0.0/0`.
- Do not put hop PEMs on portal / REST / Haystack / Neo4j.
- Do not compose Docker on the bastion.
- Do not wrap `hr-bastion` in an ASG or raise guest count above 9.
- Do not add `tls_private_key` / `key_name` to Terraform.
