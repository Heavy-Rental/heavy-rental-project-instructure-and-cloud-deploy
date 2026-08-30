# Academy infra CD

**Authoring tree:** this repo  
**Trigger:** `workflow_dispatch` on `.github/workflows/aws-infra-academy.yml`, Environment `academy` (Vocareum keys on the runner; EC2 uses `LabRole`). Paid: [`infra-paid.md`](infra-paid.md).

## Split of work

| Tool | Owns |
| --- | --- |
| **Terraform** | Architecture and cloud **resources**: VPC, subnets, IGW, two NAT Gateways, four app ASGs + LTs, **`hr-bastion`** (single EC2), public portal ALB, **internet-facing REST ALB :8080**, internal Haystack ALB, Bolt NLB, two Multi-AZ RDS, SM **shells**, S3 state, CloudTrail (S3), VPC flow logs (S3), ALB access logs, CloudWatch alarms + dashboard. Guests use **LabRole** / `LabInstanceProfile` only |
| **Ansible** | Guest **configuration** only: Docker/Compose, map SM → `.env`, pull/load a CI image, compose, portal nginx `/api`, RDS *logical* grants/extensions. `guest_base` probes `logs:CreateLogStream` and may set Docker Engine `awslogs` (not ECS `awslogs-stream-prefix`); otherwise `json-file`. **No** `terraform apply`, no create-ASG, no create-RDS |

`sync-secrets` and `sync-ssh-keys` are shell wrappers (not Terraform). They write JSON / SSH key material into shells Terraform already created. `private_key_pem` is the **private** OpenSSH key (not the public `.pub`). Bastion gets hop + role private keys; app guests get public keys only.

## Actions

```
workflow_dispatch (Environment academy)
      │
      ├── bootstrap         Terraform: state bucket only
      ├── plan              Import leftovers → Terraform show estate (no apply)
      ├── apply             Import leftovers → Terraform estate → sync-secrets → sync-ssh-keys → Ansible configure.yml
      ├── configure-only    No Terraform apply. sync-secrets + PEMs → same Ansible configure.yml
      ├── deploy-projects   Later run after apply or configure-only. Preflight images → site.yml
      ├── stop              App ASG desired=0 + stop hr-bastion + stop both RDS. NAT Gateways still bill
      └── destroy           Import leftovers → terraform destroy → sweep orphans. Keeps state bucket
```

| Action | Creates AWS architecture? | Configures guests? |
| --- | --- | --- |
| `bootstrap` / `plan` / `destroy` | Terraform only | No |
| `apply` | Yes | Yes — Docker/Compose + Neo4j only (`configure.yml`) |
| `configure-only` | No | Same as apply Ansible (`configure.yml`) |
| `deploy-projects` | No | Yes — `site.yml` (portal + REST + Haystack + Neo4j + `rds_logical`) |
| `stop` | No (pauses compute/RDS) | No compose |

`configure-only` does **not** replace portal / REST / Haystack images. `deploy-projects` is the infra first-compose (later run). Day-to-day rolls are app CD.

## Image variables (infra Environment `academy`)

`ansible/inventory/group_vars/all.yml` reads the **runner** environment. Infra CD maps GitHub Environment **variables** (not secrets) onto those names. They are separate from the same names on the three app repos.

| GitHub variable | Ansible var | Empty means |
| --- | --- | --- |
| `PORTAL_IMAGE` | `portal_image` | stock `nginx` |
| `REST_IMAGE` | `rest_image` | Run `image_ref` (`IMAGE_REF`), else empty |
| `HAYSTACK_IMAGE` | `haystack_image` | same `IMAGE_REF`, else empty |
| `IMAGE_HTTP_URL` | `image_http_url` | Run `image_http_url`, else empty |

Do not put `ghcr.io` paths in git. Public GHCR or ECR tags only; private GHCR fails (no PAT on the guest). Infra `apply` / `configure-only` still run `configure.yml` and do **not** compose these images.

## First compose vs app CD

On `apply` and `configure-only`, Ansible runs `configure.yml` only (Docker + Compose plugin on app guests; compose **Neo4j**). It does **not** pull portal / REST / Haystack images. It does **not** compose onto `hr-bastion`.

`action=deploy-projects` is a **later** `workflow_dispatch` after a successful apply or configure-only (ADR 0014). It is not chained onto those actions. Preflight requires public GHCR or ECR tags (no stock `nginx`, no `image_http_url`), then runs `site.yml`. Re-running it resets all three apps to the infra Environment tags.

Day-to-day image rolls: academy **and** paid callers in `heavy-rental-project-pipeline-development` (`haystack-fast-api-pipeline/deploy-pipeline/`, `heavy-rental-rest-api/deploy-pipeline/`, `heavy-rental-web-portal-pipeline/deploy-pipeline/`). Those workflows must not run Terraform. CORS and secret JSON: [`infra-secrets.md`](infra-secrets.md).

CI images are env-driven (Haystack/REST) or a static SPA (portal). Ansible injects SM; it does not bake lab hostnames into an image.

## ALB health checks

Layout table: [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md). ASGs stay `health_check_type = EC2` (ADR 0008).

| Target group | Probe | Matcher |
| --- | --- | --- |
| `tg-portal` | `GET <instance-ip>:80/` | `200-399` |
| `tg-rest` | `GET <instance-ip>:8080/actuator/health` | **`200-299`** (2xx). Not `GET /` (Spring 401). |
| `tg-haystack` | `GET <instance-ip>:8000/health` | **`200-299`** (2xx). Not `/` or `/docs`. |
| `tg-neo4j` | TCP `<instance-ip>:7687` | TCP |

`site.yml` (deploy-projects) waits for REST and Haystack 2xx on those paths.

## REST ALB

`hr-alb-rest` is internet-facing on **:8080** (ADR 0018). `REST_BASE_URL=http://<rest_alb_dns>:8080`. `APP_CORS_ALLOWED_ORIGINS` is `http://<portal_alb_dns>,http://<rest_alb_dns>:8080`. Portal nginx `/api` hairpins to that public DNS via NAT; `sg-portal` egresses TCP 8080 to `0.0.0.0/0` as well as to `sg-alb-rest`. Without the CIDR rule, `/api` returns **504**. Haystack stays internal. HTTPS is not this pipeline. Same contract as [`infra-paid.md`](infra-paid.md). Diagrams: [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md#portal-api-hairpin-through-nat).

## Specs

- OpenSpec: bootstrap / estate / configure / deploy-projects / paid-pipeline changes under [`../../openspec/changes/`](../../openspec/changes/)
- OpenSPDD: [`../../spdd/`](../../spdd/)
- ADRs: [`../../docs/adr/`](../../docs/adr/) (0014 = `deploy-projects`; 0017 = academy file is Vocareum-only again; 0018 = public REST ALB; 0019 = this file owns its jobs; 0021 = `hr-bastion` single EC2 jump host)
- Secrets: [`infra-secrets.md`](infra-secrets.md)
- Paid: [`infra-paid.md`](infra-paid.md)
