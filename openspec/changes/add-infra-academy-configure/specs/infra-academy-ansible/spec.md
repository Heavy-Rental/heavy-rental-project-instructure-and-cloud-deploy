# Delta for infra-academy-ansible

> **Later modified by** [`add-infra-academy-deploy-projects`](../../../add-infra-academy-deploy-projects/specs/infra-academy-ansible/spec.md): apply / configure-only stay on `configure.yml` (Docker + Neo4j). Missing REST/Haystack images do **not** fail those actions. `site.yml` is only `deploy-projects`.  
> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-bastion/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): inventory may list group `bastion`; `configure.yml` and `site.yml` SHALL NOT target it. Compose groups stay `portal` / `rest` / `haystack` / `neo4j`.

## Purpose

Guest **configuration** only on guests Terraform already created. Infra CD (`apply` and `configure-only`) SHALL run `playbooks/configure.yml`: Docker + Compose plugin on the four app groups and Neo4j compose only. It SHALL NOT invoke `site.yml` (full portal/REST/Haystack compose). Ansible SHALL NOT create or destroy VPC, ASGs, ALBs, or RDS. App CD composes portal/REST/Haystack and SHALL NOT run Terraform. **Current:** `hr-bastion` is inventoried but not composed (banner).

## ADDED Requirements

### Requirement: SSM inventory of four app groups
Ansible SHALL inventory InService + SSM Online instances for `portal`, `rest`, `haystack`, and `neo4j`. Connection SHALL be AWS SSM. RDS SHALL NOT be an inventory host. **Current:** inventory may also list `bastion` (banner); compose playbooks do not target it.

#### Scenario: Desired=2 discovers two guests per group
- GIVEN each ASG has two InService guests Online in SSM
- WHEN Ansible runs
- THEN each group has two hosts
- AND `ansible_host` is an instance id, not a public IP

### Requirement: Ansible does not create architecture
Ansible playbooks SHALL NOT invoke Terraform or create Auto Scaling groups, load balancers, or RDS instances.

#### Scenario: No terraform in the play
- GIVEN Ansible runs on `apply` or `configure-only`
- WHEN the playbook job list is evaluated
- THEN no task runs `terraform apply` or `terraform destroy`

#### Scenario: Infra CD does not compose app images
- GIVEN `action` is `apply` or `configure-only`
- WHEN the Ansible step runs
- THEN it invokes `playbooks/configure.yml`
- AND it does not invoke `playbooks/site.yml`
- AND portal / rest / haystack compose roles do not run

### Requirement: Image tags from GitHub Environment variables
`inventory/group_vars/all.yml` SHALL set `portal_image`, `rest_image`, and `haystack_image` from the Ansible controller environment (`PORTAL_IMAGE`, `REST_IMAGE`, `HAYSTACK_IMAGE`). Those names SHALL match GitHub Environment **variables** on `academy` (not secrets, not hardcoded `ghcr.io` paths). Empty `PORTAL_IMAGE` SHALL default to stock `nginx`. Empty `REST_IMAGE` / `HAYSTACK_IMAGE` SHALL fall back to Run-form `IMAGE_REF`, else empty. Infra CD SHALL still not compose portal / REST / Haystack (`configure.yml` only). Manual `site.yml` MAY use the resolved tags.

#### Scenario: group_vars has no baked GHCR path
- GIVEN `ansible/inventory/group_vars/all.yml`
- WHEN the file is read
- THEN it contains no literal `ghcr.io` image tag
- AND `portal_image` looks up `PORTAL_IMAGE`
- AND `rest_image` looks up `REST_IMAGE`
- AND `haystack_image` looks up `HAYSTACK_IMAGE`

#### Scenario: empty portal variable stays stock nginx
- GIVEN controller env `PORTAL_IMAGE` is empty
- WHEN group_vars is evaluated
- THEN `portal_image` is `nginx`

### Requirement: Per-role compose
Playbooks SHALL start Docker compose with study §6.4a limits on **existing** guests. Portal SHALL proxy `/api` to `REST_BASE_URL`. Haystack SHALL NOT start a Neo4j container. Neo4j SHALL start only `neo4j:5`.

#### Scenario: Haystack has no graph container
- GIVEN the haystack compose file
- WHEN it is rendered
- THEN it has no service named `neo4j`

#### Scenario: REST/Haystack image missing
- GIVEN no `image_http_url`, `IMAGE_HTTP_URL`, `image_ref`, or ECR image for rest or haystack
- WHEN Ansible configures that group
- THEN the play fails closed
- AND the playbook does not `docker build`

### Requirement: RDS logical only from rest or haystack
`CREATE EXTENSION vector` and grants SHALL run via `delegate_to` a rest or haystack guest. The Actions runner SHALL NOT open `:5432`.
