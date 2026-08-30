# Changelog

## As-built estate (infra CD)

Delivered on this repo. Operator walkthrough: [`OPERATOR-GUIDE.md`](OPERATOR-GUIDE.md). Specs: [`specification/README.md`](specification/README.md).

### Actions

- Two operator workflows with separate job graphs (ADR 0017 / 0019):
  - **AWS infrastructure (Academy)** — `aws-infra-academy.yml`, Environment `academy`, Vocareum keys
  - **AWS infrastructure (paid)** — `aws-infra-paid.yml`, Environment `AWS_ACTUAL`, GitHub OIDC (`AWS_ROLE_TO_ASSUME`)
- `action`: `bootstrap`, `plan`, `apply`, `configure-only`, `deploy-projects`, `stop`, `destroy`
- `apply` / `configure-only` run Ansible `configure.yml` (Docker + Neo4j on app guests only; hop keys on `hr-bastion`)
- `deploy-projects` is a later run of `site.yml` (portal + REST + Haystack first-compose)
- Day-to-day image rolls: app CD academy **and** paid callers in `heavy-rental-project-pipeline-development`

### Estate

- Two NAT Gateways (one per public AZ). Guest count **9 EC2** (8 app + `hr-bastion`). No NAT instance (ADR 0010)
- Maintenance bastion `hr-bastion` (ADR 0021): single EC2 in a public subnet (not an ASG); SSH to app guests from `sg-bastion` only; no `:22` from `0.0.0.0/0`. Interactive SSM becomes `ec2-user` so hops need **no operator SSH config** (`ssh portal`, or `hr-ssh portal` if still `ssm-user`). Secrets Manager `heavy-rental/ssh/*` `private_key_pem` is the **private** key (not the public `.pub`). Bastion gets hop `id_ed25519` plus `id_{portal,rest,haystack,neo4j}`. `hr-ssh-pull-keys` re-reads SM. Helper `scripts/bastion-connect.sh`
- Public portal ALB `:80` and internet-facing REST ALB `:8080` (ADR 0018). Haystack ALB, Bolt NLB, RDS stay internal
- `sg-portal` egress TCP 8080 to `0.0.0.0/0` so private portal guests can hairpin to the public REST ALB DNS via NAT (nginx `/api` otherwise 504s)
- `APP_CORS_ALLOWED_ORIGINS` includes portal origin and `http://<rest_alb_dns>:8080`
- Remote Terraform state: S3 `use_lockfile=true`. Academy `assert-lab` / `ensure-backend` fail closed on `voc-cancel-cred` (HeadBucket 403 is not treated as a missing bucket)
- Academy guests: `LabInstanceProfile` / `LabRole` only. Paid guests: `hr-paid-{portal,rest,haystack,neo4j,bastion}`
- Observe: CloudTrail + flow logs + ALB access logs to S3; dashboard `heavy-rental-academy` or `heavy-rental-actual`. No CloudTrail → CloudWatch Logs. Guest Docker stdout uses the Docker Engine `awslogs` driver into `/heavy-rental/{app}` when Ansible’s `CreateLogStream` probe succeeds (paid IAM `CreateLogStream`/`PutLogEvents`; Academy LabRole probe). `daemon.json` uses Engine log-opts (`awslogs-region`, `awslogs-group`, `tag`) — not ECS `awslogs-stream-prefix`. If the probe is denied or dockerd rejects the file, guests stay on `json-file` and the play continues.
- ASG health stays `EC2` (ADR 0008) — unhealthy ALB targets do not replace instances
- ALB `tg-rest` waits for `GET <instance>:8080/actuator/health` matcher **`200-299`** (2xx). `GET /` is Spring 401 and is not healthy
- ALB `tg-haystack` waits for `GET <instance>:8000/health` matcher **`200-299`** (2xx). `/docs` is not the ALB check
- Haystack workers (ADR 0020): `postgres:17` + `sync-from-primary.sh` (60s FDW merge) and `python:3.12-slim` + `populate_neo4j.py` (60s + compose `:8089`). Not uvicorn `-m`. `:8089` is not on the ALB. `sg-rds` allows :5432 to itself for FDW. `rds_logical` tries `postgres_fdw`.
- REST / Haystack SGs pair with ALB and RDS / Neo4j by security-group id (HR-243). No public 5432 / 8000 / 7687 / 8089

### Out of scope (unchanged)

- Portal / REST HTTPS (ACM)
- Marketplace Neo4j, EKS, NAT instance
- Wrapping `hr-bastion` in an Auto Scaling group
- Authoring app CD YAML in this repo
