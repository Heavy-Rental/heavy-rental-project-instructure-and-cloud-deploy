# Design: Academy configure

> **Later modified by** [`add-infra-academy-deploy-projects`](../add-infra-academy-deploy-projects/proposal.md) / [ADR 0014](../../../docs/adr/0014-deploy-projects-after-configure.md): `apply` / `configure-only` run `configure.yml` (Docker + Neo4j only). Portal / REST / Haystack first-compose is a later `action=deploy-projects` (`site.yml`). Missing REST/Haystack images do not fail apply.  
> **Later modified by** [`add-infra-bastion`](../add-infra-bastion/proposal.md) / [ADR 0021](../../../docs/adr/0021-maintenance-bastion-ssh.md): `stop` also `stop-instances` on `hr-bastion`; Ansible does not compose onto the bastion.

## Context

`ANSIBLE-PROCESS.md` and AWS study §8.2 define `apply` / `configure-only` as Terraform (if any) → `sync-secrets` → `sync-ssh-keys` → Ansible. `stop` pauses compute and both RDS. NAT Gateways cannot be stopped.

## Goals / Non-Goals

**Goals:**

- Fill `heavy-rental/{portal,rest,haystack,neo4j}` from Terraform outputs + Environment app secrets.
- After InService, write `private_key_pem` (**private** key) + `public_key` to `heavy-rental/ssh/*` and public keys via SSM. **Current:** also `heavy-rental/ssh/bastion`; hop private key **and** role private keys on `hr-bastion` (ADR 0021). App guests never get a private key.
- This delta composed all four ASGs. **Current:** apply / configure-only compose Neo4j only; portal / REST / Haystack wait for `deploy-projects` (banner). Portal `/api` → `REST_BASE_URL`. Haystack must not start Neo4j.
- `stop` sets four app ASGs desired=0 and stops both RDS. **Current:** also stops `hr-bastion` (banner).

**Non-Goals:**

- App CD, paid/OIDC, `tls_private_key` in Terraform, ELB health (ADR 0008 stays).
- Writing Vocareum AWS keys into Secrets Manager.
- `docker build` on the guests.

## Decisions

1. PEMs generated on the runner after InService (ADR 0011).
2. Ansible uses `amazon.aws.aws_ssm` (ADR 0012). Everyday path is not SSH.
3. Portal and Neo4j may use public `nginx` / `neo4j:5`. **Current:** apply / configure-only do not pull REST/Haystack images; `deploy-projects` fails without public GHCR or ECR tags (ADR 0014).
4. `stop` keeps app ASG `max=2` so the next apply can scale desired back to 2. **Current:** `stop-instances` on `hr-bastion`; next apply starts it (`aws_ec2_instance_state`).
5. Conflict order: OpenSpec → OpenSPDD → ADR → YAML / scripts / Ansible.

## Risks / Trade-offs

- NAT Gateways bill after `stop` and after session end.
- REST/Haystack first-compose needs a CI image; there is no in-repo Spring/Haystack Dockerfile.
- SSM plugin must be on the runner.
