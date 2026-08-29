# Heavy Rental — Academy and paid infra CD

GitHub Actions, Terraform, and Ansible that create and operate the estate on **AWS Academy / Vocareum** and on a **billed AWS** account.

**Terraform** creates the architecture (VPC, NAT, four app ASGs + `hr-bastion` single EC2, ALBs, RDS, secret shells, NLB).  
**Ansible** only **configures** guests that Terraform already created (Docker, `.env` from Secrets Manager, compose). It does not create VPCs, ASGs, or RDS.

**Start here if you are running the lab:** [`OPERATOR-GUIDE.md`](OPERATOR-GUIDE.md) (each GitHub Action `action`, first-time path, form fields). Specs: [`specification/README.md`](specification/README.md). Compact operate notes: [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md). Layout: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

| Path | Contents |
| --- | --- |
| `specification/` | Human index and walkthroughs |
| `openspec/` | OpenSpec behavior (SHALL + scenarios) |
| `spdd/` | OpenSPDD analysis + REASONS Canvas |
| `docs/adr/` | ADRs (Vocareum-only, two NAT Gateways, SSM, public REST ALB, `SOURCE_*` / `TARGET_*`, `hr-bastion`) |
| `terraform/backend/` | Remote state bucket (bootstrap) |
| `terraform/academy/` | Estate |
| `ansible/` | Guest configuration only |
| `scripts/` | `sync-secrets`, `sync-ssh-keys`, `stop-estate`, `estate-tf-init`, `estate-unlock`, `reconcile-estate`, `sweep-estate-orphans`, `bootstrap-github-oidc-paid`, `bastion-connect`, `bastion-hr-ssh-config` (installed on the bastion as `hr-ssh-config`) |

## Actions

Two operator workflows, **separate job graphs** (ADR 0019):

| Workflow | Environment | Auth |
| --- | --- | --- |
| `aws-infra-academy.yml` | `academy` | Vocareum keys |
| `aws-infra-paid.yml` | `AWS_ACTUAL` | GitHub OIDC (`AWS_ROLE_TO_ASSUME` variable or secret). Setup: [`docs/OIDC-PAID.md`](docs/OIDC-PAID.md) |

| Action | Terraform | Ansible |
| --- | --- | --- |
| `bootstrap` | State bucket only | No |
| `plan` | Show estate | No |
| `apply` | Create/update estate | Same as configure-only (`configure.yml`) |
| `configure-only` | No apply | Docker + Compose on app guests; **Neo4j only**. Hop keys on `hr-bastion` |
| `deploy-projects` | No | Later run after apply/configure-only: `site.yml` (all three apps) |
| `stop` | No | Pause ASGs + stop both RDS (`scripts/stop-estate.sh`) |
| `destroy` | Tear down estate | No |

Portal / REST / Haystack **first compose** on the estate: `action=deploy-projects` after apply. **Later** image redeploys are app CD in `heavy-rental-project-pipeline-development` (academy **and** paid callers). Paid first-compose is the same `deploy-projects` action on `aws-infra-paid.yml`.

REST ALB (`hr-alb-rest`) is internet-facing on **:8080**. Haystack stays internal.

ALB health (after compose): `tg-rest` waits for `GET <instance>:8080/actuator/health` **2xx** (`200-299`); `tg-haystack` waits for `GET <instance>:8000/health` **2xx**. Layout: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Out of scope

- Creating the GitHub OIDC role from estate apply (out of band; see `docs/samples/github-oidc-paid.json`)
- Academy creating IAM (`LabInstanceProfile` / `LabRole` only)
- Portal/REST HTTPS (ACM)
- Marketplace Neo4j, EKS, NAT instance
- Authoring portal/REST/Haystack **app** CD YAML (that lives in `heavy-rental-project-pipeline-development`)
