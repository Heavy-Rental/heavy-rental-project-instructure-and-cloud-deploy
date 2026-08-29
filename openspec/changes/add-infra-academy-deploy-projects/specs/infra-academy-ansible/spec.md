# Delta for infra-academy-ansible (`deploy-projects`)

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-bastion/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): `site.yml` still targets `portal` / `rest` / `haystack` / `neo4j` only. Inventory may list `bastion`; compose SHALL NOT.

## Purpose

Apply and configure-only stay on `configure.yml`. Only `deploy-projects` may invoke `site.yml`.

## MODIFIED Requirements

### Requirement: Infra CD does not compose app images on apply
Infra CD (`apply` and `configure-only`) SHALL run `playbooks/configure.yml`. It SHALL NOT invoke `site.yml`.

#### Scenario: Infra CD does not compose app images
- GIVEN `action` is `apply` or `configure-only`
- WHEN the Ansible step runs
- THEN it invokes `playbooks/configure.yml`
- AND it does not invoke `playbooks/site.yml`
- AND portal / rest / haystack compose roles do not run

### Requirement: deploy-projects is the only site.yml caller
`action=deploy-projects` SHALL invoke `playbooks/site.yml` and SHALL NOT invoke `playbooks/configure.yml`.

#### Scenario: deploy-projects runs site.yml
- GIVEN `action` is `deploy-projects` and image preflight succeeded
- WHEN the Ansible step runs
- THEN it invokes `playbooks/site.yml`
- AND it does not invoke `playbooks/configure.yml`

### Requirement: site.yml waits for REST and Haystack 2xx health
On `action=deploy-projects`, after compose, Ansible SHALL wait until `GET http://127.0.0.1:8080/actuator/health` returns HTTP **2xx** on REST guests and `GET http://127.0.0.1:8000/health` returns HTTP **2xx** on Haystack guests (same contract as ALB `tg-rest` / `tg-haystack` matcher `200-299`). `GET /` on REST (401) and `GET /` or `/docs` on Haystack SHALL NOT count as healthy.

#### Scenario: REST actuator 2xx
- GIVEN `site.yml` composed REST
- WHEN the REST health task finishes
- THEN `:8080/actuator/health` returned 2xx

#### Scenario: Haystack /health 2xx
- GIVEN `site.yml` composed Haystack
- WHEN the Haystack health task finishes
- THEN `:8000/health` returned 2xx
