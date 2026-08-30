# ADR 0021: Maintenance bastion for SSH hops

- **Status:** Accepted
- **Date:** 2026-08-29
- **Change:** `add-infra-bastion`
- **Related:** [0010](0010-two-nat-gateways.md) (NAT stays Gateways; this ADR uses the 9th EC2 slot), [0011](0011-pems-after-inservice.md), [0012](0012-ansible-over-ssm.md)

## Context

Portal, REST, Haystack, and Neo4j guests have no public IPs. Everyday operate is SSM (ADR 0012). Operators still need a supported SSH path onto those guests for break-glass maintenance. Opening `:22` from `0.0.0.0/0` on the app security groups is forbidden. Vocareum’s default EC2 cap is **9**; the four app ASGs already use **8**.

## Decision

Terraform creates a single **`aws_instance.bastion`** (`Name=hr-bastion`, `Role=bastion`): `t3.micro`, Amazon Linux 2023, **public subnet** AZ-0, public IP, no launch template, no Auto Scaling group, no ALB. Academy uses `LabInstanceProfile`. Paid creates `hr-paid-bastion` (SSM + describe instances + `GetSecretValue` on `heavy-rental/ssh/*` only; no ECR, no app secrets). `aws_ec2_instance_state` keeps the instance `running` on apply.

- `sg-bastion` allows inbound TCP 22 only from `var.bastion_ssh_cidrs` (Environment `BASTION_SSH_CIDRS`). Empty (the default) means **SSM onto the bastion**, then SSH to guests. `0.0.0.0/0` is rejected.
- App SGs (`sg-portal` / `sg-rest` / `sg-haystack` / `sg-neo4j`) allow inbound TCP 22 **only** from `sg-bastion`.
- `sync-ssh-keys` writes `heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion}`. `private_key_pem` is the **private** OpenSSH key (not the public `.pub` line). App guests get **only** the public key in `authorized_keys`. The bastion gets the hop **private** key (`~/.ssh/id_ed25519`) **and** copies of the four role private keys (`~/.ssh/id_portal`, `id_rest`, `id_haystack`, `id_neo4j`) so `hr-ssh-config` can set `IdentityFile`. `hr-ssh-pull-keys` re-reads those secrets onto the bastion. App guests still never receive a private key (ADR 0011).
- Ansible `configure.yml` / `site.yml` do **not** compose onto `bastion`.

Guest count is **9 EC2**. Do not add another instance while this host is running.

## Consequences

- Operators: `scripts/bastion-connect.sh` prints SSM and optional ProxyJump commands. Interactive SSM on the bastion becomes **ec2-user** (`/etc/profile.d/hr-ssm-ec2-user.sh`) so the hop key and Host aliases apply with **no operator SSH config**. On the bastion, `hr-ssh-targets` lists aliases; `ssh portal` (etc.) uses that role’s **private** key (`id_portal`, …) then the hop key (`id_ed25519`). If the shell is still `ssm-user`, `hr-ssh portal` does the same hop. `hr-ssh-pull-keys` re-reads `private_key_pem` from Secrets Manager (`private_key_pem` is the private key, not the public `.pub`). `.bashrc` refreshes aliases each login because app ASG IPs change.
- `action=stop` calls `stop-instances` on `hr-bastion`. The next `apply` starts it (`aws_ec2_instance_state`).
- SSH remains break-glass. Ansible and app CD stay on SSM.
