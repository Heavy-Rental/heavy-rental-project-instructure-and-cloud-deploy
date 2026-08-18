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

PORTAL_DNS="$(tf portal_alb_dns)"
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
OM_EMAIL="${ONEMAP_EMAIL:-}"
OM_PASS="${ONEMAP_PASSWORD:-}"

# APP_JWT_SECRET: Environment override, else reuse SM, else generate once (HS256 ≥ 32).
JWT="${APP_JWT_SECRET:-}"
if [ -n "${JWT}" ]; then
  if [ "${#JWT}" -lt 32 ]; then
    echo "::error::APP_JWT_SECRET from Environment must be at least 32 characters (HS256)."
    exit 1
  fi
  echo "APP_JWT_SECRET: using Environment secret."
else
  existing_rest="$(aws secretsmanager get-secret-value --secret-id heavy-rental/rest \
    --query SecretString --output text 2>/dev/null || true)"
  from_sm="$(printf '%s' "${existing_rest}" | jq -r '.APP_JWT_SECRET // empty' 2>/dev/null || true)"
  if [ "${#from_sm}" -ge 32 ] && [ "${from_sm}" != "change-me-to-a-long-random-secret-key!!" ]; then
    JWT="${from_sm}"
    echo "APP_JWT_SECRET: reusing existing Secrets Manager value."
  else
    JWT="$(openssl rand -base64 48 | tr -d '\n')"
    echo "APP_JWT_SECRET: generated (≥32 chars). SecretString not printed."
  fi
fi

need PORTAL_ALB_host "${PORTAL_DNS}"
need REST_BASE_URL_host "${REST_DNS}"
need HAYSTACK_BASE_URL_host "${HAY_DNS}"
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
need APP_JWT_SECRET "${JWT}"

if [ -n "${OM_EMAIL}" ] || [ -n "${OM_PASS}" ]; then
  if [ -z "${OM_EMAIL}" ] || [ -z "${OM_PASS}" ]; then
    echo "::error::ONEMAP_EMAIL and ONEMAP_PASSWORD must both be set or both empty."
    exit 1
  fi
fi

echo "::add-mask::${DB_PASS}"
echo "::add-mask::${NEO4J_PASS}"
echo "::add-mask::${SK}"
echo "::add-mask::${WHSEC}"
echo "::add-mask::${JWT}"
[ -n "${LLM}" ] && echo "::add-mask::${LLM}"
[ -n "${OM_PASS}" ] && echo "::add-mask::${OM_PASS}"

REST_BASE_URL="http://${REST_DNS}:8080"
HAYSTACK_BASE_URL="http://${HAY_DNS}:8000"
# Public portal ALB :80. Same-origin /api does not need this; direct browser→REST does.
APP_CORS_ALLOWED_ORIGINS="http://${PORTAL_DNS}"
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
  --arg POSTGRES_HOSTNAME "${SOR_HOST}" \
  --arg POSTGRES_DB "${SOR_DB}" \
  --arg POSTGRES_USER "${DB_USER}" \
  --arg HAYSTACK_BASE_URL "${HAYSTACK_BASE_URL}" \
  --arg STRIPE_PUBLISHABLE_KEY "${PK}" \
  --arg STRIPE_API_KEY "${SK}" \
  --arg STRIPE_WEBHOOK_SECRET "${WHSEC}" \
  --arg APP_JWT_SECRET "${JWT}" \
  --arg APP_CORS_ALLOWED_ORIGINS "${APP_CORS_ALLOWED_ORIGINS}" \
  '{
    POSTGRES_HOST:$POSTGRES_HOST,
    POSTGRES_HOSTNAME:$POSTGRES_HOSTNAME,
    POSTGRES_PORT:$POSTGRES_PORT,
    POSTGRES_DATABASE:$POSTGRES_DATABASE,
    POSTGRES_DB:$POSTGRES_DB,
    POSTGRES_USERNAME:$POSTGRES_USERNAME,
    POSTGRES_USER:$POSTGRES_USER,
    POSTGRES_PASSWORD:$POSTGRES_PASSWORD,
    POSTGRES_URL:$POSTGRES_URL,
    SPRING_DATASOURCE_URL:$SPRING_DATASOURCE_URL,
    SPRING_DATASOURCE_USERNAME:$SPRING_DATASOURCE_USERNAME,
    SPRING_DATASOURCE_PASSWORD:$SPRING_DATASOURCE_PASSWORD,
    HAYSTACK_BASE_URL:$HAYSTACK_BASE_URL,
    STRIPE_PUBLISHABLE_KEY:$STRIPE_PUBLISHABLE_KEY,
    STRIPE_API_KEY:$STRIPE_API_KEY,
    STRIPE_WEBHOOK_SECRET:$STRIPE_WEBHOOK_SECRET,
    APP_JWT_SECRET:$APP_JWT_SECRET,
    APP_CORS_ALLOWED_ORIGINS:$APP_CORS_ALLOWED_ORIGINS
  }' >"${WORKDIR}/rest.json"

