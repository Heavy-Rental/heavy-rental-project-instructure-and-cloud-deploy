# Delta for infra-academy-estate-sg

> **Later modified by** [`add-infra-paid-pipeline`](../../../add-infra-paid-pipeline/specs/infra-academy-estate-sg/spec.md) / [ADR 0018](../../../../../docs/adr/0018-public-rest-alb.md): `sg-alb-rest` allows TCP 8080 from `0.0.0.0/0`. Portal ALB (`sg-alb-public`) stays the only public TCP 80. Haystack / RDS / Bolt stay private.  
> **Later modified by** [`add-infra-haystack-workers`](../../../add-infra-haystack-workers/specs/infra-academy-estate-sg/spec.md) / [ADR 0020](../../../../../docs/adr/0020-haystack-devcontainer-workers.md): `sg-rds` allows TCP 5432 to/from itself for Haystack RDS `postgres_fdw`.

## Purpose

Security groups implement AWS study §6.2. This delta made the public portal ALB the only internet-facing listener; REST public :8080 is the later change above.

## ADDED Requirements

### Requirement: Public ALB is portal :80 only
`sg-alb-public` SHALL allow ingress TCP 80 from `0.0.0.0/0` and SHALL NOT allow 8080, 8000, 5432, or 7687 from the internet.

#### Scenario: REST is not on the public ALB
- GIVEN the estate is applied
- WHEN security-group rules for the public ALB are listed
- THEN there is no ingress 8080 or 8000 from `0.0.0.0/0`

### Requirement: East-west contract
Terraform SHALL encode:

- portal :80 from `sg-alb-public`
- REST :8080 from `sg-alb-rest`; egress 5432 to `sg-rds` and 8000 to `sg-alb-haystack`; no egress 7687
- Haystack :8000 from `sg-alb-haystack`; egress 5432 to `sg-rds` and 7687 to `sg-neo4j`
- RDS :5432 from `sg-rest` and `sg-haystack` only
- Neo4j :7687 from `sg-haystack` only

#### Scenario: Portal cannot reach RDS
- GIVEN the estate is applied
- WHEN `sg-rds` ingress is listed
- THEN `sg-portal` is not a source
- AND `0.0.0.0/0` is not a source on 5432
