# Academy infra CD

**Authoring tree:** this repo  
**Trigger:** `workflow_dispatch` on Environment `academy` (Vocareum keys on the runner; EC2 uses `LabRole`)

## Split of work

| Tool | Owns |
| --- | --- |
| **Terraform** | Architecture and cloud **resources**: VPC, subnets, IGW, two NAT Gateways, four ASGs + LTs, public portal ALB, internal REST/Haystack ALBs, Bolt NLB, two Multi-AZ RDS, SM **shells**, S3 state, CloudTrail (S3), VPC flow logs (S3), ALB access logs, CloudWatch alarms + dashboard. Guests use **LabRole** / `LabInstanceProfile` only |
| **Ansible** | Guest **configuration** only: Docker/Compose, map SM → `.env`, pull/load a CI image, compose, portal nginx `/api`, RDS *logical* grants/extensions. **No** `terraform apply`, no create-ASG, no create-RDS |

`sync-secrets` and `sync-ssh-keys` are shell wrappers (not Terraform). They write JSON / PEMs into shells Terraform already created.

## Actions

```
workflow_dispatch (Environment academy)
      │
      ├── bootstrap         Terraform: state bucket only
      ├── plan              Import leftovers → Terraform show estate (no apply)
      ├── apply             Import leftovers → Terraform estate → sync-secrets → sync-ssh-keys → Ansible configure.yml
      ├── configure-only    No Terraform apply. sync-secrets + PEMs → same Ansible configure.yml
      ├── deploy-projects   Later run after apply or configure-only. Preflight images → site.yml
      ├── stop              ASG desired=0 + stop both RDS. NAT Gateways still bill
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

On `apply` and `configure-only`, Ansible runs `configure.yml` only (Docker + Compose plugin on all guests; compose **Neo4j**). It does **not** pull portal / REST / Haystack images.

`action=deploy-projects` is a **later** `workflow_dispatch` after a successful apply or configure-only (ADR 0014). It is not chained onto those actions. Preflight requires public GHCR or ECR tags (no stock `nginx`, no `image_http_url`), then runs `site.yml`. Re-running it resets all three apps to the infra Environment tags.

Day-to-day image rolls: `haystack-fast-api-pipeline/deploy-pipeline/`, `heavy-rental-rest-api/deploy-pipeline/`, `heavy-rental-web-portal-pipeline/deploy-pipeline/`. Those workflows must not run Terraform.

CI images are env-driven (Haystack/REST) or a static SPA (portal). Ansible injects SM; it does not bake lab hostnames into an image.

## Specs

- OpenSpec: bootstrap / estate / configure / deploy-projects changes under [`../../openspec/changes/`](../../openspec/changes/)
- OpenSPDD: [`../../spdd/`](../../spdd/)
- ADRs: [`../../docs/adr/`](../../docs/adr/) (0014 = `deploy-projects`)
- Secrets: [`infra-secrets.md`](infra-secrets.md)