if [ -n "${OM_EMAIL}" ]; then
  jq --arg ONEMAP_EMAIL "${OM_EMAIL}" --arg ONEMAP_PASSWORD "${OM_PASS}" \
    '. + {ONEMAP_EMAIL:$ONEMAP_EMAIL, ONEMAP_PASSWORD:$ONEMAP_PASSWORD}' \
    "${WORKDIR}/rest.json" >"${WORKDIR}/rest.onemap.json"
  mv "${WORKDIR}/rest.onemap.json" "${WORKDIR}/rest.json"
  echo "ONEMAP_EMAIL / ONEMAP_PASSWORD: written from Environment secrets."
else
  echo "ONEMAP_EMAIL / ONEMAP_PASSWORD: unset; not written (Spring defaults / distance lookup may fail)."
fi

# Optional pricing knobs (Spring DYNAMIC_PRICING_* / PRICING_*). Empty = omit (app defaults).
pricing_json="{}"
for key in DYNAMIC_PRICING_ENABLED PRICING_DEFAULT_DISTANCE_KM PRICING_ORIGIN_POSTAL_CODE PRICING_DISTANCE_LOOKUP_ENABLED; do
  val="${!key:-}"
  if [ -n "${val}" ]; then
    pricing_json="$(jq --arg k "${key}" --arg v "${val}" '. + {($k):$v}' <<<"${pricing_json}")"
  fi
done
if [ "${pricing_json}" != "{}" ]; then
  jq --argjson extra "${pricing_json}" '. + $extra' "${WORKDIR}/rest.json" >"${WORKDIR}/rest.pricing.json"
  mv "${WORKDIR}/rest.pricing.json" "${WORKDIR}/rest.json"
  echo "Pricing knobs: written from Environment variables."
else
  echo "Pricing knobs: unset; Spring application.properties defaults apply."
fi

jq -n \
  --arg POSTGRES_HOST "${HAY_HOST}" \
  --arg POSTGRES_PORT "${HAY_PORT}" \
  --arg POSTGRES_DATABASE "${HAY_DB}" \
  --arg POSTGRES_USERNAME "${DB_USER}" \
  --arg POSTGRES_HOSTNAME "${HAY_HOST}" \
  --arg POSTGRES_DB "${HAY_DB}" \
  --arg POSTGRES_USER "${DB_USER}" \
  --arg POSTGRES_PASSWORD "${DB_PASS}" \
  --arg POSTGRES_URL "${HAY_URL}" \
  --arg DATABASE_URL "${HAY_URL}" \
  --arg NEO4J_URI "${NEO4J_URI}" \
  --arg NEO4J_USER "${NEO4J_USER}" \
  --arg NEO4J_PASSWORD "${NEO4J_PASS}" \
  --arg FLEET_BACKEND "sql" \
  --arg NEO4J_BACKEND "bolt" \
  --arg NEO4J_POPULATE_URL "http://neo4j-populate:8089/v1/populate" \
  --arg LLM_API_KEY "${LLM}" \
  --arg SOURCE_HOST "${SOR_HOST}" \
  --arg SOURCE_PORT "${SOR_PORT}" \
  --arg SOURCE_DATABASE "${SOR_DB}" \
  --arg TARGET_HOST "${HAY_HOST}" \
  --arg TARGET_PORT "${HAY_PORT}" \
  --arg TARGET_DATABASE "${HAY_DB}" \
  '{
    POSTGRES_HOST:$POSTGRES_HOST,
    POSTGRES_HOSTNAME:$POSTGRES_HOSTNAME,
    POSTGRES_PORT:$POSTGRES_PORT,
    POSTGRES_DATABASE:$POSTGRES_DATABASE,
    POSTGRES_DB:$POSTGRES_DB,
    POSTGRES_USERNAME:$POSTGRES_USERNAME,
    POSTGRES_USER:$POSTGRES_USER,
    POSTGRES_PASSWORD:$POSTGRES_PASSWORD,
    POSTGRES_URL:$POSTGRES_URL,
    DATABASE_URL:$DATABASE_URL,
    NEO4J_URI:$NEO4J_URI,
    NEO4J_USER:$NEO4J_USER,
    NEO4J_PASSWORD:$NEO4J_PASSWORD,
    FLEET_BACKEND:$FLEET_BACKEND,
    NEO4J_BACKEND:$NEO4J_BACKEND,
    NEO4J_POPULATE_URL:$NEO4J_POPULATE_URL,
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
