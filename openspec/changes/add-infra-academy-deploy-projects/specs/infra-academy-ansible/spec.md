# Delta for infra-academy-ansible (`deploy-projects`)

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
