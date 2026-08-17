#!/usr/bin/env bash
# Build Secrets Manager JSON from terraform output + Environment app secrets.
# Never write Vocareum AWS keys. Never echo SecretString / sk_ / passwords.
set +x
set -euo pipefail

need() {
  local name="$1"
  local val="$2"
  if [ -z "${val}" ] || [ "${val}" = "null" ]; then
    echo "::error::sync-secrets: ${name} is empty."
    exit 1
  fi
}

tf() {
  terraform -chdir=terraform/academy output -raw "$1"
}

REST_DNS="$(tf rest_alb_dns)"
HAY_DNS="$(tf haystack_alb_dns)"
SOR_HOST="$(tf rds_endpoint)"
SOR_PORT="$(tf rds_port)"
SOR_DB="$(tf rds_database)"
HAY_HOST="$(tf rds_haystack_endpoint)"
HAY_PORT="$(tf rds_haystack_port)"
HAY_DB="$(tf rds_haystack_database)"
DB_USER="$(tf rds_username)"
NEO4J_URI="$(tf neo4j_uri)"

DB_PASS="${SPRING_DATASOURCE_PASSWORD:-}"
NEO4J_PASS="${NEO4J_PASSWORD:-}"
NEO4J_USER="${NEO4J_USER:-neo4j}"
PK="${STRIPE_PUBLISHABLE_KEY:-}"
SK="${STRIPE_API_KEY:-}"
WHSEC="${STRIPE_WEBHOOK_SECRET:-}"
LLM="${LLM_API_KEY:-}"

need REST_BASE_URL_host "${REST_DNS}"
need HAYSTACK_URL_host "${HAY_DNS}"
need POSTGRES_HOST "${SOR_HOST}"
need POSTGRES_PORT "${SOR_PORT}"
need POSTGRES_DATABASE "${SOR_DB}"
need POSTGRES_USERNAME "${DB_USER}"
need SPRING_DATASOURCE_PASSWORD "${DB_PASS}"
need haystack_POSTGRES_HOST "${HAY_HOST}"
need haystack_POSTGRES_DATABASE "${HAY_DB}"
need NEO4J_URI "${NEO4J_URI}"
need NEO4J_PASSWORD "${NEO4J_PASS}"
need STRIPE_PUBLISHABLE_KEY "${PK}"
need STRIPE_API_KEY "${SK}"
need STRIPE_WEBHOOK_SECRET "${WHSEC}"

echo "::add-mask::${DB_PASS}"
echo "::add-mask::${NEO4J_PASS}"
echo "::add-mask::${SK}"
echo "::add-mask::${WHSEC}"
[ -n "${LLM}" ] && echo "::add-mask::${LLM}"

REST_BASE_URL="http://${REST_DNS}:8080"
HAYSTACK_URL="http://${HAY_DNS}:8000"
SOR_JDBC="jdbc:postgresql://${SOR_HOST}:${SOR_PORT}/${SOR_DB}"
HAY_URL="postgresql://${DB_USER}:${DB_PASS}@${HAY_HOST}:${HAY_PORT}/${HAY_DB}"

put() {
  local id="$1"
  local file="$2"
  aws secretsmanager put-secret-value \
    --secret-id "${id}" \
    --secret-string "file://${file}" \
    >/dev/null
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

jq -n \
  --arg REST_BASE_URL "${REST_BASE_URL}" \
  --arg STRIPE_PUBLISHABLE_KEY "${PK}" \
  --arg VITE_STRIPE_PUBLISHABLE_KEY "${PK}" \
  '{
    REST_BASE_URL:$REST_BASE_URL,
    STRIPE_PUBLISHABLE_KEY:$STRIPE_PUBLISHABLE_KEY,
    VITE_STRIPE_PUBLISHABLE_KEY:$VITE_STRIPE_PUBLISHABLE_KEY
  }' \
  >"${WORKDIR}/portal.json"

