# Implementation plan: AWS infrastructure pipeline (Academy)

**Repo:** this tree (`heavy-rental-project-instructure-and-cloud-deploy`).  
**Contract:** `heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/` — especially `AWS-INFRASTRUCTURE-FEASIBILITY.md` §8, `TERRAFORM-PROCESS.md`, `ANSIBLE-PROCESS.md`, `aws-infra-pipeline.example.yml`.

**Status:** Branches 1–3 are delivered (estate + configure). Layout: [`ARCHITECTURE.md`](ARCHITECTURE.md).

**Split:** Terraform creates AWS architecture and resources. Ansible only configures existing guests. App CD (portal / REST / Haystack images) is in `heavy-rental-project-pipeline-development` `deploy-pipeline/` trees and must not run Terraform. Paid / OIDC is later.

Each feature branch SHALL add or extend **OpenSpec + OpenSPDD + ADR** before expanding YAML or Terraform. Conflict order: OpenSpec scenarios → OpenSPDD Safeguards → ADR → code. See [`../specification/README.md`](../specification/README.md).

---

## 1. Goal

Stand up the **Academy (Vocareum)** estate from GitHub Actions:

- `workflow_dispatch` `action=apply` creates the VPC and compute (Terraform).
- `sync-secrets` writes the required Secrets Manager JSON.
- Ansible first-compose starts CI images on the four ASGs.
- `stop` / `destroy` operate the same pipeline.

**Non-goals (not in the minimum branch set):**

- Paid / OIDC (`aws-infra-paid.yml`)
- Portal / REST / Haystack **app CD** (they consume this estate; they do not create it)
- CDK, Marketplace Neo4j CFT, NAT **instance**, new IAM roles, EKS

---

## 2. Optimal minimum branches: **3** (plus existing default)

Keep the repo default (`master` / `main`). Add **`develop`** once (GitHub Flow, same as app CI). Implement on **three sequential feature branches**. Merge each to `develop`, then promote `develop` → `master` when that slice is accepted.

```
master          (protected default — already exists)
  └── develop   (create once)
        ├── feat/infra-academy-bootstrap     # 1
        ├── feat/infra-academy-estate        # 2  (after 1)
        └── feat/infra-academy-configure     # 3  (after 2)
```

### Why 3 is the minimum that still works

| Count | Problem |
| --- | --- |
| **1** | Workflow + backend + full VPC + four ASGs + RDS + secrets + Ansible in one PR cannot be reviewed. S3 state **cannot** live in the same state it stores (chicken-and-egg). |
| **2** | Folding “Actions can call AWS” into “create the whole estate” hides a dead Vocareum session behind a large apply. You want `action=plan` green **before** you spend credits. |
| **3** | Smallest split that (1) proves auth + remote state, (2) creates the estate, (3) fills secrets and starts containers / stop / destroy. |

Paid infra is a **later wave**, not an extra branch in this minimum. Academy app CD (no Terraform): portal `heavy-rental-web-portal-pipeline/deploy-pipeline/`, REST `heavy-rental-rest-api/deploy-pipeline/`, Haystack `haystack-fast-api-pipeline/deploy-pipeline/`.

---

## 3. Target layout (this repo)

```
.github/workflows/aws-infra-academy.yml
terraform/
  backend/          # branch 1 — S3 + DynamoDB lock only
  academy/          # branch 2 — estate (separate state key)
ansible/
  inventory/        # branch 3 — aws_ssm, groups portal/rest/haystack/neo4j
  playbooks/
  templates/        # portal nginx /api, compose files
```

Academy and paid **never** share a Terraform state key. Paid is out of the first three branches.

---

## 4. Branch 1 — `feat/infra-academy-bootstrap`

**Purpose:** GitHub Actions can authenticate to Vocareum and `terraform plan` against an **empty** estate key. No VPC.

### Tasks

