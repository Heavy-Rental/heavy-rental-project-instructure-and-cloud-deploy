# Delta for infra-academy-estate-vpc

## Purpose

The Academy estate is one VPC in `us-east-1` with three subnet tiers and **two NAT Gateways** (one per public AZ).

## ADDED Requirements

### Requirement: Three-tier CIDRs
Terraform SHALL create a VPC `10.0.0.0/16` with public `10.0.0.0/24` + `10.0.1.0/24`, private-app `10.0.10.0/24` + `10.0.11.0/24`, and private-data `10.0.20.0/24` + `10.0.21.0/24` across two AZs.

#### Scenario: Data subnets have no public IPs
- GIVEN the estate is applied
- WHEN data subnets are described
- THEN `map_public_ip_on_launch` is false
- AND they have no Internet Gateway route

### Requirement: Two NAT Gateways, one per AZ
Terraform SHALL create two `aws_nat_gateway` resources (one in each public subnet) each with a VPC Elastic IP. Each private-app and private-data subnet SHALL use a dedicated route table whose `0.0.0.0/0` target is the NAT Gateway in the **same** AZ. The configuration SHALL NOT contain an `aws_instance` used as NAT.

#### Scenario: Private route uses the same-AZ NAT Gateway
- GIVEN `action=apply` succeeds
- WHEN a private-app route table in AZ-n is described
- THEN `0.0.0.0/0` points at the NAT Gateway in public AZ-n
- AND no NAT instance exists in the VPC

### Requirement: S3 gateway endpoint
The VPC SHALL have an S3 gateway endpoint associated with the private route tables.

#### Scenario: S3 endpoint is present
- GIVEN the estate is applied
- THEN an `aws_vpc_endpoint` of type Gateway for S3 exists
- AND no Secrets Manager / SSM / ECR **interface** endpoints are required on this branch
