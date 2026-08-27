# Design: Academy configure

> **Later modified by** [`add-infra-academy-deploy-projects`](../add-infra-academy-deploy-projects/proposal.md) / [ADR 0014](../../../docs/adr/0014-deploy-projects-after-configure.md): `apply` / `configure-only` run `configure.yml` (Docker + Neo4j only). Portal / REST / Haystack first-compose is a later `action=deploy-projects` (`site.yml`). Ansible spec already matches.

## Context

`ANSIBLE-PROCESS.md` and AWS study §8.2 define `apply` / `configure-only` as Terraform (if any) → `sync-secrets` → `sync-ssh-keys` → Ansible. `stop` pauses compute and both RDS. NAT Gateways cannot be stopped.

## Goals / Non-Goals

**Goals:**

- Fill `heavy-rental/{portal,rest,haystack,neo4j}` from Terraform outputs + Environment app secrets.
- After InService, write PEMs to `heavy-rental/ssh/*` and public keys via SSM.
- First compose on all four ASGs over SSM. Portal `/api` → `REST_BASE_URL`. Haystack must not start Neo4j.
- `stop` sets four ASGs desired=0 and stops both RDS.

**Non-Goals:**

- App CD, paid/OIDC, `tls_private_key` in Terraform, ELB health (ADR 0008 stays).
- Writing Vocareum AWS keys into Secrets Manager.
- `docker build` on the guests.

## Decisions

1. PEMs generated on the runner after InService (ADR 0011).
2. Ansible uses `amazon.aws.aws_ssm` (ADR 0012). Everyday path is not SSH.
3. Portal and Neo4j may use public `nginx` / `neo4j:5`. REST and Haystack fail without an operator image (`image_http_url` / `IMAGE_HTTP_URL` / `image_ref` / ECR).
4. `stop` keeps `max=2` so the next configure can scale desired back to 2 without Terraform.
5. Conflict order: OpenSpec → OpenSPDD → ADR → YAML / scripts / Ansible.

## Risks / Trade-offs

- NAT Gateways bill after `stop` and after session end.
- REST/Haystack first-compose needs a CI image; there is no in-repo Spring/Haystack Dockerfile.
- SSM plugin must be on the runner.
