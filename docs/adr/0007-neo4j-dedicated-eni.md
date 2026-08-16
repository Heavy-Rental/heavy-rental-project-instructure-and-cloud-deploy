# ADR 0007: Dedicated ENI for asg-neo4j

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

`sync-secrets` needs `NEO4J_URI=bolt://<private-ip>:7687`. An Auto Scaling group does not expose a stable private IP as a first-class Terraform attribute. Neo4j is `max=1` and lives in one data subnet.

## Decision

Create an `aws_network_interface` in a data subnet and attach it as the only NIC on the Neo4j launch template. Output `neo4j_private_ip` from that ENI.

## Consequences

- Bolt address is known at apply time without a `data.aws_instances` race.
- The graph host is pinned to one AZ (already required by `max=1`).
- Replacement instances reuse the same IP if the ENI `delete_on_termination` is false.
- `asg-neo4j` must **not** set `vpc_zone_identifier`. AWS rejects a launch template that names a network interface ID **and** an ASG subnet.
