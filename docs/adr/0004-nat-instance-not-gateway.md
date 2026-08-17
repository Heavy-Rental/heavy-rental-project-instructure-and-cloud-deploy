# ADR 0004: NAT instance, not NAT Gateway

- **Status:** Superseded by [0010](0010-two-nat-gateways.md)
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

Private app and data subnets need outbound HTTPS (SSM, ECR, yum, Secrets Manager). AWS NAT Gateway is simple but bills hourly and is a poor fit for a $50 Vocareum lab. The AWS study forbids NAT Gateway on Academy.

## Decision

Use **one `t3.nano` NAT instance** in public AZ-0: source/dest check disabled, IP forwarding + MASQUERADE, `LabInstanceProfile` for SSM. Both private app/data route tables send `0.0.0.0/0` to that ENI (cross-AZ). Add a free **S3 gateway** endpoint. Do not create `aws_nat_gateway`.

A second NAT would make 10 EC2 and break the Vocareum default cap of **9**. App/Neo4j stay at desired=2 instead.

## Consequences

- If the NAT or public AZ-0 dies, **all** private outbound (SSM, ECR, yum) fails.
- Instance count: 8 ASG guests + 1 NAT = **9**.
- Throughput is limited (`t3.nano`). Acceptable for a class demo.
