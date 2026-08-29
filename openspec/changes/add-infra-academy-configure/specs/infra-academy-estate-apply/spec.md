# Delta for infra-academy-estate-apply (branch 3)

> **Later modified by** [`add-infra-academy-deploy-projects`](../../../add-infra-academy-deploy-projects/specs/infra-academy-ansible/spec.md): apply Ansible is `configure.yml` (Docker + Neo4j only). Missing REST/Haystack images do **not** fail apply. `site.yml` is a later `deploy-projects` run.  
> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-bastion/spec.md): compose targets the four app groups only; inventory may list `bastion`.

## Purpose

`action=apply` still creates the estate, then configures guests (`configure.yml`).

## MODIFIED Requirements

### Requirement: Apply continues to configure
After a successful estate apply, the workflow SHALL run `sync-secrets`, `sync-ssh-keys`, and Ansible.

#### Scenario: Apply is not estate-only
- GIVEN `action=apply` and Terraform apply succeeded
- WHEN the workflow finishes
- THEN `sync-secrets` has written required JSON
- AND Ansible has run `configure.yml` against the four app groups (Docker + Neo4j). **Current:** missing REST/Haystack images do not fail this action (banner).
