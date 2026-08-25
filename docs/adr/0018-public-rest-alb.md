# ADR 0018: REST ALB is internet-facing

- **Status:** Accepted
- **Date:** 2026-08-19
- **Change:** `add-infra-paid-pipeline`
- **Related:** [0010](0010-two-nat-gateways.md), [0013](0013-haystack-source-target-in-sync-secrets.md)
- **Diverges from:** AWS study §6 / §6P (“REST internal”; “no public 8080”)

## Context

`hr-alb-rest` was internal in the app subnets. The portal reached Spring only via that private DNS (`REST_BASE_URL`). Direct clients, mobile, and Stripe webhooks could not hit Tomcat. REST **instances** already had NAT egress on :80/:443.

Internet-facing ALBs must use public subnets. Changing `internal` or subnets replaces the ALB (new DNS).

Feasibility §6P keeps REST on an **internal** ALB and forbids public 8080. Operators need the REST API reachable from the internet on this estate. HTTPS/ACM is a later change.

## Alternatives

1. **Keep the internal REST ALB.** Rejected: only the portal can call Spring, and only from inside the VPC.
2. **Add :8080 on the public portal ALB.** Rejected: mixes SPA and Tomcat on one balancer; portal SG contract stays :80.
3. **New internet-facing REST ALB on :8080 in public subnets.** Chosen. Listener shape (`http://<dns>:8080`) stays valid for `REST_BASE_URL`.

## Decision

1. `hr-alb-rest` is **internet-facing** in the **public** subnets (same AZs as the portal ALB).
2. Listener stays **TCP 8080** → `tg-rest` :8080 so `REST_BASE_URL=http://<dns>:8080` does not change shape.
3. `sg-alb-rest` allows 8080 from `0.0.0.0/0`. Portal SG → REST ALB :8080 remains.
4. `asg-rest` stays in **private app** subnets with **no public IP**. Outbound is still the same-AZ NAT Gateway.
5. Haystack ALB, Bolt NLB, and RDS stay internal / non-public. Portal ALB stays the only public :80.
6. `sync-secrets` sets `APP_CORS_ALLOWED_ORIGINS` to `http://<portal_alb_dns>,http://<rest_alb_dns>:8080` so a browser may call REST directly as well as via portal `/api`.

## Consequences

- Apply + `sync-secrets` rewrites `REST_BASE_URL` and CORS after the ALB replacement (new DNS).
- Portal nginx `/api` still proxies; hairpin from private portal guests to the public REST DNS uses NAT.
- HTTP only (no ACM in this change). Stripe webhooks that require HTTPS still need a later listener.
- This is a recorded divergence from feasibility §6P. The study is not edited here.
