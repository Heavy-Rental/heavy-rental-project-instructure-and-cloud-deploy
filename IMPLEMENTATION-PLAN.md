# Implementation plan: AWS infrastructure pipeline (Academy)

**Repo:** this tree (`heavy-rental-project-instructure-and-cloud-deploy`).  
**Contract:** `heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/` — especially `AWS-INFRASTRUCTURE-FEASIBILITY.md` §8, `TERRAFORM-PROCESS.md`, `ANSIBLE-PROCESS.md`, `aws-infra-pipeline.example.yml`.

**Status:** Branch 1 merged. Branch 2 (`feat/infra-academy-estate`) is implemented on `HR-161-implement-aws-infrastructure-academy-by-building-resources` (estate Terraform + `action=apply`).

Each feature branch SHALL add or extend **OpenSpec + OpenSPDD + ADR** before expanding YAML or Terraform. Conflict order: OpenSpec scenarios → OpenSPDD Safeguards → ADR → code. See [`specification/README.md`](specification/README.md).

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
- CDK, Marketplace Neo4j CFT, NAT Gateway, new IAM roles, EKS

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

Paid and app CD are **later waves**, not extra branches in this minimum.

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

Terraform in `terraform/academy/` (see AWS study §8.1 / `TERRAFORM-PROCESS.md`):

- VPC, IGW, public / private-app / private-data subnets (2 AZs), NAT **instance** (not Gateway)
- Security groups (portal :80 from public ALB; REST :8080 from portal; Haystack :8000 from rest; RDS :5432 from rest+haystack; Bolt :7687 from haystack only)
- Four launch templates + ASGs with **`LabInstanceProfile`** only — **no** `aws_iam_role`
- Public portal ALB + `tg-portal` :80
- Internal REST ALB + `tg-rest` :8080; internal Haystack ALB + `tg-haystack` :8000
- RDS in the **data** subnet group (`publicly_accessible=false`, `multi_az=false`, `deletion_protection=false`)
- `asg-neo4j` `max=1`, data subnets, EC2 health, scale-in protection
- Secrets Manager **shells**: `heavy-rental/{portal,rest,haystack,neo4j}` and `heavy-rental/ssh/*` (`recovery_window_in_days=0`)
- Optional ECR repos
- No `key_name` / no `tls_private_key`
- Outputs: portal/REST/Haystack ALB DNS, RDS endpoint, Neo4j private IP, secret ARNs

`apply` = `init` → `plan` → `apply` against the estate state key from branch 1.

### Done when

`action=apply` creates those resources. `describe-auto-scaling-groups asg-portal` (etc.) returns the groups. App CD still **fails** `describe-secret` field checks until branch 3.

---

## 6. Branch 3 — `feat/infra-academy-configure`

**Purpose:** Fill secrets, first compose, operate.

### Tasks

1. **`sync-secrets`:** `put-secret-value` for every required field (AWS study §8.2):

   | Secret id | Required fields |
   | --- | --- |
   | `heavy-rental/portal` | `REST_BASE_URL`, `STRIPE_PUBLISHABLE_KEY` |
   | `heavy-rental/rest` | `POSTGRES_*` / `SPRING_DATASOURCE_*`, `HAYSTACK_URL`, Stripe trio |
   | `heavy-rental/haystack` | Postgres fields, `NEO4J_URI` / user / password |
   | `heavy-rental/neo4j` | `NEO4J_USER`, `NEO4J_PASSWORD` |

   Fail if host, database, password, port, or `REST_BASE_URL` is empty. **Never** write Vocareum AWS keys into SM.

2. **`sync-ssh-keys`:** after InService only. PEMs → `heavy-rental/ssh/*`. Public keys via SSM.

3. **Ansible** (`ANSIBLE-PROCESS.md`): SSM inventory `portal` / `rest` / `haystack` / `neo4j`; Docker; `get-secret-value` → `.env`; CI image load/pull; compose with §6.4a limits; portal nginx `/api` → `REST_BASE_URL`; Haystack must not start `neo4j`; RDS logical via `delegate_to` rest or haystack.

4. **`stop`:** ASG desired=0 (all four + NAT) + `rds stop-db-instance`.

5. **`destroy`:** `confirm_destroy=destroy` → `terraform destroy` of **this** estate state only.

### Done when

`configure-only` starts containers. Portal ALB serves `:80`. `stop` pauses compute/RDS. `destroy` empties the estate state.

---

## 7. After the three branches (not in the minimum)

| Next | Branch (later) | Why it waited |
| --- | --- | --- |
| Portal app CD | `feat/cd-portal-academy` | Needs `asg-portal` + `heavy-rental/portal` |
| REST app CD | `feat/cd-rest-academy` | Needs `asg-rest` + `heavy-rental/rest` |
| Haystack app CD | `feat/cd-haystack-academy` | Needs `asg-haystack` + `heavy-rental/haystack` |
| Paid infra | `feat/infra-paid` | Separate account, OIDC, **no** Vocareum form keys |

Each app CD is one branch (discover + image + one Ansible group). Do not start them before branch 3.

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
- NAT Gateway, Marketplace Neo4j CFT, Multi-AZ RDS
- REST or Haystack on the public ALB
- Vocareum keys in Secrets Manager or on the guest
- Vocareum form keys on **paid** workflows
- Local Terraform state on the GitHub runner
- `destroy` without `confirm_destroy=destroy`

---

## 10. Pointers

- Pinned versions: [`docs/VERSIONS.md`](docs/VERSIONS.md)
- Estate + E2E: `../heavy-rental-project-pipeline-development/cloud-deployment-feasibility-studies/AWS-INFRASTRUCTURE-FEASIBILITY.md` §8
- Terraform jobs: `.../TERRAFORM-PROCESS.md`
- Ansible jobs: `.../ANSIBLE-PROCESS.md`
- Academy workflow stub: `.../aws-infra-pipeline.example.yml`