0. OpenSpec change `add-infra-academy-bootstrap`, OpenSPDD REASONS Canvas, ADRs 0001–0003 (this branch).
1. Copy `aws-infra-pipeline.example.yml` → `.github/workflows/aws-infra-academy.yml`.
2. Vocareum form keys + Environment `academy` fallback (ADR 0009). Read form from `$GITHUB_EVENT_PATH` and mask in logs. **Do not** add these inputs to any paid file.
3. Implement `assert-lab` for real (`sts get-caller-identity`).
4. Create GitHub Environment **`academy`** (reviewers if more than one operator). Optional fallback secrets; form is the every-Start-Lab path. Variable `AWS_REGION=us-east-1`.
5. Bootstrap remote state **outside** the estate state: S3 bucket (tiny Terraform in `terraform/backend/` applied once, or console). Estate `init` uses that backend with `use_lockfile=true` (Terraform 1.15; no DynamoDB). The bucket is **not** in the estate state.
6. Wire `action=plan` to `terraform init` + `plan` on an empty `terraform/academy/` (or a `null_resource` placeholder). `apply` may still no-op or refuse until branch 2.

### Done when

Start Lab → Run workflow → paste the three keys (or Environment fallback) → `action=plan` is **green**. No billable VPC/ALB/RDS yet.

---

## 5. Branch 2 — `feat/infra-academy-estate`

**Delivery branch:** `HR-161-implement-aws-infrastructure-academy-by-building-resources`.  
**Purpose:** `action=apply` creates the AWS estate. Containers may be absent.

### Tasks

Terraform in `terraform/academy/` (see [`ARCHITECTURE.md`](ARCHITECTURE.md) and AWS study §8.1):

- VPC, IGW, public / private-app / private-data subnets (**2 AZs**)
- **Two NAT Gateways** (one per public AZ) + EIP each. Per-AZ private route tables. Guest count **8 EC2**. Gateways bill until `destroy`.
- Security groups (portal :80 from public ALB; REST :8080 from portal; Haystack :8000 from rest; RDS :5432 from rest+haystack; Bolt :7687 from haystack / NLB)
- Four launch templates + ASGs with **`LabInstanceProfile` → `LabRole`**. Portal (React), REST (Spring Boot), Haystack **desired=2** (one per app AZ, ALBs span both). `asg-neo4j` **desired=2** (one per data AZ)
- Public portal ALB + `tg-portal` :80; internal REST + Haystack ALBs
- Internal **Bolt NLB** + `tg-neo4j` :7687
- Two **Multi-AZ** RDS (`heavy_rental` SoR + `haystack`). No third RDS for db-sync
- Secrets Manager **shells**: `heavy-rental/{portal,rest,haystack,neo4j}` and `heavy-rental/ssh/*`
- Optional ECR repos. No `key_name` / no `tls_private_key`
- Outputs: ALB DNS, both RDS endpoints, `neo4j_uri` (NLB), NAT ids, secret ARNs

`apply` = `init` → `plan` → `apply` against the estate state key from branch 1.

`destroy` is available on this branch (not waiting for branch 3) so a failed apply can be wiped and recreated: `confirm_destroy=destroy` → terminate estate EC2 (releases eth0) → `terraform destroy`. The state **bucket** stays.

### Done when

`action=apply` creates those resources. `describe-auto-scaling-groups asg-portal` (etc.) returns the groups. App CD still **fails** `describe-secret` field checks until branch 3.

---

## 6. Branch 3 — `feat/infra-academy-configure`

**Delivery branch:** `HR-162-implement-aws-infrastructure-configuration-using-ansible-compose`.  
**Purpose:** Fill secrets, first compose, operate.

### Tasks

1. **`sync-secrets`:** `put-secret-value` for every required field (AWS study §8.2):

   | Secret id | Required fields |
   | --- | --- |
   | `heavy-rental/portal` | `REST_BASE_URL`, `STRIPE_PUBLISHABLE_KEY`, `VITE_STRIPE_PUBLISHABLE_KEY` (same `pk_`) |
   | `heavy-rental/rest` | `POSTGRES_*` / `SPRING_DATASOURCE_*` plus app aliases, `HAYSTACK_BASE_URL`, `APP_CORS_ALLOWED_ORIGINS` (portal ALB), Stripe trio, `APP_JWT_SECRET`, optional OneMap |
   | `heavy-rental/haystack` | Haystack RDS `POSTGRES_*` / aliases / `DATABASE_URL`, `SOURCE_*` (SoR), `TARGET_*` (Haystack RDS), `NEO4J_URI` / user / password, `NEO4J_POPULATE_URL` (`http://neo4j-populate:8089/v1/populate`), `FLEET_BACKEND=sql`, `NEO4J_BACKEND=bolt`, optional `LLM_API_KEY` |
   | `heavy-rental/neo4j` | `NEO4J_USER`, `NEO4J_PASSWORD` |

   Fail if host, database, password, port, or `REST_BASE_URL` is empty. **Never** write Vocareum AWS keys into SM.

