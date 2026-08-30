# Paid infra CD

**Authoring tree:** this repo  
**Trigger:** `workflow_dispatch` on `.github/workflows/aws-infra-paid.yml`, Environment `AWS_ACTUAL` (GitHub OIDC). EC2 uses Terraform `hr-paid-*` instance profiles.

Academy / Vocareum: [`infra-academy.md`](infra-academy.md). This Action owns its jobs (ADR 0019). Do not call the academy workflow.

## Split of work

Same Terraform root (`terraform/academy/`, `var.deployment=actual`) and the same Ansible playbooks as academy. Differences:

| | Academy | Paid |
| --- | --- | --- |
| Action file | `aws-infra-academy.yml` | `aws-infra-paid.yml` |
| Auth | Vocareum keys | OIDC `AWS_ROLE_TO_ASSUME` |
| Guests | `LabRole` | `hr-paid-{portal,rest,haystack,neo4j,bastion}` |
| State bucket | `…-academy` | `…-actual` |
| Ansible S3 | tfstate bucket | `heavy-rental-ssm-<account>-actual` |
| Vocareum form keys | Required (or Environment fallback) | **Not declared** |
| Observe names | `heavy-rental-academy` | `heavy-rental-actual` |

| Tool | Owns |
| --- | --- |
| **Terraform** | Architecture and cloud **resources**: VPC, subnets, IGW, two NAT Gateways, four app ASGs + LTs, **`hr-bastion`** (single EC2), public portal ALB, **internet-facing REST ALB :8080**, internal Haystack ALB, Bolt NLB, two Multi-AZ RDS, SM **shells**, S3 state, CloudTrail (S3), VPC flow logs (S3), ALB access logs, CloudWatch alarms + dashboard, paid SSM bucket, `hr-paid-*` instance profiles (apps + bastion) |
| **Ansible** | Guest **configuration** only: Docker/Compose, map SM → `.env`, pull/load a CI image, compose, portal nginx `/api`, RDS *logical* grants/extensions. `guest_base` probes `logs:CreateLogStream` and may set Docker Engine `awslogs` (not ECS `awslogs-stream-prefix`); otherwise `json-file`. Paid `hr-paid-*` also has `PutLogEvents`. **No** `terraform apply`, no create-ASG, no create-RDS |

`sync-secrets` and `sync-ssh-keys` are shell wrappers (not Terraform). They write JSON / SSH key material into shells Terraform already created. `private_key_pem` is the **private** OpenSSH key (not the public `.pub`). Bastion gets hop + role private keys; app guests get public keys only. Paid `hr-paid-bastion` may `GetSecretValue` `heavy-rental/ssh/*` only.

## Actions

```
workflow_dispatch (Environment AWS_ACTUAL)
      │
      ├── bootstrap         Terraform: state bucket only
      ├── plan              Import leftovers → Terraform show estate (no apply)
      ├── apply             Import leftovers → Terraform estate → sync-secrets → sync-ssh-keys → Ansible configure.yml
      ├── configure-only    No Terraform apply. sync-secrets + PEMs → same Ansible configure.yml
      ├── deploy-projects   Later run after apply or configure-only. Preflight images → site.yml
      ├── stop              App ASG desired=0 + stop hr-bastion + stop both RDS. NAT Gateways still bill
      └── destroy           Import leftovers → terraform destroy → sweep this DEPLOYMENT's leftovers.
                            Keeps state bucket. Observe names are heavy-rental-actual.
```

| Action | Creates AWS architecture? | Configures guests? |
| --- | --- | --- |
| `bootstrap` / `plan` / `destroy` | Terraform only | No |
| `apply` | Yes | Yes — Docker/Compose + Neo4j only (`configure.yml`) |
| `configure-only` | No | Same as apply Ansible (`configure.yml`) |
| `deploy-projects` | No | Yes — `site.yml` (portal + REST + Haystack + Neo4j + `rds_logical`) |
| `stop` | No (pauses compute/RDS) | No compose |

`configure-only` does **not** replace portal / REST / Haystack images. `deploy-projects` is the infra first-compose (later run). Day-to-day rolls are app CD in `heavy-rental-project-pipeline-development` (academy **and** paid callers).

## Image variables (infra Environment `AWS_ACTUAL`)

Same names as academy, **this** Environment’s copies — not academy’s and not the three app-repo Environments.

