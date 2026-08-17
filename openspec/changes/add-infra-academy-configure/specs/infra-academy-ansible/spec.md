# Delta for infra-academy-ansible

## Purpose

First compose on all four ASGs over SSM. App CD later reuses the same playbook, one group.

## ADDED Requirements

### Requirement: SSM inventory of four groups
Ansible SHALL inventory InService + SSM Online instances for `portal`, `rest`, `haystack`, and `neo4j`. Connection SHALL be AWS SSM. RDS SHALL NOT be an inventory host.

#### Scenario: Desired=2 discovers two guests per group
- GIVEN each ASG has two InService guests Online in SSM
- WHEN Ansible runs
- THEN each group has two hosts
- AND `ansible_host` is an instance id, not a public IP

### Requirement: Per-role compose
Playbooks SHALL start Docker compose with study §6.4a limits. Portal SHALL proxy `/api` to `REST_BASE_URL`. Haystack SHALL NOT start a Neo4j container. Neo4j SHALL start only `neo4j:5`.

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
