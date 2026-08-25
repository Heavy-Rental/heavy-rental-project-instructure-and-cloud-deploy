# Delta for infra-academy-sync-secrets (public REST CORS)

## MODIFIED Requirements

### Requirement: Required app fields
On `action=apply` and `action=configure-only`, after Terraform has created the shells (or they already exist), the workflow SHALL `put-secret-value` for `heavy-rental/{portal,rest,haystack,neo4j}` with the fields in AWS study §8.2 as amended by ADR 0018.

`heavy-rental/portal` SHALL contain `REST_BASE_URL` equal to `http://<rest_alb_dns>:8080` (internet-facing REST ALB). `heavy-rental/rest` SHALL contain `APP_CORS_ALLOWED_ORIGINS` equal to `http://<portal_alb_dns>,http://<rest_alb_dns>:8080`. This **replaces** the CORS clause that listed only the portal origin.

#### Scenario: Portal and REST URLs come from Terraform
- GIVEN estate outputs exist
- WHEN `sync-secrets` runs
- THEN `heavy-rental/portal` contains `REST_BASE_URL` as `http://` plus the REST ALB DNS plus `:8080`
- AND `heavy-rental/rest` contains `APP_CORS_ALLOWED_ORIGINS` with the portal ALB `http://` origin and `http://` plus the REST ALB DNS plus `:8080`

#### Scenario: Direct browser origin is allowed
- GIVEN `sync-secrets` succeeded after a REST ALB replacement
- WHEN `heavy-rental/rest` is read
- THEN `APP_CORS_ALLOWED_ORIGINS` includes the **new** REST ALB DNS on :8080
- AND Vocareum `AWS_*` keys are not written to Secrets Manager
