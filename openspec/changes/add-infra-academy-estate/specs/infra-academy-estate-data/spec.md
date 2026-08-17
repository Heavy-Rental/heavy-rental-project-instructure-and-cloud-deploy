# Delta for infra-academy-estate-data

## Purpose

Academy has **two Multi-AZ** PostgreSQL instances (REST SoR `heavy_rental` and Haystack) and **two** Neo4j guests behind an internal Bolt NLB.

## ADDED Requirements

### Requirement: Two Multi-AZ RDS instances in the data subnet group
Terraform SHALL create two PostgreSQL instances (`heavy-rental-academy` database `heavy_rental`, `heavy-rental-haystack-academy` database `haystack`) with `publicly_accessible = false`, `multi_az = true`, `deletion_protection = false`. The subnet group SHALL list both data subnets. Instances SHALL NOT pin `availability_zone`.

#### Scenario: Two Multi-AZ RDS after apply
- GIVEN `action=apply` succeeded
- WHEN `describe-db-instances` is called
- THEN both Heavy Rental instances exist
- AND neither is publicly accessible
- AND Multi-AZ is true on both

### Requirement: Master password from Environment, not the form
The RDS master password SHALL come from `TF_VAR_db_master_password` (GitHub Environment secret `SPRING_DATASOURCE_PASSWORD`). `action=apply` SHALL fail if that value is empty or the plan-only placeholder.

#### Scenario: Apply without DB password
- GIVEN Environment `academy` has no `SPRING_DATASOURCE_PASSWORD`
- WHEN the operator selects `action=apply`
- THEN the terraform job fails before `terraform apply`
- AND the password is not printed in logs

### Requirement: Stable Neo4j Bolt URI
`asg-neo4j` SHALL run two guests (one per data AZ). Bolt SHALL be an internal NLB. `terraform output neo4j_uri` SHALL be `bolt://<nlb-dns>:7687`.

#### Scenario: Bolt address is an output
- GIVEN `action=apply` succeeded
- WHEN `terraform output neo4j_uri` is read
- THEN it is `bolt://` plus the internal NLB DNS and port `7687`
