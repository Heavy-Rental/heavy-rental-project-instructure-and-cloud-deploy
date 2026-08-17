# ADR 0011: SSH PEMs after InService, not in Terraform

- **Status:** Accepted
- **Date:** 2026-08-17
- **Branch:** `HR-162-implement-aws-infrastructure-configuration-using-ansible-compose`

## Context

Everyday operate is SSM Session Manager (`LabInstanceProfile` / `LabRole`). Break-glass SSH still needs a PEM. `tls_private_key` in Terraform would put the private key in state.

## Decision

`sync-ssh-keys` runs only after each of the four ASGs has InService guests. The runner generates an ed25519 key per role (or reuses a valid PEM already in Secrets Manager), `put-secret-value`s `heavy-rental/ssh/{portal,rest,haystack,neo4j}`, and installs **only the public key** via SSM. Launch templates stay without `key_name`.

## Consequences

- PEMs are not in Terraform state.
- If desired=0, the job fails closed (nothing to install onto).
- Configurer retrieves the PEM from SM and SSM port-forwards to `:22`.