| GitHub variable | Ansible var | Empty means |
| --- | --- | --- |
| `PORTAL_IMAGE` | `portal_image` | stock `nginx` |
| `REST_IMAGE` | `rest_image` | Run `image_ref` (`IMAGE_REF`), else empty |
| `HAYSTACK_IMAGE` | `haystack_image` | same `IMAGE_REF`, else empty |
| `IMAGE_HTTP_URL` | `image_http_url` | Run `image_http_url`, else empty |

Do not put `ghcr.io` paths in git. Public GHCR or ECR tags only; private GHCR fails (no PAT on the guest). Infra `apply` / `configure-only` still run `configure.yml` and do **not** compose these images.

## First compose vs app CD

On `apply` and `configure-only`, Ansible runs `configure.yml` only (Docker + Compose plugin on app guests; compose **Neo4j**). It does **not** pull portal / REST / Haystack images. It does **not** compose onto `hr-bastion`.

`action=deploy-projects` is a **later** `workflow_dispatch` after a successful apply or configure-only (ADR 0014). It is not chained onto those actions. Preflight requires public GHCR or ECR tags (no stock `nginx`, no `image_http_url`), then runs `site.yml`. Re-running it resets all three apps to the infra Environment `AWS_ACTUAL` tags.

Day-to-day image rolls: academy and paid callers in `heavy-rental-project-pipeline-development` (`haystack-fast-api-pipeline/deploy-pipeline/`, `heavy-rental-rest-api/deploy-pipeline/`, `heavy-rental-web-portal-pipeline/deploy-pipeline/`). Those workflows must not run Terraform.

## One-time OIDC

Create the GitHub OIDC provider and IAM role `github-actions-infra` in the billed account **before** the first paid `plan`. Estate apply cannot create the role it assumes.

Operator guide (AWS Console, CLI script, GitHub Environment variable **or** secret): [`../../docs/OIDC-PAID.md`](../../docs/OIDC-PAID.md). Sample trust and runner policy: [`../../docs/samples/github-oidc-paid.json`](../../docs/samples/github-oidc-paid.json). Script: `GITHUB_ORG=ORG ./scripts/bootstrap-github-oidc-paid.sh`.

Put the role ARN on Environment `AWS_ACTUAL` as **variable** or **secret** `AWS_ROLE_TO_ASSUME`. Trust `repo:ORG/heavy-rental-project-instructure-and-cloud-deploy:*`. Do **not** put `AWS_ACCESS_KEY_ID` on Environment `AWS_ACTUAL`.

## REST ALB

`hr-alb-rest` is internet-facing on **:8080** (ADR 0018). `REST_BASE_URL=http://<rest_alb_dns>:8080`. `APP_CORS_ALLOWED_ORIGINS` is `http://<portal_alb_dns>,http://<rest_alb_dns>:8080` for **direct** REST ALB browser calls. Portal nginx `/api` is same-origin: it hairpins to that public DNS via NAT, sets `Host $proxy_host`, and **omits `Origin`**. `sg-portal` egresses TCP 8080 to `0.0.0.0/0` as well as to `sg-alb-rest`. Haystack stays internal. HTTPS is not this pipeline. This diverges from feasibility §6P (study said REST internal / no public 8080).

**Health:** `tg-rest` waits for `GET <instance-ip>:8080/actuator/health` matcher **`200-299`** (2xx). `GET /` is Spring 401 and is not healthy. `tg-haystack` waits for `GET <instance-ip>:8000/health` matcher **`200-299`**. Table: [`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md). OpenSpec: [`../../openspec/changes/add-infra-paid-pipeline/specs/infra-estate-rest-alb/spec.md`](../../openspec/changes/add-infra-paid-pipeline/specs/infra-estate-rest-alb/spec.md).

## Specs

- OpenSpec: [`../../openspec/changes/add-infra-paid-pipeline/`](../../openspec/changes/add-infra-paid-pipeline/)
- OpenSPDD: [`../../spdd/analysis/add-infra-paid-pipeline.md`](../../spdd/analysis/add-infra-paid-pipeline.md), [`../../spdd/prompt/add-infra-paid-pipeline.md`](../../spdd/prompt/add-infra-paid-pipeline.md)
- ADRs: [0017](../../docs/adr/0017-two-actions-academy-paid.md), [0018](../../docs/adr/0018-public-rest-alb.md), [0019](../../docs/adr/0019-separate-job-graphs.md), [0021](../../docs/adr/0021-maintenance-bastion-ssh.md)
- Secrets: [`infra-secrets.md`](infra-secrets.md)
