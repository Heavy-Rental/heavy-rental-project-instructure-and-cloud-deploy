# Architecture Decision Records

ADRs for this CD repo (Nygard format). Conflict order: **OpenSpec → OpenSPDD Safeguards → these ADRs → YAML / Terraform**.

| ID | Title |
| --- | --- |
| [0001](0001-academy-vocareum-only.md) | Academy / Vocareum only on the first pipeline |
| [0002](0002-vocareum-keys-on-dispatch.md) | Session keys on Run workflow |
| [0003](0003-remote-state-outside-estate.md) | Remote Terraform state outside the estate |
| [0004](0004-nat-instance-not-gateway.md) | NAT instance, not NAT Gateway |
| [0005](0005-labinstanceprofile-only.md) | LabInstanceProfile only — never create IAM |
| [0006](0006-empty-secret-shells.md) | Empty Secrets Manager shells |
| [0007](0007-neo4j-dedicated-eni.md) | Dedicated ENI for asg-neo4j |
| [0008](0008-ec2-health-until-compose.md) | EC2 health on app ASGs until compose |
