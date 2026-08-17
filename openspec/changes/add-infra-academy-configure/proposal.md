# Proposal: Academy configure (secrets, Ansible compose, stop)

## Why

Branch 2 (`HR-161`) creates the estate. Guests have no containers, Secrets Manager shells are empty, and `configure-only` / `stop` fail closed. Branch 3 (`HR-162`) fills secrets, first-compose, and pause so the lab is operable.

## What Changes

- OpenSpec, OpenSPDD, ADRs 0011–0012.
- `sync-secrets` + `sync-ssh-keys` + Ansible on `action=apply` and `action=configure-only`.
- `action=stop`: ASG desired=0 + stop both RDS. NAT Gateways keep billing.
- `destroy` stays as branch 2 (`confirm_destroy=destroy`).

## Capabilities

### New Capabilities

- `infra-academy-sync-secrets`
- `infra-academy-sync-ssh`
- `infra-academy-ansible`
- `infra-academy-stop`

### Modified Capabilities

- `infra-academy-scope`: `configure-only` and `stop` are allowed; destroy unchanged
- `infra-academy-estate-apply`: apply continues to `sync-secrets` → Ansible

## Impact

- Operators set Environment `academy` secrets: `SPRING_DATASOURCE_PASSWORD`, `NEO4J_PASSWORD`, Stripe trio. Optional image URL for REST/Haystack.
- **Not in this change:** app CD, paid/OIDC, ELB health on ASGs, NAT instance.
