# Heavy Rental — Academy infra CD

GitHub Actions, Terraform, and Ansible that create and operate the **AWS Academy / Vocareum** estate.

**Terraform** creates the architecture (VPC, NAT, ASGs, ALBs, RDS, secret shells, NLB).  
**Ansible** only **configures** guests that Terraform already created (Docker, `.env` from Secrets Manager, compose). It does not create VPCs, ASGs, or RDS.

Start here: [`specification/README.md`](specification/README.md). Everyday operate: [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md). Layout: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

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

## Actions (`aws-infra-academy.yml`)

| Action | Terraform | Ansible |
| --- | --- | --- |
| `bootstrap` | State bucket only | No |
| `plan` | Show estate | No |
| `apply` | Create/update estate | First compose (all four groups) after `sync-secrets` |
| `configure-only` | No apply | Docker on all guests; compose **Neo4j only** |
| `stop` | No | Pause ASGs + stop both RDS (`scripts/stop-estate.sh`) |
| `destroy` | Tear down estate | No |

Portal / REST / Haystack **image** redeploys are app CD in `heavy-rental-project-pipeline-development`. Paid / OIDC is later.

## Out of scope

- Creating IAM roles (use `LabInstanceProfile` / `LabRole`)
- App product specs
- Marketplace Neo4j, EKS, NAT instance
