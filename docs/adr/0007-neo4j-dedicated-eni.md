# ADR 0007: Two Neo4j guests + internal Bolt NLB

- **Status:** Accepted
- **Date:** 2026-08-17
- **Branch:** `feat/infra-academy-estate` (`HR-161`)
- **Supersedes:** dedicated single ENI (`max=1`)

## Context

Haystack needs one `NEO4J_URI`. Operators asked for a Neo4j copy in each of the two `us-east-1` AZs. A single dedicated ENI cannot attach to two instances, and an ASG cannot combine `network_interface_id` with subnets.

## Decision

`asg-neo4j` is **min=2 desired=2 max=2** across both data subnets. Bolt is reached through an **internal NLB** (`hr-nlb-neo4j`, TCP 7687). Output `neo4j_uri = bolt://<nlb-dns>:7687`.

No dedicated ENI. Community Edition is still not a causal cluster: both guests can accept Bolt; graph state is not automatically replicated. Ansible/populate (branch 3) must treat this as two independent copies or a later clustering choice.

## Consequences

- One AZ loss still leaves a Neo4j guest and an NLB node.
- `NEO4J_URI` is stable (NLB DNS), not a private IP.
- Two `t3.large` guests use more credits than `max=1`.
