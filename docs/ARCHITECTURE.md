# Academy estate architecture

**Region:** `us-east-1` (first two available AZs, usually `us-east-1a` + `us-east-1b`).  
**IAM (academy):** every EC2 uses **`LabInstanceProfile`** → **`LabRole`**. No IAM create.  
**IAM (AWS_ACTUAL):** Terraform creates `hr-paid-{portal,rest,haystack,neo4j}` instance profiles. Auth is GitHub OIDC (`AWS_ROLE_TO_ASSUME`). Separate state bucket suffix `-actual` (S3 cannot use uppercase `AWS_ACTUAL`).

This is the live target for `terraform/academy/`. `postgres-haystack-sync` is a **container**, not a third RDS.

## Layout (two AZs, not two full copies)

```
                    Internet
                        |
                   +---------+
                   |   IGW   |
                   +---------+
                        |
     +------------------+------------------+
     |   public AZ-0         public AZ-1   |
     |  10.0.0.0/24         10.0.1.0/24    |
     |  NAT GW + EIP        NAT GW + EIP   |
     |  portal ALB + REST ALB (public)     |
     +------------------+------------------+
                        |
     +------------------+------------------+
     |   app AZ-0            app AZ-1      |
     |  10.0.10.0/24        10.0.11.0/24   |
     |  asg-portal x1       asg-portal x1  |  desired=2
     |  asg-rest x1         asg-rest x1    |
     |  asg-haystack x1     asg-haystack x1|
     |  internal Haystack ALB              |
     |  0.0.0.0/0 -> NAT GW in same AZ     |
     +------------------+------------------+
                        |
     +------------------+------------------+
     |   data AZ-0           data AZ-1     |
     |  10.0.20.0/24        10.0.21.0/24   |
     |  asg-neo4j x1        asg-neo4j x1   |  desired=2
     |  RDS SoR primary     RDS SoR standby|  Multi-AZ
     |  RDS Haystack pri.   RDS Haystack sb|
     |  internal Bolt NLB (spans both)     |
     +------------------+------------------+
```

```mermaid
flowchart TB
  browser[Browser] --> igw[IGW]
  igw --> albP[Public ALB portal :80]
  igw --> albR[Public ALB REST :8080]
  albP --> asgP0[asg-portal AZ-0]
  albP --> asgP1[asg-portal AZ-1]
  asgP0 --> albR
  asgP1 --> albR
  albR --> asgR0[asg-rest AZ-0]
  albR --> asgR1[asg-rest AZ-1]
  asgR0 --> albH[Internal ALB Haystack :8000]
  asgR1 --> albH
  albH --> asgH0[asg-haystack AZ-0]
  albH --> asgH1[asg-haystack AZ-1]
  asgR0 --> rdsSor[RDS heavy_rental Multi-AZ]
  asgR1 --> rdsSor
  asgH0 --> rdsHs[RDS haystack Multi-AZ]
  asgH1 --> rdsHs
  asgH0 --> nlbN[Internal NLB Bolt :7687]
  asgH1 --> nlbN
  nlbN --> n4j0[asg-neo4j AZ-0]
  nlbN --> n4j1[asg-neo4j AZ-1]
  asgP0 --> nat0[NAT GW AZ-0]
  asgR0 --> nat0
  asgH0 --> nat0
  n4j0 --> nat0
  asgP1 --> nat1[NAT GW AZ-1]
  asgR1 --> nat1
  asgH1 --> nat1
  n4j1 --> nat1
  nat0 --> igw
  nat1 --> igw
```

## Counts

| Role | How many | Redundancy |
| --- | --- | --- |
| Portal / REST / Haystack EC2 | 2 each (one per app AZ) | AZ loss keeps one guest behind the ALB. REST ALB is public :8080; guests stay private |
| Neo4j EC2 | 2 (one per data AZ) | AZ loss keeps one guest behind the Bolt NLB. **Not** a causal cluster |
| NAT | **2 Gateways** (one per public AZ) + EIP each | Same-AZ outbound for portal / REST / Haystack / Neo4j. Not an EC2 instance |
| RDS `heavy_rental` | 1 Multi-AZ | Primary + standby |
| RDS `haystack` | 1 Multi-AZ | Primary + standby |
| `postgres-haystack-sync` | 0 RDS | Worker on `asg-haystack`: `postgres:17` + `sync-from-primary.sh` (60s). Not a third RDS |
| `neo4j-populate` | 0 RDS | Same guest: `python:3.12-slim` + `populate_neo4j.py` (60s + compose `:8089`) |

**Guest count:** 8 ASG instances + **0** NAT EC2 = **8** EC2 (Vocareum default cap is 9).

## Traffic

Browser → public portal ALB → portal → **internet-facing REST ALB :8080** → REST → SoR RDS.  
Internet clients may also hit the REST ALB :8080 directly (`REST_BASE_URL`). `sync-secrets` sets `APP_CORS_ALLOWED_ORIGINS` to the portal origin and `http://<rest_alb_dns>:8080` ([`../specification/pipelines/infra-secrets.md`](../specification/pipelines/infra-secrets.md)).  
REST → internal Haystack ALB → Haystack → Haystack RDS + Bolt NLB → Neo4j.  
On `asg-haystack`, `postgres-haystack-sync` merges SoR RDS → Haystack RDS (`postgres_fdw`, `sg-rds` self :5432). `neo4j-populate` reads Haystack RDS and writes Bolt (`NEO4J_URI`). HTTP `:8089` is Compose DNS only ([ADR 0020](adr/0020-haystack-devcontainer-workers.md)).  
Private outbound HTTPS → the **NAT Gateway in the same AZ**. S3 via gateway endpoint (no NAT). If AZ-0 dies, AZ-1 guests keep outbound. NAT Gateways bill until `action=destroy`; session end and `action=stop` do not pause them.

