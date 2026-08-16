# ADR 0004: NAT instance, not NAT Gateway

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

Private app and data subnets need outbound HTTPS (SSM, ECR, yum, Secrets Manager). AWS NAT Gateway is simple but bills hourly and is a poor fit for a $50 Vocareum lab. The AWS study forbids NAT Gateway on Academy.

## Decision

Use a **`t3.nano` NAT instance** in a public subnet: source/dest check disabled, IP forwarding + MASQUERADE, `LabInstanceProfile` for SSM. Private route tables send `0.0.0.0/0` to that ENI. Add a free **S3 gateway** endpoint. Do not create `aws_nat_gateway`.

## Consequences

- Fifth instance (four ASGs + NAT) stays under the Vocareum cap of 9.
- Operator must treat the NAT host as a dependency for SSM and image pull.
- Throughput is limited (`t3.nano`). Acceptable for a class demo.
