#!/usr/bin/env bash
# Bind existing estate objects into Terraform state so plan/apply can
# be re-run after lost state or a partial apply.
# Does not create AWS resources. Writes only terraform state (imports).
#
# Requires DEPLOYMENT=academy|actual (workflow env). Observe leftovers
# (trail / dashboard / flow-log) use that profile's names. VPC tag and RDS
# identifiers stay Terraform names (heavy-rental-academy) on both profiles.
#
# ESTATE_ON_VPC_FORK=fail|continue  (fail is default; destroy uses continue)
# ESTATE_IMPORT_STRICT=true|false   (destroy sets false so a bad import cannot block sweep)
set -euo pipefail

case "${DEPLOYMENT:-}" in
  academy|actual) ;;
  *)
    echo "::error::reconcile-estate: set DEPLOYMENT to academy or actual."
    exit 1
    ;;
esac
OBSERVE_NAME="heavy-rental-${DEPLOYMENT}"
OBSERVE_FLOW="${OBSERVE_NAME}-flow"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${ROOT}/terraform/academy"
ON_FORK="${ESTATE_ON_VPC_FORK:-fail}"
IMPORT_STRICT="${ESTATE_IMPORT_STRICT:-true}"

cd "${TF_DIR}"

in_state() {
  terraform state show -no-color -lock-timeout=2m "$1" >/dev/null 2>&1
}

aws_text() {
  aws "$@" --output text 2>/dev/null || true
}

import_one() {
  local addr="$1"
  local id="${2:-}"
  local out rc
  if [ -z "${id}" ] || [ "${id}" = "None" ] || [ "${id}" = "none" ]; then
    return 0
  fi
  if in_state "${addr}"; then
    echo "state already has ${addr}"
    return 0
  fi
  echo "terraform import ${addr}"
  set +e
  out="$(terraform import -input=false -no-color -lock-timeout=2m "${addr}" "${id}" 2>&1)"
  rc=$?
  set -e
  printf '%s\n' "${out}"
  if [ "${rc}" -eq 0 ]; then
    return 0
  fi
  # Address already bound (common for name_prefix launch templates: ASG/newest
  # lt-* id differs from the id already in state). Reconcile must not fail.
  if printf '%s\n' "${out}" | grep -Fq 'Resource already managed by Terraform'; then
    echo "state already has ${addr}; leaving existing binding"
    return 0
  fi
  if [ "${IMPORT_STRICT}" = "true" ]; then
    echo "::error::terraform import ${addr} failed (id=${id})."
    exit 1
  fi
  echo "::warning::terraform import ${addr} failed (id=${id}); continuing."
}

wait_rds_idle() {
  local id="$1"
  local deadline=$((SECONDS + 1500))
  local status
  while [ "${SECONDS}" -lt "${deadline}" ]; do
    status="$(aws rds describe-db-instances --db-instance-identifier "${id}" \
      --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo missing)"
    case "${status}" in
      missing|available|stopped|storage-optimization)
        echo "RDS ${id}: ${status}"
        return 0
        ;;
      deleting)
        echo "RDS ${id}: deleting; waiting."
        ;;
      *)
        echo "RDS ${id}: ${status}; waiting until idle."
        ;;
    esac
    sleep 20
  done
  echo "::warning::RDS ${id} still ${status:-unknown} after wait. Import may fail."
}

restore_secret_if_deleted() {
  local name="$1"
  local deleted
  deleted="$(aws secretsmanager describe-secret --secret-id "${name}" \
    --query 'DeletedDate' --output text 2>/dev/null || echo none)"
  if [ -n "${deleted}" ] && [ "${deleted}" != "None" ] && [ "${deleted}" != "none" ]; then
    echo "Restoring secret ${name} (was pending deletion)."
    aws secretsmanager restore-secret --secret-id "${name}" >/dev/null
  fi
}

subnet_id_by_cidr() {
  local vpc="$1"
  local cidr="$2"
  aws_text ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${vpc}" "Name=cidr-block,Values=${cidr}" \
    --query 'Subnets[0].SubnetId'
}

