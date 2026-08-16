# ADR 0008: EC2 health on app ASGs until compose

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

The study wants ELB health so an unhealthy nginx/Tomcat/uvicorn node is replaced. This branch does not install those containers. ELB health on empty guests would terminate and replace instances until credits run out.

## Decision

`asg-portal`, `asg-rest`, and `asg-haystack` use `health_check_type = EC2`. They still register with `tg-portal` / `tg-rest` / `tg-haystack`. `asg-neo4j` stays EC2 health with scale-in protection. Branch 3 may switch app ASGs to ELB health after compose.

## Consequences

- `describe-auto-scaling-groups` shows InService after apply even with no containers.
- The public ALB returns 502 until nginx is composed — expected.
- Target group health may be unhealthy; that does not kill the instance.
