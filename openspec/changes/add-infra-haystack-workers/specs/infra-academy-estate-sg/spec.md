# Delta for infra-academy-estate-sg (postgres_fdw)

## Purpose

Haystack RDS `postgres_fdw` opens `:5432` to SoR RDS. Both instances use `sg-rds`.

## MODIFIED Requirements

### Requirement: East-west contract
RDS `:5432` SHALL allow `sg-rest`, `sg-haystack`, and **`sg-rds`**. Egress SHALL include those three. `0.0.0.0/0` SHALL NOT be a source on 5432.

#### Scenario: RDS self pairing for FDW
- GIVEN the estate is applied
- WHEN `sg-rds` rules are listed
- THEN ingress TCP 5432 from `sg-rds` is present
- AND egress TCP 5432 to `sg-rds` is present
