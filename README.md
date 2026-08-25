# Heavy Rental — Academy and paid infra CD

GitHub Actions, Terraform, and Ansible that create and operate the estate on **AWS Academy / Vocareum** and on a **billed AWS** account.

**Terraform** creates the architecture (VPC, NAT, ASGs, ALBs, RDS, secret shells, NLB).  
**Ansible** only **configures** guests that Terraform already created (Docker, `.env` from Secrets Manager, compose). It does not create VPCs, ASGs, or RDS.

**Start here if you are running the lab:** [`OPERATOR-GUIDE.md`](OPERATOR-GUIDE.md) (each GitHub Action `action`, first-time path, form fields). Specs: [`specification/README.md`](specification/README.md). Compact operate notes: [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md). Layout: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

| Path | Contents |
| --- | --- |
| `specification/` | Human index and walkthroughs |
| `openspec/` | OpenSpec behavior (SHALL + scenarios) |
| `spdd/` | OpenSPDD analysis + REASONS Canvas |
| `docs/adr/` | ADRs (Vocareum-only, two NAT Gateways, SSM, `SOURCE_*` / `TARGET_*`) |
| `terraform/backend/` | Remote state bucket (bootstrap) |
| `terraform/academy/` | Estate |
| `ansible/` | Guest configuration only |
| `scripts/` | `sync-secrets`, `sync-ssh-keys`, `stop-estate` |

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
| `configure-only` | No apply | Docker + Compose on all guests; **Neo4j only** |
| `deploy-projects` | No | Later run after apply/configure-only: `site.yml` (all three apps) |
| `stop` | No | Pause ASGs + stop both RDS (`scripts/stop-estate.sh`) |
| `destroy` | Tear down estate | No |

Portal / REST / Haystack **first compose** on the estate: `action=deploy-projects` after apply. **Later** image redeploys on Academy are app CD in `heavy-rental-project-pipeline-development` (still academy-only). Paid first-compose is the same `deploy-projects` action on `aws-infra-paid.yml`.

REST ALB (`hr-alb-rest`) is internet-facing on **:8080**. Haystack stays internal.

## Out of scope

- Creating the GitHub OIDC role from estate apply (out of band; see `docs/samples/github-oidc-paid.json`)
- Academy creating IAM (`LabInstanceProfile` / `LabRole` only)
- Portal/REST HTTPS (ACM)
- Paid portal/REST/Haystack **app** CD
- Marketplace Neo4j, EKS, NAT instance