sg_id_by_name() {
  local vpc="$1"
  local name="$2"
  aws_text ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${vpc}" "Name=group-name,Values=${name}" \
    --query 'SecurityGroups[0].GroupId'
}

rtb_id_by_name() {
  local vpc="$1"
  local name="$2"
  aws_text ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=${vpc}" "Name=tag:Name,Values=${name}" \
    --query 'RouteTables[0].RouteTableId'
}

# AWS provider import id is "subnet-id/route-table-id", not rtbassoc-*.
assoc_import_id() {
  local rtb="$1"
  local subnet="$2"
  local assoc
  if [ -z "${rtb}" ] || [ "${rtb}" = "None" ] || [ -z "${subnet}" ] || [ "${subnet}" = "None" ]; then
    return 0
  fi
  assoc="$(aws_text ec2 describe-route-tables --route-table-ids "${rtb}" \
    --query "RouteTables[0].Associations[?SubnetId==\`${subnet}\`].RouteTableAssociationId | [0]")"
  if [ -z "${assoc}" ] || [ "${assoc}" = "None" ]; then
    return 0
  fi
  printf '%s/%s\n' "${subnet}" "${rtb}"
}

lb_arn_by_name() {
  aws_text elbv2 describe-load-balancers --names "$1" \
    --query 'LoadBalancers[0].LoadBalancerArn'
}

tg_arn_by_name() {
  aws_text elbv2 describe-target-groups --names "$1" \
    --query 'TargetGroups[0].TargetGroupArn'
}

listener_arn() {
  local lb_arn="$1"
  local port="$2"
  aws_text elbv2 describe-listeners --load-balancer-arn "${lb_arn}" \
    --query "Listeners[?Port==${port}].ListenerArn | [0]"
}

asg_exists() {
  local name="$1"
  local got
  got="$(aws_text autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${name}" \
    --query 'AutoScalingGroups[0].AutoScalingGroupName')"
  [ "${got}" = "${name}" ]
}

asg_lt_id() {
  local name="$1"
  aws_text autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${name}" \
    --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId'
}

newest_lt_prefix() {
  local prefix="$1"
  aws ec2 describe-launch-templates --output json \
    | jq -r --arg p "${prefix}" '
        [.LaunchTemplates[]? | select(.LaunchTemplateName | startswith($p))]
        | sort_by(.CreateTime) | last | .LaunchTemplateId // empty'
}

list_estate_vpcs() {
  aws_text ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=heavy-rental-academy" \
    --query 'Vpcs[].VpcId' | tr '\t' ' '
}

import_account_scoped() {
  local repo secret
  for repo in heavy-rental-web-portal heavy-rental-rest-api heavy-rental-haystack heavy-rental-neo4j; do
    if aws ecr describe-repositories --repository-names "${repo}" >/dev/null 2>&1; then
      import_one "aws_ecr_repository.app[\"${repo}\"]" "${repo}"
    fi
  done

  for secret in \
    heavy-rental/portal heavy-rental/rest heavy-rental/haystack heavy-rental/neo4j \
    heavy-rental/ssh/portal heavy-rental/ssh/rest heavy-rental/ssh/haystack heavy-rental/ssh/neo4j \
    heavy-rental/ssh/bastion
  do
    if aws secretsmanager describe-secret --secret-id "${secret}" >/dev/null 2>&1; then
      restore_secret_if_deleted "${secret}"
      import_one "aws_secretsmanager_secret.app[\"${secret}\"]" "${secret}"
    fi
  done

  import_observe
}

import_observe() {
  local account bucket trail topic dash app key flow
  account="$(aws_text sts get-caller-identity --query Account)"
  bucket="heavy-rental-observe-${account}-${DEPLOYMENT}"
  if aws s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1; then
    import_one aws_s3_bucket.observe "${bucket}"
    import_one aws_s3_bucket_public_access_block.observe "${bucket}"
    import_one aws_s3_bucket_server_side_encryption_configuration.observe "${bucket}"
    import_one aws_s3_bucket_lifecycle_configuration.observe "${bucket}"
    import_one aws_s3_bucket_policy.observe "${bucket}"
  fi

  trail="$(aws_text cloudtrail get-trail --name "${OBSERVE_NAME}" --query 'Trail.Name')"
  import_one aws_cloudtrail.academy "${trail}"

  topic="$(aws_text sns list-topics --query "Topics[?contains(TopicArn, ':hr-academy-alarms')].TopicArn | [0]")"
  import_one aws_sns_topic.alarms "${topic}"

  dash="$(aws_text cloudwatch list-dashboards --query "DashboardEntries[?DashboardName==\`${OBSERVE_NAME}\`].DashboardName | [0]")"
  import_one aws_cloudwatch_dashboard.estate "${dash}"

  for app in portal rest haystack neo4j; do
    if aws logs describe-log-groups --log-group-name-prefix "/heavy-rental/${app}" \
      --query "logGroups[?logGroupName==\`/heavy-rental/${app}\`].logGroupName | [0]" \
      --output text 2>/dev/null | grep -q "/heavy-rental/${app}"; then
      import_one "aws_cloudwatch_log_group.app[\"${app}\"]" "/heavy-rental/${app}"
    fi
  done

  for key in portal rest haystack; do
    if aws cloudwatch describe-alarms --alarm-names "hr-alb-${key}-5xx" \
      --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-alb-${key}-5xx"; then
      import_one "aws_cloudwatch_metric_alarm.alb_5xx[\"${key}\"]" "hr-alb-${key}-5xx"
    fi
    if aws cloudwatch describe-alarms --alarm-names "hr-alb-${key}-unhealthy" \
      --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-alb-${key}-unhealthy"; then
      import_one "aws_cloudwatch_metric_alarm.alb_unhealthy[\"${key}\"]" "hr-alb-${key}-unhealthy"
    fi
  done
  for key in sor haystack; do
    if aws cloudwatch describe-alarms --alarm-names "hr-rds-${key}-cpu" \
      --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-rds-${key}-cpu"; then
      import_one "aws_cloudwatch_metric_alarm.rds_cpu[\"${key}\"]" "hr-rds-${key}-cpu"
    fi
    if aws cloudwatch describe-alarms --alarm-names "hr-rds-${key}-storage" \
      --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-rds-${key}-storage"; then
      import_one "aws_cloudwatch_metric_alarm.rds_storage[\"${key}\"]" "hr-rds-${key}-storage"
    fi
  done
  for key in portal rest haystack neo4j; do
    if aws cloudwatch describe-alarms --alarm-names "hr-asg-${key}-inservice" \
      --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-asg-${key}-inservice"; then
      import_one "aws_cloudwatch_metric_alarm.asg_inservice[\"${key}\"]" "hr-asg-${key}-inservice"
    fi
  done
  if aws cloudwatch describe-alarms --alarm-names "hr-bastion-status" \
    --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "hr-bastion-status"; then
    import_one "aws_cloudwatch_metric_alarm.bastion_status" "hr-bastion-status"
  fi

  flow="$(aws_text ec2 describe-flow-logs \
    --filter Name=tag:Name,Values="${OBSERVE_FLOW}" \
    --query 'FlowLogs[0].FlowLogId')"
  import_one aws_flow_log.academy "${flow}"
}

import_unique_regional() {
  local name arn
  for name in asg-portal asg-rest asg-haystack asg-neo4j; do
    if asg_exists "${name}"; then
      import_one "aws_autoscaling_group.${name#asg-}" "${name}"
    fi
  done

  import_one aws_instance.bastion "$(aws_text ec2 describe-instances \
    --filters "Name=tag:Name,Values=hr-bastion" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId | [0]')"

  if aws rds describe-db-subnet-groups --db-subnet-group-name heavy-rental-data >/dev/null 2>&1; then
    import_one aws_db_subnet_group.data heavy-rental-data
  fi
  if aws rds describe-db-instances --db-instance-identifier heavy-rental-academy >/dev/null 2>&1; then
    import_one aws_db_instance.heavy_rental heavy-rental-academy
  fi
  if aws rds describe-db-instances --db-instance-identifier heavy-rental-haystack-academy >/dev/null 2>&1; then
    import_one aws_db_instance.haystack heavy-rental-haystack-academy
  fi

  for name in hr-alb-portal hr-alb-rest hr-alb-haystack hr-nlb-neo4j; do
    arn="$(lb_arn_by_name "${name}")"
    case "${name}" in
      hr-alb-portal) import_one aws_lb.portal "${arn}" ;;
      hr-alb-rest) import_one aws_lb.rest "${arn}" ;;
      hr-alb-haystack) import_one aws_lb.haystack "${arn}" ;;
      hr-nlb-neo4j) import_one aws_lb.neo4j "${arn}" ;;
    esac
  done

  for name in tg-portal tg-rest tg-haystack tg-neo4j; do
    arn="$(tg_arn_by_name "${name}")"
    import_one "aws_lb_target_group.${name#tg-}" "${arn}"
  done
}

import_listeners_and_lts() {
  local arn lt
  arn="$(lb_arn_by_name hr-alb-portal)"
  import_one aws_lb_listener.portal_http "$(listener_arn "${arn}" 80)"
  arn="$(lb_arn_by_name hr-alb-rest)"
  import_one aws_lb_listener.rest "$(listener_arn "${arn}" 8080)"
  arn="$(lb_arn_by_name hr-alb-haystack)"
  import_one aws_lb_listener.haystack "$(listener_arn "${arn}" 8000)"
  arn="$(lb_arn_by_name hr-nlb-neo4j)"
  import_one aws_lb_listener.neo4j_bolt "$(listener_arn "${arn}" 7687)"

  for name in portal rest haystack neo4j; do
    lt=""
    if asg_exists "asg-${name}"; then
      lt="$(asg_lt_id "asg-${name}")"
    fi
    if [ -z "${lt}" ] || [ "${lt}" = "None" ]; then
      lt="$(newest_lt_prefix "lt-${name}-")"
    fi
    import_one "aws_launch_template.${name}" "${lt}"
  done
}

import_network() {
  local vpc="$1"
  local i cidr subnet az rtb assoc nat eip vpce igw
  local -a public_cidrs=("10.0.0.0/24" "10.0.1.0/24")
  local -a app_cidrs=("10.0.10.0/24" "10.0.11.0/24")
  local -a data_cidrs=("10.0.20.0/24" "10.0.21.0/24")
  local -a azs=()

  import_one aws_vpc.academy "${vpc}"

  igw="$(aws_text ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=${vpc}" \
    --query 'InternetGateways[0].InternetGatewayId')"
  import_one aws_internet_gateway.academy "${igw}"

  for i in 0 1; do
    subnet="$(subnet_id_by_cidr "${vpc}" "${public_cidrs[$i]}")"
    import_one "aws_subnet.public[${i}]" "${subnet}"
    az=""
    if [ -n "${subnet}" ] && [ "${subnet}" != "None" ]; then
      az="$(aws_text ec2 describe-subnets --subnet-ids "${subnet}" --query 'Subnets[0].AvailabilityZone')"
    fi
    azs+=("${az}")

    eip="$(aws_text ec2 describe-addresses \
      --filters "Name=tag:Name,Values=eip-nat-${az}" \
      --query 'Addresses[0].AllocationId')"
    if [ -z "${eip}" ] || [ "${eip}" = "None" ]; then
      eip="$(aws_text ec2 describe-nat-gateways \
        --filter "Name=subnet-id,Values=${subnet}" "Name=state,Values=available,pending" \
        --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId')"
    fi
    import_one "aws_eip.nat[${i}]" "${eip}"

    nat="$(aws_text ec2 describe-nat-gateways \
      --filter "Name=subnet-id,Values=${subnet}" "Name=state,Values=available,pending" \
      --query 'NatGateways[0].NatGatewayId')"
    if [ -z "${nat}" ] || [ "${nat}" = "None" ]; then
      nat="$(aws_text ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${vpc}" "Name=tag:Name,Values=natgw-${az}" \
          "Name=state,Values=available,pending" \
        --query 'NatGateways[0].NatGatewayId')"
    fi
    import_one "aws_nat_gateway.this[${i}]" "${nat}"
  done

  for i in 0 1; do
    import_one "aws_subnet.app[${i}]" "$(subnet_id_by_cidr "${vpc}" "${app_cidrs[$i]}")"
    import_one "aws_subnet.data[${i}]" "$(subnet_id_by_cidr "${vpc}" "${data_cidrs[$i]}")"
  done

  rtb="$(rtb_id_by_name "${vpc}" rt-public)"
  import_one aws_route_table.public "${rtb}"
  if [ -n "${rtb}" ] && [ "${rtb}" != "None" ]; then
    import_one aws_route.public_internet "${rtb}_0.0.0.0/0"
    for i in 0 1; do
      subnet="$(subnet_id_by_cidr "${vpc}" "${public_cidrs[$i]}")"
      import_one "aws_route_table_association.public[${i}]" "$(assoc_import_id "${rtb}" "${subnet}")"
    done
  fi

  for i in 0 1; do
    rtb="$(rtb_id_by_name "${vpc}" "rt-app-${azs[$i]}")"
    import_one "aws_route_table.app[${i}]" "${rtb}"
    if [ -n "${rtb}" ] && [ "${rtb}" != "None" ]; then
      import_one "aws_route.app_nat[${i}]" "${rtb}_0.0.0.0/0"
      subnet="$(subnet_id_by_cidr "${vpc}" "${app_cidrs[$i]}")"
      import_one "aws_route_table_association.app[${i}]" "$(assoc_import_id "${rtb}" "${subnet}")"
    fi

    rtb="$(rtb_id_by_name "${vpc}" "rt-data-${azs[$i]}")"
    import_one "aws_route_table.data[${i}]" "${rtb}"
    if [ -n "${rtb}" ] && [ "${rtb}" != "None" ]; then
      import_one "aws_route.data_nat[${i}]" "${rtb}_0.0.0.0/0"
      subnet="$(subnet_id_by_cidr "${vpc}" "${data_cidrs[$i]}")"
      import_one "aws_route_table_association.data[${i}]" "$(assoc_import_id "${rtb}" "${subnet}")"
    fi
  done

  vpce="$(aws_text ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=${vpc}" "Name=service-name,Values=com.amazonaws.${AWS_DEFAULT_REGION:-us-east-1}.s3" \
    --query 'VpcEndpoints[0].VpcEndpointId')"
  import_one aws_vpc_endpoint.s3 "${vpce}"
}

import_security_groups() {
  local vpc="$1"
  local key name
  declare -A NAMES=(
    [alb_public]=hr-alb-public
    [alb_rest]=hr-alb-rest
    [alb_haystack]=hr-alb-haystack
    [portal]=hr-portal
    [rest]=hr-rest
    [haystack]=hr-haystack
    [rds]=hr-rds
    [neo4j]=hr-neo4j
    [bastion]=hr-bastion
  )
  declare -A IDS=()
  for key in "${!NAMES[@]}"; do
    name="${NAMES[$key]}"
    IDS[$key]="$(sg_id_by_name "${vpc}" "${name}")"
    import_one "aws_security_group.${key}" "${IDS[$key]}"
  done

  # addr|owner_key|egress(0/1)|proto|from|to|peer  peer is cidr:X or sg:key
  local row addr owner egress proto from to peer peer_val rule_id is_egress
  while IFS='|' read -r addr owner egress proto from to peer; do
    [ -n "${addr}" ] || continue
    if [ -z "${IDS[$owner]:-}" ] || [ "${IDS[$owner]}" = "None" ]; then
      continue
    fi
    if [[ "${peer}" == cidr:* ]]; then
      peer_val="${peer#cidr:}"
      is_egress="${egress}"
      rule_id="$(aws ec2 describe-security-group-rules \
        --filters "Name=group-id,Values=${IDS[$owner]}" --output json \
        | jq -r --argjson eg "${is_egress}" --arg proto "${proto}" \
            --arg from "${from}" --arg to "${to}" --arg cidr "${peer_val}" '
            .SecurityGroupRules[]
            | select(.IsEgress == ($eg == 1)
                and .IpProtocol == $proto
                and ((.FromPort // -1) | tostring) == $from
                and ((.ToPort // -1) | tostring) == $to
                and .CidrIpv4 == $cidr)
            | .SecurityGroupRuleId' | head -n 1)"
    else
      peer_val="${IDS[${peer#sg:}]:-}"
      [ -n "${peer_val}" ] && [ "${peer_val}" != "None" ] || continue
      rule_id="$(aws ec2 describe-security-group-rules \
        --filters "Name=group-id,Values=${IDS[$owner]}" --output json \
        | jq -r --argjson eg "${egress}" --arg proto "${proto}" \
            --arg from "${from}" --arg to "${to}" --arg ref "${peer_val}" '
            .SecurityGroupRules[]
            | select(.IsEgress == ($eg == 1)
                and .IpProtocol == $proto
                and ((.FromPort // -1) | tostring) == $from
                and ((.ToPort // -1) | tostring) == $to
                and .ReferencedGroupInfo.GroupId == $ref)
            | .SecurityGroupRuleId' | head -n 1)"
    fi
    import_one "${addr}" "${rule_id}"
  done <<'RULES'
aws_vpc_security_group_ingress_rule.alb_public_http|alb_public|0|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.alb_public_to_portal|alb_public|1|tcp|80|80|sg:portal
aws_vpc_security_group_ingress_rule.portal_from_alb|portal|0|tcp|80|80|sg:alb_public
aws_vpc_security_group_egress_rule.portal_to_rest_alb|portal|1|tcp|8080|8080|sg:alb_rest
aws_vpc_security_group_egress_rule.portal_to_rest_public|portal|1|tcp|8080|8080|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.portal_https|portal|1|tcp|443|443|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.portal_http|portal|1|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_ingress_rule.alb_rest_from_portal|alb_rest|0|tcp|8080|8080|sg:portal
aws_vpc_security_group_ingress_rule.alb_rest_health|alb_rest|0|tcp|8080|8080|sg:alb_rest
aws_vpc_security_group_egress_rule.alb_rest_to_rest|alb_rest|1|tcp|8080|8080|sg:rest
aws_vpc_security_group_ingress_rule.rest_from_alb|rest|0|tcp|8080|8080|sg:alb_rest
aws_vpc_security_group_egress_rule.rest_to_rds|rest|1|tcp|5432|5432|sg:rds
aws_vpc_security_group_egress_rule.rest_to_haystack_alb|rest|1|tcp|8000|8000|sg:alb_haystack
aws_vpc_security_group_egress_rule.rest_https|rest|1|tcp|443|443|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.rest_http|rest|1|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_ingress_rule.alb_haystack_from_rest|alb_haystack|0|tcp|8000|8000|sg:rest
aws_vpc_security_group_egress_rule.alb_haystack_to_haystack|alb_haystack|1|tcp|8000|8000|sg:haystack
aws_vpc_security_group_ingress_rule.haystack_from_alb|haystack|0|tcp|8000|8000|sg:alb_haystack
aws_vpc_security_group_egress_rule.haystack_to_rds|haystack|1|tcp|5432|5432|sg:rds
aws_vpc_security_group_egress_rule.haystack_to_neo4j_bolt|haystack|1|tcp|7687|7687|sg:neo4j
aws_vpc_security_group_egress_rule.haystack_to_neo4j_browser|haystack|1|tcp|7474|7474|sg:neo4j
aws_vpc_security_group_egress_rule.haystack_https|haystack|1|tcp|443|443|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.haystack_http|haystack|1|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_ingress_rule.rds_from_rest|rds|0|tcp|5432|5432|sg:rest
aws_vpc_security_group_ingress_rule.rds_from_haystack|rds|0|tcp|5432|5432|sg:haystack
aws_vpc_security_group_ingress_rule.neo4j_bolt_from_haystack|neo4j|0|tcp|7687|7687|sg:haystack
aws_vpc_security_group_ingress_rule.neo4j_bolt_from_vpc|neo4j|0|tcp|7687|7687|cidr:10.0.0.0/16
aws_vpc_security_group_ingress_rule.neo4j_browser_from_haystack|neo4j|0|tcp|7474|7474|sg:haystack
aws_vpc_security_group_egress_rule.neo4j_https|neo4j|1|tcp|443|443|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.neo4j_http|neo4j|1|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.bastion_https|bastion|1|tcp|443|443|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.bastion_http|bastion|1|tcp|80|80|cidr:0.0.0.0/0
aws_vpc_security_group_egress_rule.bastion_ssh_to_portal|bastion|1|tcp|22|22|sg:portal
aws_vpc_security_group_egress_rule.bastion_ssh_to_rest|bastion|1|tcp|22|22|sg:rest
aws_vpc_security_group_egress_rule.bastion_ssh_to_haystack|bastion|1|tcp|22|22|sg:haystack
aws_vpc_security_group_egress_rule.bastion_ssh_to_neo4j|bastion|1|tcp|22|22|sg:neo4j
aws_vpc_security_group_ingress_rule.portal_ssh_from_bastion|portal|0|tcp|22|22|sg:bastion
aws_vpc_security_group_ingress_rule.rest_ssh_from_bastion|rest|0|tcp|22|22|sg:bastion
aws_vpc_security_group_ingress_rule.haystack_ssh_from_bastion|haystack|0|tcp|22|22|sg:bastion
aws_vpc_security_group_ingress_rule.neo4j_ssh_from_bastion|neo4j|0|tcp|22|22|sg:bastion
RULES
}

# --- main ---
if [ ! -d .terraform ]; then
  echo "::error::reconcile-estate: run terraform init first."
  exit 1
fi

wait_rds_idle heavy-rental-academy
wait_rds_idle heavy-rental-haystack-academy

VPCS="$(list_estate_vpcs)"
VPC_COUNT=0
if [ -n "${VPCS}" ]; then
  VPC_COUNT="$(printf '%s\n' ${VPCS} | awk 'NF' | wc -l | tr -d ' ')"
fi
echo "Estate VPCs tagged Name=heavy-rental-academy: ${VPC_COUNT:-0} (${VPCS:-none})"

if [ "${VPC_COUNT}" -ge 2 ]; then
  msg="Found ${VPC_COUNT} VPCs named heavy-rental-academy (${VPCS}). A previous apply likely forked the estate."
  if [ "${ON_FORK}" = "fail" ]; then
    echo "::error::${msg} Run action=destroy (confirm_destroy=destroy) to wipe leftovers, then apply. Do not apply again."
    exit 1
  fi
  echo "::warning::${msg} Importing unique names only; sweep will delete extra VPCs on destroy."
fi

import_account_scoped
import_unique_regional
import_listeners_and_lts

if [ "${VPC_COUNT}" = "1" ]; then
  VPC_ID="$(printf '%s' "${VPCS}" | awk '{print $1}')"
  import_network "${VPC_ID}"
  import_security_groups "${VPC_ID}"
elif [ "${VPC_COUNT}" = "0" ]; then
  echo "No estate VPC to import. First apply will create networking."
fi

echo "Reconcile finished. Subsequent plan/apply should not recreate named leftovers."
