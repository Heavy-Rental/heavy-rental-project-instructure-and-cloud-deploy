# Delta for infra-academy-estate-sg (public REST ALB)

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
- REST :8080 from the internet (`0.0.0.0/0`) and from `sg-portal` (via `sg-alb-rest`); egress 5432 to `sg-rds` and 8000 to `sg-alb-haystack`; no egress 7687
- Haystack :8000 from `sg-alb-haystack`; egress 5432 to `sg-rds` and 7687 to `sg-neo4j`
- RDS :5432 from `sg-rest` and `sg-haystack` only
- Neo4j :7687 from `sg-haystack` only

#### Scenario: Portal cannot reach RDS
- GIVEN the estate is applied
- WHEN `sg-rds` ingress is listed
- THEN `sg-portal` is not a source
- AND `0.0.0.0/0` is not a source on 5432

#### Scenario: REST ALB still accepts portal
- GIVEN the estate is applied
- WHEN `sg-alb-rest` ingress is listed
- THEN TCP 8080 from `sg-portal` is present
- AND TCP 8080 from `0.0.0.0/0` is present
