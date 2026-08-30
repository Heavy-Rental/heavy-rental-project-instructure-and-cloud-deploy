# Academy Secrets Manager (`sync-secrets`)

Terraform creates **empty** secret shells. `scripts/sync-secrets.sh` (infra CD, not Ansible and not Terraform resources) writes JSON after estate outputs exist. Ansible only **reads** those secrets onto the guest as `.env`.

Never write Vocareum `AWS_*` into SM. Never put those keys on the EC2.

## JSON per secret

| Secret id | Who reads | Required fields |
| --- | --- | --- |
| `heavy-rental/portal` | `asg-portal` / portal app CD | `REST_BASE_URL` (`http://<rest_alb_dns>:8080`, internet-facing REST ALB — public DNS; portal nginx `/api` hairpins via NAT), `STRIPE_PUBLISHABLE_KEY`, `VITE_STRIPE_PUBLISHABLE_KEY` (same `pk_`). **No** `sk_` or webhook |
| `heavy-rental/rest` | `asg-rest` / REST app CD | SoR `POSTGRES_*` + aliases + `SPRING_DATASOURCE_*`, `HAYSTACK_BASE_URL` (Haystack ALB), `APP_CORS_ALLOWED_ORIGINS` (`http://<portal_alb_dns>,http://<rest_alb_dns>:8080`), Stripe trio, `APP_JWT_SECRET` (env / reuse SM / generate ≥ 32), optional `ONEMAP_EMAIL` / `ONEMAP_PASSWORD` from Environment secrets |
| `heavy-rental/haystack` | `asg-haystack` / Haystack app CD | Haystack RDS `POSTGRES_*` / aliases / `DATABASE_URL`, `SOURCE_HOST` / `SOURCE_PORT` / `SOURCE_DATABASE` (SoR `heavy_rental`), `TARGET_HOST` / `TARGET_PORT` / `TARGET_DATABASE` (Haystack RDS), `FLEET_BACKEND=sql`, `NEO4J_BACKEND=bolt`, `NEO4J_URI` (Bolt NLB) / user / password, `NEO4J_POPULATE_URL` (`http://neo4j-populate:8089/v1/populate` — Compose network on `asg-haystack`, not an ALB or SG). Optional `LLM_API_KEY`. No Stripe. No `SOURCE_USER` in SM — Ansible aliases `SOURCE_USER` / `SOURCE_DB` / `PG*` / `NEO4J_POPULATE_TRIGGER_URL` from these keys (ADR 0020) |
| `heavy-rental/neo4j` | `asg-neo4j` (infra compose only) | `NEO4J_USER`, `NEO4J_PASSWORD` |

`SOURCE_*` / `TARGET_*` are infra-owned (ADR 0013). Haystack app CD maps SM → `.env` and must not invent hosts or a third RDS.

Portal / REST / Haystack **Release images** must not bake these values (pipeline-development ADRs). Ansible/`sync-secrets` supply them at configure/deploy time.

## Fail closed

Empty RDS hostname, database, password, port, or `REST_BASE_URL` fails `sync-secrets`. Missing shell fails app CD `describe-secret`.

## SSH PEMs

`sync-ssh-keys` writes `heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion}` after the four app ASGs are **InService** and `hr-bastion` is **running** (ADR 0011 / 0021). Not Terraform `tls_private_key`.

JSON per SSH secret: `key_name`, `private_key_pem` (**private** OpenSSH key, `BEGIN OPENSSH PRIVATE KEY` — this is not the public key), `public_key` (one-line `ssh-ed25519 AAAA…` that goes in `authorized_keys`).

| Secret id | Where the private key goes | Public key |
| --- | --- | --- |
| `heavy-rental/ssh/{portal,rest,haystack,neo4j}` | Secrets Manager **and** `/home/ec2-user/.ssh/id_{role}` on `hr-bastion` | App guests’ `authorized_keys` via SSM. Never a private key on app disks |
| `heavy-rental/ssh/bastion` | Secrets Manager **and** `/home/ec2-user/.ssh/id_ed25519` on `hr-bastion` | `hr-bastion` and all four app roles |

On `hr-bastion`, `hr-ssh-config` writes Host aliases (`ssh portal`, `ssh rest-2`, `ssh haystack-1a`, `ssh neo4j`) with `IdentityFile` = that role’s private key plus the hop key. `hr-ssh-pull-keys` re-reads `private_key_pem` from SM onto the bastion. Interactive SSM becomes `ec2-user` so operators do not write SSH config; `hr-ssh` hops as `ec2-user` if the shell is still `ssm-user`. App guests never receive a private key. Optional Environment variable `BASTION_SSH_CIDRS` (never `0.0.0.0/0`) opens `:22` on `sg-bastion` only.
