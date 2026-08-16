# Delta for infra-academy-estate-vpc

## Purpose

The Academy estate is one VPC in `us-east-1` with three subnet tiers and a NAT **instance**.

## ADDED Requirements

### Requirement: Three-tier CIDRs
Terraform SHALL create a VPC `10.0.0.0/16` with public `10.0.0.0/24` + `10.0.1.0/24`, private-app `10.0.10.0/24` + `10.0.11.0/24`, and private-data `10.0.20.0/24` + `10.0.21.0/24` across two AZs.

#### Scenario: Data subnets have no public IPs
- GIVEN the estate is applied
- WHEN data subnets are described
- THEN `map_public_ip_on_launch` is false
- AND they have no Internet Gateway route

### Requirement: NAT instance, not NAT Gateway
Private app and data default routes SHALL target a `t3.nano` NAT **instance** ENI. The configuration SHALL NOT contain `aws_nat_gateway`.

#### Scenario: Private route uses the NAT instance
- GIVEN `action=apply` succeeds
- WHEN a private-app route table is described
- THEN `0.0.0.0/0` points at the NAT instance network interface
- AND no NAT Gateway exists in the VPC

### Requirement: S3 gateway endpoint
The VPC SHALL have an S3 gateway endpoint associated with the private route tables.

#### Scenario: S3 endpoint is present
- GIVEN the estate is applied
- THEN an `aws_vpc_endpoint` of type Gateway for S3 exists
- AND no Secrets Manager / SSM / ECR **interface** endpoints are required on this branch
