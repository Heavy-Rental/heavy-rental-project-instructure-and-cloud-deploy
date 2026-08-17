# Delta for infra-academy-estate-data

## Purpose

Academy has **two** PostgreSQL instances (REST SoR `heavy_rental` and Haystack) and **one** Neo4j. Two data subnets exist so RDS can have a subnet group — not one database per AZ.

## ADDED Requirements

### Requirement: Two single-AZ RDS instances in the data subnet group
Terraform SHALL create two PostgreSQL instances (`heavy-rental-academy` database `heavy_rental`, `heavy-rental-haystack-academy` database `haystack`) with `publicly_accessible = false`, `multi_az = false`, `deletion_protection = false`. The subnet group SHALL list both data subnets (AWS requires two AZs). Both instances SHALL set `availability_zone` to the first data subnet so they land in the **same** subnet.

#### Scenario: Two RDS after apply
- GIVEN `action=apply` succeeded
- WHEN `describe-db-instances` is called
- THEN both Heavy Rental instances exist
- AND neither is publicly accessible
- AND Multi-AZ is false on both
- AND both instances are in the same Availability Zone as `data[0]`

### Requirement: Master password from Environment, not the form
The RDS master password SHALL come from `TF_VAR_db_master_password` (GitHub Environment secret `SPRING_DATASOURCE_PASSWORD`). `action=apply` SHALL fail if that value is empty or the plan-only placeholder.

#### Scenario: Apply without DB password
- GIVEN Environment `academy` has no `SPRING_DATASOURCE_PASSWORD`
- WHEN the operator selects `action=apply`
- THEN the terraform job fails before `terraform apply`
- AND the password is not printed in logs

### Requirement: Stable Neo4j private IP
`asg-neo4j` SHALL attach a dedicated ENI in a data subnet so the private IP is a Terraform output for later `NEO4J_URI`.

#### Scenario: Bolt address is an output
- GIVEN `action=apply` succeeded
- WHEN `terraform output neo4j_private_ip` is read
- THEN it is a `10.0.20.x` or `10.0.21.x` address
- AND it matches the dedicated ENI
