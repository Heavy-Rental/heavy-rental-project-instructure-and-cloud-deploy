# Architecture Decision Records

ADRs for this CD repo (Nygard format). Conflict order: **OpenSpec → OpenSPDD Safeguards → these ADRs → YAML / Terraform**.

| ID | Title |
| --- | --- |
| [0001](0001-academy-vocareum-only.md) | Academy / Vocareum only on `aws-infra-academy.yml` (restored by 0017) |
| [0002](0002-vocareum-keys-on-dispatch.md) | Session keys on Run workflow (**superseded** by 0009) |
| [0003](0003-remote-state-outside-estate.md) | Remote Terraform state outside the estate |
| [0004](0004-nat-instance-not-gateway.md) | NAT instance, not NAT Gateway (**superseded** by 0010) |
| [0010](0010-two-nat-gateways.md) | Two NAT Gateways, one per AZ |
| [0005](0005-labinstanceprofile-only.md) | Academy: LabInstanceProfile only — never create IAM (paid IAM is 0016/0017) |
| [0006](0006-empty-secret-shells.md) | Empty Secrets Manager shells |
| [0007](0007-neo4j-dedicated-eni.md) | Two Neo4j guests + internal Bolt NLB |
| [0008](0008-ec2-health-until-compose.md) | EC2 health on app ASGs until compose (ALB TGs still probe REST `/actuator/health` and Haystack `/health`) |
| [0009](0009-academy-keys-in-environment-secrets.md) | Vocareum keys on the Run form, masked in logs |
| [0011](0011-pems-after-inservice.md) | SSH private keys after InService, not in Terraform (`private_key_pem` is the private key) |
| [0012](0012-ansible-over-ssm.md) | Ansible over SSM, not SSH (configuration only; Terraform owns architecture) |
| [0013](0013-haystack-source-target-in-sync-secrets.md) | SoR → Haystack sync endpoints in infra `sync-secrets` |
| [0014](0014-deploy-projects-after-configure.md) | `deploy-projects` is a later run of `site.yml`, not part of apply |
| [0015](0015-academy-observe-no-iam.md) | Observe uses LabRole + S3; no CloudTrail → CloudWatch Logs (paid trail name `heavy-rental-actual`) |
| [0016](0016-dual-profile-academy-paid.md) | Dual profile isolation (superseded in part by 0017) |
| [0017](0017-two-actions-academy-paid.md) | Two Actions: academy Vocareum / paid OIDC |
| [0018](0018-public-rest-alb.md) | REST ALB is internet-facing :8080; portal `/api` hairpins via NAT (`sg-portal` :8080 to `0.0.0.0/0`) |
| [0019](0019-separate-job-graphs.md) | Separate job graphs (no reusable estate workflow) |
| [0020](0020-haystack-devcontainer-workers.md) | Haystack workers are Fast API devcontainer scripts + `sg-rds` FDW |
| [0021](0021-maintenance-bastion-ssh.md) | Maintenance bastion (`hr-bastion` single EC2) for SSH hops; hop + role private keys on bastion; no `:22` from `0.0.0.0/0` |
