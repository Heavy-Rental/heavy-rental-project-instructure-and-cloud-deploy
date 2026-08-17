# Delta for infra-academy-stop

## Purpose

`action=stop` pauses compute and both RDS. It is not destroy.

## ADDED Requirements

### Requirement: Pause ASGs and both RDS
`action=stop` SHALL set `asg-portal`, `asg-rest`, `asg-haystack`, and `asg-neo4j` desired=0 (min=0, max remains 2) and call `rds stop-db-instance` on both Academy identifiers.

#### Scenario: Gateways stay
- GIVEN `action=stop` succeeds
- THEN no NAT Gateway, EIP, ALB, NLB, or VPC is deleted
- AND the job summary states NAT Gateways still bill
- AND Ansible does not run

#### Scenario: Already stopped RDS
- GIVEN an RDS instance is already stopped
- WHEN `stop` runs
- THEN the job still succeeds
