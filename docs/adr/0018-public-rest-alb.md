# ADR 0018: REST ALB is internet-facing

- **Status:** Accepted
- **Date:** 2026-08-19
- **Change:** `add-infra-paid-pipeline`
- **Related:** [0010](0010-two-nat-gateways.md) (same-AZ outbound NAT; portal `/api` hairpin), [0013](0013-haystack-source-target-in-sync-secrets.md)
- **Amended:** 2026-08-30 — CORS allow-list is for **direct** REST ALB browser calls. Portal nginx `/api` omits `Origin` so Spring CorsFilter does not treat the hairpin as CORS.
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
2. Listener stays **TCP 8080** → `tg-rest` :8080 so `REST_BASE_URL=http://<dns>:8080` does not change shape. **Current health:** `tg-rest` waits for `GET <instance-ip>:8080/actuator/health` matcher **`200-299`** (2xx). `GET /` is Spring 401 and is not healthy.
3. `sg-alb-rest` allows 8080 from `0.0.0.0/0`. Portal SG → REST ALB :8080 remains (SG-to-SG). `sg-portal` also egresses TCP 8080 to `0.0.0.0/0` so private guests can hairpin to the public REST DNS via NAT. SG-to-SG alone does not match the public ALB IPs; without the CIDR rule, nginx `/api` waits for the default 60s proxy timeout and returns **504**.
4. `asg-rest` stays in **private app** subnets with **no public IP**. Outbound is still the same-AZ NAT Gateway.
5. Haystack ALB, Bolt NLB, and RDS stay internal / non-public. Portal ALB stays the only public :80.
6. `sync-secrets` sets `APP_CORS_ALLOWED_ORIGINS` to `http://<portal_alb_dns>,http://<rest_alb_dns>:8080` so a **browser may call the public REST ALB `:8080` directly**. The SPA does **not** use that path: it calls same-origin `/api` on the portal ALB.
7. Portal nginx `location /api/` `proxy_pass`es `REST_BASE_URL` with **no trailing URI** (`Host $proxy_host`) and **omits `Origin`** (`proxy_set_header Origin ""`). `fetch()` still sends `Origin`; if nginx forwarded it, Spring CorsFilter would 403 `Invalid CORS request` unless the address bar exactly matched the allow-list. The portal login helper then POSTs that 403 body as the interim JWT and `/api/auth/login` returns **401**. Omitting `Origin` keeps the hairpin off the CORS allow-list. Infra `site.yml` and portal app CD MUST keep the same nginx snippet.

## Consequences

- Apply + `sync-secrets` rewrites `REST_BASE_URL` and CORS after the ALB replacement (new DNS). Direct REST ALB callers need the new origin; portal `/api` does not (Origin is omitted).
- Portal nginx `/api` still proxies; hairpin from private portal guests to the public REST DNS uses NAT. That path needs `sg-portal` egress TCP 8080 to `0.0.0.0/0` in addition to `sg-alb-rest`. Redeploy portal after changing the nginx snippet (`configure-only` or `deploy-projects`).
- HTTP only (no ACM in this change). Stripe webhooks that require HTTPS still need a later listener.
- This is a recorded divergence from feasibility §6P. The study is not edited here.
