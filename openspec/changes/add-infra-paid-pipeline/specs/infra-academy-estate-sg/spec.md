# Delta for infra-academy-estate-sg (public REST ALB)

> **Later modified by** [`add-infra-haystack-workers`](../../../add-infra-haystack-workers/specs/infra-academy-estate-sg/spec.md) / [ADR 0020](../../../../../docs/adr/0020-haystack-devcontainer-workers.md): `sg-rds` also pairs with itself on TCP 5432 for Haystack RDS `postgres_fdw`.

## Purpose

Security groups implement AWS study §6.2 with ADR 0018: public ALBs are the portal on :80 and REST on :8080. Haystack, RDS, and Bolt stay off the internet.

## MODIFIED Requirements

### Requirement: Public ALBs are portal :80 and REST :8080
`sg-alb-public` SHALL allow ingress TCP 80 from `0.0.0.0/0` and SHALL NOT allow 8080, 8000, 5432, or 7687 from the internet. `sg-alb-rest` SHALL allow ingress TCP 8080 from `0.0.0.0/0` and SHALL NOT allow 8000, 5432, or 7687 from the internet. This requirement **replaces** “Public ALB is portal :80 only”.

#### Scenario: REST is on its own public ALB
- GIVEN the estate is applied
- WHEN security-group rules for the public portal ALB are listed
- THEN there is no ingress 8080 or 8000 from `0.0.0.0/0`
- AND the REST ALB security group allows 8080 from `0.0.0.0/0`

#### Scenario: Haystack is not on a public ALB
- GIVEN the estate is applied
- WHEN security-group rules for the Haystack ALB are listed
- THEN there is no ingress 8000 from `0.0.0.0/0`

### Requirement: East-west contract
Terraform SHALL encode:

- portal :80 from `sg-alb-public`
- REST :8080 from the internet (`0.0.0.0/0`) and from `sg-portal` (via `sg-alb-rest`); instance SG ingress TCP 8080 from `sg-alb-rest` and egress TCP 8080 to `sg-alb-rest`; ingress TCP 5432 from `sg-rds`; egress 5432 to `sg-rds`; ingress and egress TCP 8000 with `sg-alb-haystack`; no egress 7687; no instance-SG pairing with `sg-portal` or `sg-haystack`
- Haystack ALB :8000 from `sg-rest` and from `sg-alb-haystack`; egress TCP 8000 to `sg-rest`, `sg-alb-haystack`, and `sg-haystack`; not public
- Haystack :8000 from `sg-alb-haystack`; ingress and egress TCP 5432 with `sg-rds`; ingress and egress TCP 7687 and 7474 with `sg-neo4j`
- RDS :5432 from `sg-rest`, `sg-haystack`, and `sg-rds` (Haystack RDS `postgres_fdw` to SoR); egress 5432 to `sg-rest`, `sg-haystack`, and `sg-rds`
- Neo4j :7687 from `sg-haystack` (and Bolt NLB / VPC CIDR); egress TCP 7687 and 7474 to `sg-haystack`

#### Scenario: Portal cannot reach RDS
- GIVEN the estate is applied
- WHEN `sg-rds` ingress is listed
- THEN `sg-portal` is not a source
- AND `0.0.0.0/0` is not a source on 5432

#### Scenario: REST and RDS pair on :5432 by security-group id
- GIVEN the estate is applied
- WHEN `sg-rest` and `sg-rds` rules are listed
- THEN `sg-rest` allows ingress TCP 5432 from `sg-rds` and egress TCP 5432 to `sg-rds`
- AND `sg-rds` allows ingress TCP 5432 from `sg-rest` and egress TCP 5432 to `sg-rest`
- AND neither rule uses `0.0.0.0/0` on 5432

#### Scenario: REST ALB still accepts portal
- GIVEN the estate is applied
- WHEN `sg-alb-rest` ingress is listed
- THEN TCP 8080 from `sg-portal` is present
- AND TCP 8080 from `0.0.0.0/0` is present

#### Scenario: REST pairs with REST ALB on :8080 by security-group id
- GIVEN the estate is applied
- WHEN `sg-rest` rules are listed
- THEN ingress TCP 8080 from `sg-alb-rest` is present
- AND egress TCP 8080 to `sg-alb-rest` is present
- AND neither rule uses `0.0.0.0/0` on 8080
- AND `sg-portal` is not a source or destination on `sg-rest`

#### Scenario: REST pairs with Haystack ALB on :8000 by security-group id
- GIVEN the estate is applied
- WHEN `sg-rest` and `sg-alb-haystack` rules are listed
- THEN `sg-rest` allows ingress TCP 8000 from `sg-alb-haystack` and egress TCP 8000 to `sg-alb-haystack`
- AND `sg-alb-haystack` allows ingress TCP 8000 from `sg-rest` and egress TCP 8000 to `sg-rest`
- AND `sg-alb-haystack` allows ingress TCP 8000 from `sg-alb-haystack` and egress TCP 8000 to `sg-alb-haystack`
- AND `sg-haystack` is not a source or destination on `sg-rest`
- AND `0.0.0.0/0` is not a source on 8000

#### Scenario: Haystack pairs with RDS on :5432 by security-group id
- GIVEN the estate is applied
- WHEN `sg-haystack` and `sg-rds` rules are listed
- THEN `sg-haystack` allows ingress TCP 5432 from `sg-rds` and egress TCP 5432 to `sg-rds`
- AND `sg-rds` allows ingress TCP 5432 from `sg-haystack` and egress TCP 5432 to `sg-haystack`
- AND `sg-rds` allows ingress TCP 5432 from `sg-rds` and egress TCP 5432 to `sg-rds`
- AND neither rule uses `0.0.0.0/0` on 5432

#### Scenario: Haystack pairs with Neo4j on :7687 and :7474 by security-group id
- GIVEN the estate is applied
- WHEN `sg-haystack` and `sg-neo4j` rules are listed
- THEN `sg-haystack` allows ingress and egress TCP 7687 and 7474 with `sg-neo4j`
- AND `sg-neo4j` allows ingress and egress TCP 7687 and 7474 with `sg-haystack`
- AND `sg-neo4j` still allows Bolt :7687 from the VPC CIDR
- AND neither 7687 nor 7474 uses `0.0.0.0/0`
