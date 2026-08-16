# Delta for infra-academy-estate-data

## Purpose

Academy has **one** RDS and **one** Neo4j. Two data subnets exist so RDS can have a subnet group — not one database per AZ.

## ADDED Requirements

### Requirement: Single-AZ RDS in the data subnet group
Terraform SHALL create one PostgreSQL instance with `publicly_accessible = false`, `multi_az = false`, `deletion_protection = false`, in a subnet group that lists **both** data subnets.

#### Scenario: One RDS after apply
- GIVEN `action=apply` succeeded
- WHEN `describe-db-instances` is called
- THEN exactly one Heavy Rental instance exists
- AND it is not publicly accessible
- AND Multi-AZ is false

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
