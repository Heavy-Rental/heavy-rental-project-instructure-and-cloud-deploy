# Design: Maintenance bastion for SSH hops

## Context

ADR 0012 forbids internet `:22` on app guests. ADR 0011 keeps PEMs out of Terraform and off app disks. Vocareum allows 9 EC2.

## Goals / Non-Goals

**Goals:** one public-subnet jump host; SSM always; optional operator CIDR SSH; SSH from bastion to the four app roles.

**Non-Goals:** Docker/compose on the bastion; EIP; ALB; `:22` from `0.0.0.0/0`; a second bastion for AZ redundancy; putting **private** keys on portal/REST/Haystack/Neo4j disks.

## Decisions

1. Single `aws_instance` `hr-bastion` (not an ASG). `stop` uses `stop-instances`; apply starts it via `aws_ec2_instance_state`.
2. Public subnet + associate public IP so ProxyJump is possible when CIDRs are set. Empty CIDRs → SSM only.
3. Hop **private** key plus copies of the four role **private** keys on the bastion (ADR 0021 exception to ADR 0011). `private_key_pem` in SM is the private key, not the public `.pub`. Interactive SSM becomes `ec2-user`; operators do not write `~/.ssh/config`.
4. Paid IAM is SSM + describe + `GetSecretValue` on `heavy-rental/ssh/*` only; no ECR / app secrets.
5. Conflict order: OpenSpec → OpenSPDD → ADR 0021 → Terraform / scripts.

## Risks

- 9-EC2 cap is full. Adding EKS nodes or another ASG while this estate is InService fails.
- `configure-only` on an old estate without `hr-bastion` warns and still writes app PEMs.