## ALB / NLB health checks

Terraform target groups probe each **registered instance private IP**. Matcher **`200-299`** means **2xx only** (3xx/4xx/5xx stay unhealthy). ASGs still use `health_check_type = EC2` (ADR 0008): an unhealthy target does **not** replace the instance.

| Target group | Probe | Matcher | Notes |
| --- | --- | --- | --- |
| `tg-portal` | `http://<instance-ip>:80/` | `200-399` | 502 until nginx is composed |
| `tg-rest` | `http://<instance-ip>:8080/actuator/health` | **`200-299`** | Spring Security **401**s `GET /` — not this check |
| `tg-haystack` | `http://<instance-ip>:8000/health` | **`200-299`** | `GET /` is 404; `/docs` is OpenAPI, not the ALB check |
| `tg-neo4j` | TCP `<instance-ip>:7687` | TCP | Internal Bolt NLB |

`deploy-projects` / `site.yml` waits for REST `:8080/actuator/health` and Haystack `:8000/health` to return 2xx before the play succeeds.

## Terraform vs Ansible

**Terraform** (`terraform/academy/`) creates the architecture: VPC, two NAT Gateways, four ASGs, ALBs (portal :80 and REST :8080 internet-facing; Haystack internal), two Multi-AZ RDS, Bolt NLB, empty SM shells, and Monitor (CloudTrail + CloudWatch + S3 logs). Academy guests use **`LabInstanceProfile` → `LabRole`** (no IAM create). AWS_ACTUAL guests use Terraform `hr-paid-*` profiles.  
**Ansible** only configures guests that already exist: Docker, SM → `.env`, compose, portal `/api`. It does not create or destroy VPC/ASG/RDS.

## Monitor (apply)

| Signal | Where |
| --- | --- |
| API audit | CloudTrail `heavy-rental-academy` → observe S3 (`cloudtrail/`). **No** trail → CloudWatch Logs (Vocareum). |
| VPC accept/reject | Flow logs → same bucket (`vpc-flow/`). S3 destination — **not** LabRole (wrong trust). |
| ALB requests | Access logs on portal / REST / Haystack ALBs → `alb/` |
| Health | Dashboard `heavy-rental-academy`; alarms on ALB 5xx / unhealthy, RDS CPU / storage, ASG InService |
| Guest logs | Docker `awslogs` driver → `/heavy-rental/{portal,rest,haystack,neo4j}` (instance profile). No CloudWatch Agent. If LabRole cannot `PutLogEvents`, guests stay on `json-file` and `docker logs` over SSM. |

Optional Environment variable `ALARM_EMAIL` subscribes SNS topic `hr-academy-alarms` (confirm the AWS mail). Cost Explorer stays the Vocareum budget UI — not Terraform.

## Configure (Ansible)

`action=apply` runs Terraform first, then `sync-secrets` → `sync-ssh-keys` → Ansible **`configure.yml`** (Docker + Compose on all guests; compose **Neo4j only**). `action=configure-only` does **not** run Terraform apply; Ansible is the **same** playbook. Neither action pulls portal / REST / Haystack images.

`action=deploy-projects` is a **later** workflow run after apply or configure-only (ADR 0014). It is not a job at the end of apply. Preflight requires public GHCR or ECR tags, then Ansible **`site.yml`**. Day-to-day single-image rolls stay app CD.

`group_vars` does **not** hardcode GHCR paths. It looks up GitHub Environment variables `PORTAL_IMAGE` / `REST_IMAGE` / `HAYSTACK_IMAGE` on the Ansible controller (infra repo Environment `academy`).

| Role | Image | Notes |
| --- | --- | --- |
| Portal | Env `PORTAL_IMAGE` or stock `nginx` | `/api` → `REST_BASE_URL`. ECR tags get `docker login` on the guest. Public GHCR pulls with no login. |
| REST / Haystack | Env `REST_IMAGE` / `HAYSTACK_IMAGE` or Run `image_ref` | Fail if empty. Haystack compose has **no** `neo4j` service. Compose waits for REST `:8080/actuator/health` **2xx** and Haystack `:8000/health` **2xx**. |
| Neo4j | `neo4j:5` | `/data` on extra EBS |

Portal SM JSON includes `STRIPE_PUBLISHABLE_KEY` and `VITE_STRIPE_PUBLISHABLE_KEY` (same `pk_`). REST has `STRIPE_API_KEY` + webhook. Prefer a **new tag** on each redeploy (`compose up` does not `--pull always`). Haystack SM includes `SOURCE_*` (SoR) and `TARGET_*` (Haystack RDS) from infra `sync-secrets` (ADR 0013).

Portal-only redeploy: portal app CD in `heavy-rental-web-portal-pipeline/deploy-pipeline/` (same `guest_base` + `portal`, `--limit portal`, **no Terraform**). REST-only: `heavy-rental-rest-api/deploy-pipeline/`. Haystack-only: `haystack-fast-api-pipeline/deploy-pipeline/`.