2. **`sync-ssh-keys`:** after InService only. PEMs → `heavy-rental/ssh/*`. Public keys via SSM.

3. **Ansible** (`ANSIBLE-PROCESS.md`): SSM inventory `portal` / `rest` / `haystack` / `neo4j`; Docker; `get-secret-value` → `.env`; CI image load/pull; compose with §6.4a limits; portal nginx `/api` → `REST_BASE_URL`; Haystack must not start `neo4j`; RDS logical via `delegate_to` rest or haystack.

4. **`stop`:** ASG desired=0 (all four) + `rds stop-db-instance` on both RDS. NAT Gateways **cannot** be stopped — they bill until `destroy`.

5. **`destroy`:** already on branch 2 (`confirm_destroy=destroy`). Branch 3 must keep the same confirm gate.

### Done when

`configure-only` refills SM + PEMs, installs Docker + Compose on all guests, and composes Neo4j only. `deploy-projects` is a later run that first-composes portal + REST + Haystack via `site.yml`. Day-to-day image rolls are app CD. `stop` pauses compute/RDS (Gateways still bill). `destroy` empties the estate state.

---

## 7. After the three branches (not in the minimum)

| Next | Where | Notes |
| --- | --- | --- |
| Portal app CD | **Shipped** in `heavy-rental-web-portal-pipeline/deploy-pipeline/` (discover + compose) | Reuses this repo’s `guest_base` + `portal`. Does not create the estate. |
| REST app CD | **Shipped** in `heavy-rental-rest-api/deploy-pipeline/` (discover + compose) | Reuses this repo’s `guest_base` + `rest`. Does not create the estate. |
| Haystack app CD | **Shipped** in `haystack-fast-api-pipeline/deploy-pipeline/` (discover + compose) | Reuses this repo’s `guest_base` + `haystack`. No Neo4j container. |
| Paid infra | later | Separate account, OIDC, **no** Vocareum form keys |

Infra `configure-only` installs Docker + Compose and composes Neo4j. Infra `deploy-projects` (later run after apply/configure-only) first-composes all three apps. Portal / REST / Haystack image updates after that use those app CD pipelines.

---

## 8. Merge and protect

1. Create `develop` from `master`.
2. Open PR `feat/infra-academy-bootstrap` → `develop`. Merge only when `action=plan` is green.
3. Branch 2 from updated `develop`. PR → `develop`. Merge when `apply` creates the estate.
4. Branch 3 from updated `develop`. PR → `develop`. Merge when configure/stop/destroy work.
5. PR `develop` → `master` when the class is ready to treat this as the CD default.

Protect `master` (and `develop` if more than one operator). Environment `academy` reviewers on `apply` / `destroy`.

---

## 9. Forbidden in every branch

- `aws_iam_role` / OIDC provider on Academy
- NAT **instance**, Marketplace Neo4j CFT
- Neo4j causal cluster (two guests share an NLB; they are not clustered)
- REST or Haystack on the public ALB
- Vocareum keys in Secrets Manager or on the guest
- Vocareum form keys on **paid** workflows
- Local Terraform state on the GitHub runner
- `destroy` without `confirm_destroy=destroy`

---

## 10. Pointers

- Architecture layout: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Pinned versions: [`VERSIONS.md`](VERSIONS.md)
- Estate + E2E: `../heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/AWS-INFRASTRUCTURE-FEASIBILITY.md` §8
- Terraform jobs: `.../TERRAFORM-PROCESS.md`
- Ansible jobs: `.../ANSIBLE-PROCESS.md`
- Academy workflow stub: `.../aws-infra-pipeline.example.yml`
