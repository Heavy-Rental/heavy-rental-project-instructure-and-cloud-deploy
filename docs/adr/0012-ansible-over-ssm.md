# ADR 0012: Ansible over SSM, not SSH

- **Status:** Accepted
- **Date:** 2026-08-17
- **Branch:** `HR-162-implement-aws-infrastructure-configuration-using-ansible-compose`

## Context

Portal, REST, Haystack, and Neo4j guests have no public IPs. Opening `:22` from `0.0.0.0/0` is forbidden. Vocareum documents LabRole + Session Manager.

## Decision

Ansible uses `amazon.aws.aws_ssm` (plugin moved out of `community.aws`). Collection **11.3.0+** imports `ansible.module_utils.common.text.converters`, not deprecated `_text`. Inventory hosts are instance ids. The runner installs the Session Manager plugin. SSH PEMs (ADR 0011) are break-glass only and are never the everyday connection. Break-glass SSH to private guests goes through `hr-bastion` (ADR 0021), not `:22` from `0.0.0.0/0` on app SGs.

## Consequences

- Guests need outbound to SSM (`ssm` / `ssmmessages` / `ec2messages`) via the same-AZ NAT Gateway.
- RDS is not in inventory (no guest OS).
- App CD later uses the same connection for one group.
