# Delta for infra-academy-bastion

## Purpose

One maintenance jump host so operators can SSH to private app guests without opening `:22` from the internet on those guests.

## ADDED Requirements

### Requirement: Named bastion instance
Terraform SHALL create `aws_instance.bastion` tagged `Name=hr-bastion` and `Role=bastion` in a public subnet, with a public IP, no Auto Scaling group, and no target group. It SHALL NOT set `key_name`. Academy SHALL use `LabInstanceProfile`. Paid SHALL use instance profile `hr-paid-bastion`. Apply SHALL keep the instance `running` (`aws_ec2_instance_state`).

#### Scenario: Describe returns the instance
- GIVEN `action=apply` succeeded
- WHEN `describe-instances` is filtered on `tag:Name=hr-bastion`
- THEN one instance exists
- AND it is not a member of an Auto Scaling group
- AND it is not registered with an ALB target group

### Requirement: SSH chokepoint
`sg-bastion` SHALL allow inbound TCP 22 only from `var.bastion_ssh_cidrs`. That list SHALL reject `0.0.0.0/0`. Empty SHALL mean no public SSH (SSM onto the bastion). `sg-portal`, `sg-rest`, `sg-haystack`, and `sg-neo4j` SHALL allow inbound TCP 22 from `sg-bastion` and SHALL NOT allow TCP 22 from `0.0.0.0/0`.

#### Scenario: App guests are not internet-SSH
- GIVEN the estate is applied
- WHEN app security-group ingress is listed
- THEN TCP 22 from `sg-bastion` is present
- AND TCP 22 from `0.0.0.0/0` is absent

### Requirement: Hop key only on the bastion
`sync-ssh-keys` SHALL write `heavy-rental/ssh/bastion`, install that public key on the bastion and the four app roles, write the matching hop private key onto `hr-bastion` as `id_ed25519`, and copy the four role private keys from `heavy-rental/ssh/{portal,rest,haystack,neo4j}` onto the bastion as `id_{role}`.

#### Scenario: App disks have no hop PEM
- GIVEN four app ASGs are InService and `hr-bastion` is running
- WHEN `sync-ssh-keys` completes
- THEN `heavy-rental/ssh/bastion` contains `private_key_pem` (private key) and `public_key`
- AND portal/rest/haystack/neo4j `authorized_keys` contain the bastion public key
- AND those four roles do not have `/home/ec2-user/.ssh/id_ed25519` or `id_{portal,rest,haystack,neo4j}` from this job
- AND the bastion has those private-key files
- AND the bastion `~/.ssh/config` has Host aliases for each running app guest (`portal`, `rest-1`, …) with `IdentityFile` for that role
- AND interactive SSM on the bastion becomes `ec2-user` so `ssh portal` needs no operator SSH config

### Requirement: Ansible does not compose the bastion
`configure.yml` and `site.yml` SHALL NOT target group `bastion`.

#### Scenario: configure skips bastion
- GIVEN inventory lists a running `hr-bastion` instance
- WHEN `configure.yml` runs
- THEN `guest_base` is not applied to that host