jq -n \
  --arg POSTGRES_HOST "${SOR_HOST}" \
  --arg POSTGRES_PORT "${SOR_PORT}" \
  --arg POSTGRES_DATABASE "${SOR_DB}" \
  --arg POSTGRES_USERNAME "${DB_USER}" \
  --arg POSTGRES_PASSWORD "${DB_PASS}" \
  --arg POSTGRES_URL "${SOR_JDBC}" \
  --arg SPRING_DATASOURCE_URL "${SOR_JDBC}" \
  --arg SPRING_DATASOURCE_USERNAME "${DB_USER}" \
  --arg SPRING_DATASOURCE_PASSWORD "${DB_PASS}" \
  --arg HAYSTACK_URL "${HAYSTACK_URL}" \
  --arg STRIPE_PUBLISHABLE_KEY "${PK}" \
  --arg STRIPE_API_KEY "${SK}" \
  --arg STRIPE_WEBHOOK_SECRET "${WHSEC}" \
  '{
    POSTGRES_HOST:$POSTGRES_HOST,
    POSTGRES_PORT:$POSTGRES_PORT,
    POSTGRES_DATABASE:$POSTGRES_DATABASE,
    POSTGRES_USERNAME:$POSTGRES_USERNAME,
    POSTGRES_PASSWORD:$POSTGRES_PASSWORD,
    POSTGRES_URL:$POSTGRES_URL,
    SPRING_DATASOURCE_URL:$SPRING_DATASOURCE_URL,
    SPRING_DATASOURCE_USERNAME:$SPRING_DATASOURCE_USERNAME,
    SPRING_DATASOURCE_PASSWORD:$SPRING_DATASOURCE_PASSWORD,
    HAYSTACK_URL:$HAYSTACK_URL,
    STRIPE_PUBLISHABLE_KEY:$STRIPE_PUBLISHABLE_KEY,
    STRIPE_API_KEY:$STRIPE_API_KEY,
    STRIPE_WEBHOOK_SECRET:$STRIPE_WEBHOOK_SECRET
  }' >"${WORKDIR}/rest.json"

jq -n \
  --arg POSTGRES_HOST "${HAY_HOST}" \
  --arg POSTGRES_PORT "${HAY_PORT}" \
  --arg POSTGRES_DATABASE "${HAY_DB}" \
  --arg POSTGRES_USERNAME "${DB_USER}" \
  --arg POSTGRES_PASSWORD "${DB_PASS}" \
  --arg POSTGRES_URL "${HAY_URL}" \
  --arg DATABASE_URL "${HAY_URL}" \
  --arg NEO4J_URI "${NEO4J_URI}" \
  --arg NEO4J_USER "${NEO4J_USER}" \
  --arg NEO4J_PASSWORD "${NEO4J_PASS}" \
  --arg LLM_API_KEY "${LLM}" \
  --arg SOURCE_HOST "${SOR_HOST}" \
  --arg SOURCE_PORT "${SOR_PORT}" \
  --arg SOURCE_DATABASE "${SOR_DB}" \
  --arg TARGET_HOST "${HAY_HOST}" \
  --arg TARGET_PORT "${HAY_PORT}" \
  --arg TARGET_DATABASE "${HAY_DB}" \
  '{
    POSTGRES_HOST:$POSTGRES_HOST,
    POSTGRES_PORT:$POSTGRES_PORT,
    POSTGRES_DATABASE:$POSTGRES_DATABASE,
    POSTGRES_USERNAME:$POSTGRES_USERNAME,
    POSTGRES_PASSWORD:$POSTGRES_PASSWORD,
    POSTGRES_URL:$POSTGRES_URL,
    DATABASE_URL:$DATABASE_URL,
    NEO4J_URI:$NEO4J_URI,
    NEO4J_USER:$NEO4J_USER,
    NEO4J_PASSWORD:$NEO4J_PASSWORD,
    LLM_API_KEY:$LLM_API_KEY,
    SOURCE_HOST:$SOURCE_HOST,
    SOURCE_PORT:$SOURCE_PORT,
    SOURCE_DATABASE:$SOURCE_DATABASE,
    TARGET_HOST:$TARGET_HOST,
    TARGET_PORT:$TARGET_PORT,
    TARGET_DATABASE:$TARGET_DATABASE
  }' >"${WORKDIR}/haystack.json"

jq -n \
  --arg NEO4J_USER "${NEO4J_USER}" \
  --arg NEO4J_PASSWORD "${NEO4J_PASS}" \
  '{NEO4J_USER:$NEO4J_USER,NEO4J_PASSWORD:$NEO4J_PASSWORD}' \
  >"${WORKDIR}/neo4j.json"

# Refuse accidental Vocareum keys in the JSON we are about to write.
for f in portal rest haystack neo4j; do
  if jq -e 'to_entries[] | select(.key|test("AWS_";"i"))' "${WORKDIR}/${f}.json" >/dev/null; then
    echo "::error::Refusing to write AWS_* into Secrets Manager."
    exit 1
  fi
done

put "heavy-rental/portal" "${WORKDIR}/portal.json"
put "heavy-rental/rest" "${WORKDIR}/rest.json"
put "heavy-rental/haystack" "${WORKDIR}/haystack.json"
put "heavy-rental/neo4j" "${WORKDIR}/neo4j.json"

echo "Wrote heavy-rental/{portal,rest,haystack,neo4j}. SecretString not printed."
