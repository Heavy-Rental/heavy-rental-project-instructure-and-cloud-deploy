# ADR 0008: EC2 health on app ASGs until compose

- **Status:** Accepted
- **Date:** 2026-08-16
- **Branch:** `feat/infra-academy-estate` (`HR-161`)

## Context

The study wants ELB health so an unhealthy nginx/Tomcat/uvicorn node is replaced. This branch does not install those containers. ELB health on empty guests would terminate and replace instances until credits run out.

## Decision

`asg-portal`, `asg-rest`, and `asg-haystack` use `health_check_type = EC2`. They still register with `tg-portal` / `tg-rest` / `tg-haystack`. `asg-neo4j` stays EC2 health with scale-in protection.

**Current:** compose (`configure.yml` / `site.yml`) shipped. App ASGs **still** use EC2 health. ELB health replacement was not switched on.

ALB **target groups** have their own probes (they do not replace instances):

- `tg-rest`: `GET <instance-ip>:8080/actuator/health`, matcher **`200-299`** (2xx). Spring **401** on `/` is unhealthy.
- `tg-haystack`: `GET <instance-ip>:8000/health`, matcher **`200-299`** (2xx). `/docs` is not the ALB check.
- `tg-portal`: `GET <instance-ip>:80/`.

## Consequences

- `describe-auto-scaling-groups` shows InService after apply even with no containers.
- The public ALB returns 502 until nginx is composed — expected.
- Target group health may be unhealthy; that does not kill the instance.
