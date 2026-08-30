# ADR 0011: SSH PEMs after InService, not in Terraform

- **Status:** Accepted
- **Date:** 2026-08-17
- **Branch:** `HR-162-implement-aws-infrastructure-configuration-using-ansible-compose`

## Context

Everyday operate is SSM Session Manager (`LabInstanceProfile` / `LabRole`). Break-glass SSH still needs a PEM. `tls_private_key` in Terraform would put the private key in state.

## Decision

`sync-ssh-keys` runs only after each app ASG has InService guests **and** `hr-bastion` is running (if the instance exists). The runner generates an ed25519 key per role (or reuses a valid **private** key already in Secrets Manager), `put-secret-value`s `heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion}` as `key_name` + `private_key_pem` (private key) + `public_key` (authorized_keys line), and installs **only the public key** via SSM on app guests. Launch templates stay without `key_name`. The maintenance bastion is the ADR 0021 exception: it receives the hop **private** key (`id_ed25519`) **and** copies of the four role **private** keys (`id_portal`, `id_rest`, `id_haystack`, `id_neo4j`) so Host aliases can set `IdentityFile`. App guests never receive a private key.

## Consequences

- PEMs are not in Terraform state.
- If an app ASG desired=0, the job fails closed (nothing to install onto).
- If `hr-bastion` is missing, the job warns and still writes app PEMs.
- Break-glass: SSM onto `hr-bastion` (becomes `ec2-user`; no operator SSH config), then `ssh portal` (etc.). App CD stays SSM.
