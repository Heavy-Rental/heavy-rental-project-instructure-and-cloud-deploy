# ADR 0010: Two NAT Gateways, one per AZ

- **Status:** Accepted
- **Date:** 2026-08-17
- **Branch:** `HR-161-implement-aws-infrastructure-academy-by-building-resources`
- **Supersedes:** [0004](0004-nat-instance-not-gateway.md)

## Context

ADR 0004 used one `t3.nano` NAT **instance** in public AZ-0 so the lab stayed at 9 EC2 and Vocareum could stop that guest with the rest of the fleet. Portal (React), REST (Spring Boot), and Haystack already run `desired=2` across both app AZs, but their outbound HTTPS (SSM, ECR, yum, Secrets Manager) still crossed to AZ-0. Losing AZ-0 killed outbound for every private guest.

The operator accepted 24/7 NAT Gateway credit burn in exchange for same-AZ outbound.

## Decision

Create **two public NAT Gateways**, one in each public subnet, each with a VPC Elastic IP. Split private-app and private-data route tables **per AZ** so `0.0.0.0/0` targets the Gateway in that AZ. Keep the free S3 gateway endpoint on all four private tables.

Do **not** keep `aws_instance.nat`. Do **not** add a 9th EC2. Guest count is **8**.

`action=stop` cannot pause a NAT Gateway. Only `action=destroy` stops the charge. Vocareum session end does not stop Gateways.

## Consequences

- AZ-0 loss no longer takes down AZ-1 outbound.
- Two NAT Gateway hours + two EIPs bill until destroy, including after session end.
- Vocareum may reject `CreateNatGateway` / EIP. If apply fails, revert to the NAT instance (ADR 0004) rather than leaving a half-applied mix.
- Apply this graph on a **clean** estate (`action=destroy` first). In-place replace of the NAT instance plus shared route tables is the same detach class of failure as the old dedicated ENI.
