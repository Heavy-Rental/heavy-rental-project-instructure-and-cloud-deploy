# Spec: infra-estate-rest-alb

## Purpose

The Spring Boot REST ALB is reachable from the internet on :8080. REST guests keep NAT egress. Haystack and the data plane stay private. Portal ALB stays the only public :80.

## ADDED Requirements

### Requirement: REST ALB is internet-facing
`hr-alb-rest` SHALL have `internal = false` and SHALL be attached to the public subnets (same subnets as the portal ALB). It SHALL listen on TCP 8080 and forward to `tg-rest` :8080. `REST_BASE_URL` SHALL remain `http://<rest_alb_dns>:8080`. Changing scheme or subnets replaces the ALB; `sync-secrets` SHALL run after apply so Secrets Manager receives the new DNS.

#### Scenario: REST ALB scheme
- GIVEN a successful estate apply
- WHEN `hr-alb-rest` is described
- THEN `Scheme` is `internet-facing`
- AND the ALB subnets are the public subnets
- AND a listener exists on port 8080

#### Scenario: REST_BASE_URL shape is unchanged
- GIVEN `sync-secrets` succeeded after apply
- WHEN `heavy-rental/portal` is read
- THEN `REST_BASE_URL` is `http://` plus the REST ALB DNS plus `:8080`

### Requirement: Internet may reach REST :8080
`sg-alb-rest` SHALL allow ingress TCP 8080 from `0.0.0.0/0`. It SHALL NOT allow 8000, 5432, or 7687 from the internet. Portal SG → REST ALB :8080 SHALL remain. Portal ALB (`sg-alb-public`) SHALL remain the only public TCP 80.

#### Scenario: Internet to REST ALB
- GIVEN the estate is applied
- WHEN security-group rules for the REST ALB are listed
- THEN TCP 8080 from `0.0.0.0/0` is present
- AND 8000 from `0.0.0.0/0` is not present

#### Scenario: Portal ALB stays public :80 only
- GIVEN the estate is applied
- WHEN security-group rules for `sg-alb-public` are listed
- THEN TCP 80 from `0.0.0.0/0` is present
- AND TCP 8080 from `0.0.0.0/0` is not present on that group

### Requirement: REST guests still egress via NAT
`asg-rest` SHALL remain in the private app subnets. Outbound HTTPS/HTTP to `0.0.0.0/0` SHALL stay on the REST instance SG (NAT Gateway). REST SHALL NOT receive a public IP. Private portal guests MAY reach the public REST DNS via NAT (hairpin).

#### Scenario: REST instance is not public
- GIVEN the estate is applied
- WHEN an `asg-rest` instance is described
- THEN it has no public IP
- AND its subnet is an app subnet (`10.0.10.0/24` or `10.0.11.0/24`)

### Requirement: CORS includes the public REST origin
`sync-secrets` SHALL set `APP_CORS_ALLOWED_ORIGINS` to the public portal origin and `http://<rest_alb_dns>:8080` so a browser can call the REST ALB directly as well as via portal `/api`.

#### Scenario: REST CORS includes both ALBs
- GIVEN `sync-secrets` succeeded
- WHEN `heavy-rental/rest` is read
- THEN `APP_CORS_ALLOWED_ORIGINS` contains the portal ALB `http://` origin
- AND it contains `http://` plus the REST ALB DNS plus `:8080`

### Requirement: Haystack stays internal
`hr-alb-haystack` SHALL remain internal. Bolt NLB and RDS SHALL remain non-public.

#### Scenario: Haystack ALB scheme
- GIVEN the estate is applied
- WHEN `hr-alb-haystack` is described
- THEN `Scheme` is `internal`
