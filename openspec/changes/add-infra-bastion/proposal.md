# Proposal: Maintenance bastion for SSH hops

## Why

App guests have no public IP. Everyday operate is SSM. Operators still need a supported SSH path onto portal / REST / Haystack / Neo4j without opening `:22` from `0.0.0.0/0` on those security groups. Vocareum’s EC2 cap is 9; eight app guests leave room for one jump host.

## What Changes

- Terraform `hr-bastion` (single EC2) in a public subnet, `sg-bastion`, hop `:22` from that SG onto the four app SGs, SM shell `heavy-rental/ssh/bastion`, paid `hr-paid-bastion`.
- `sync-ssh-keys` writes `private_key_pem` (**private** key) + `public_key` to `heavy-rental/ssh/*`, installs the public key on all guests, and puts the hop **private** key plus copies of the four role private keys on the bastion.
- `stop` / sweep / reconcile / destroy include `hr-bastion`.
- Ansible compose playbooks do not target `bastion`.
- ADR 0021, operator helper `scripts/bastion-connect.sh`.

## Capabilities

### New Capabilities

- `infra-academy-bastion`

### Modified Capabilities

- `infra-academy-estate-compute`: `hr-bastion` single EC2 (not an ASG)
- `infra-academy-estate-sg`: app `:22` from `sg-bastion` only
- `infra-academy-estate-secrets-shells`: `heavy-rental/ssh/bastion`
- `infra-academy-sync-ssh`: hop key on bastion
- `infra-academy-stop`: `stop-instances` on `hr-bastion`
- `infra-academy-paid-profile`: `hr-paid-bastion`

## Impact

- Guest count **9 EC2** (cap). Re-run `apply` on an existing estate to create the instance. If leftover `asg-bastion` is still InService, scale it to desired=0 first so apply does not exceed the cap.
- Optional Environment variable `BASTION_SSH_CIDRS` (never `0.0.0.0/0`).
