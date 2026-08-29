# Delta for infra-academy-stop

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-stop/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): `stop` also `stop-instances` on `hr-bastion`. App ASGs stay max=2.

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
