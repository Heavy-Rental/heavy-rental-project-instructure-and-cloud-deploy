# Academy infra CD

**Authoring tree:** this repo  
**Trigger:** `workflow_dispatch` on Environment `academy` (Vocareum keys on the runner; EC2 uses `LabRole`)

## Split of work

| Tool | Owns |
| --- | --- |
| **Terraform** | Architecture and cloud **resources**: VPC, subnets, IGW, two NAT Gateways, four ASGs + LTs, public portal ALB, internal REST/Haystack ALBs, Bolt NLB, two Multi-AZ RDS, SM **shells**, S3 state |
| **Ansible** | Guest **configuration** only: Docker/Compose, map SM → `.env`, pull/load a CI image, compose, portal nginx `/api`, RDS *logical* grants/extensions. **No** `terraform apply`, no create-ASG, no create-RDS |

`sync-secrets` and `sync-ssh-keys` are shell wrappers (not Terraform). They write JSON / PEMs into shells Terraform already created.

## Actions

```
workflow_dispatch (Environment academy)
      │
      ├── bootstrap         Terraform: state bucket only
      ├── plan              Terraform: show estate (no apply)
      ├── apply             Terraform estate → sync-secrets → sync-ssh-keys → Ansible (all four groups)
      ├── configure-only    No Terraform apply. sync-secrets + PEMs + Ansible (Docker all; compose Neo4j only)
      ├── stop              ASG desired=0 + stop both RDS. NAT Gateways still bill
      └── destroy           Terraform destroy (confirm_destroy=destroy). Keeps state bucket
```

| Action | Creates AWS architecture? | Configures guests? |
| --- | --- | --- |
| `bootstrap` / `plan` / `destroy` | Terraform only | No |
| `apply` | Yes | Yes — first compose |
| `configure-only` | No | Yes — Neo4j compose only |
| `stop` | No (pauses compute/RDS) | No compose |

`configure-only` does **not** replace portal / REST / Haystack images. Those are app CD.

## First compose vs app CD

On `apply`, Ansible first-composes all four groups if images are set (`PORTAL_IMAGE` may be stock `nginx`; REST/Haystack fail if empty). Later image rolls: `haystack-fast-api-pipeline/deploy-pipeline/`, `heavy-rental-rest-api/deploy-pipeline/`, `heavy-rental-web-portal-pipeline/deploy-pipeline/`. Those workflows must not run Terraform.

CI images are env-driven (Haystack/REST) or a static SPA (portal). Ansible injects SM; it does not bake lab hostnames into an image.

## Specs

- OpenSpec: bootstrap / estate / configure changes under [`../../openspec/changes/`](../../openspec/changes/)
- OpenSPDD: [`../../spdd/`](../../spdd/)
- ADRs: [`../../docs/adr/`](../../docs/adr/)
- Secrets: [`infra-secrets.md`](infra-secrets.md)
