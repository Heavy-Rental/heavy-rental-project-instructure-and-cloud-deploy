#!/usr/bin/env bash
# Delete estate leftovers that Terraform state cannot see (lost state,
# cancelled credentials, or a second VPC from a failed re-apply). Idempotent.
# Does not delete the S3 state bucket or Vocareum IAM.
# Deletes leftover `heavy-rental-tfstate-lock-<deployment>` if present (unused).
#
# Requires DEPLOYMENT=academy|actual. Observe leftovers use that profile's
# names. VPC tag and RDS identifiers stay Terraform names on both profiles.
set -euo pipefail

case "${DEPLOYMENT:-}" in
  academy|actual) ;;
  *)
    echo "::error::sweep-estate-orphans: set DEPLOYMENT to academy or actual."
    exit 1
    ;;
esac
OBSERVE_NAME="heavy-rental-${DEPLOYMENT}"
OBSERVE_FLOW="${OBSERVE_NAME}-flow"

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

exists_asg() {
  local name="$1"
  local got
  got="$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${name}" \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text 2>/dev/null || true)"
  [ "${got}" = "${name}" ]
}

delete_asgs() {
  local asg
  for asg in asg-portal asg-rest asg-haystack asg-neo4j; do
    if exists_asg "${asg}"; then
      echo "Deleting ASG ${asg}."
      aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "${asg}" \
        --min-size 0 --desired-capacity 0 --max-size 0 || true
      aws autoscaling delete-auto-scaling-group \
        --auto-scaling-group-name "${asg}" --force-delete || true
    else
      echo "ASG ${asg}: already gone."
    fi
  done
}

delete_lbs_and_tgs() {
  local name arn
  for name in hr-alb-portal hr-alb-rest hr-alb-haystack hr-nlb-neo4j; do
    arn="$(aws elbv2 describe-load-balancers --names "${name}" \
      --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
    if [ -n "${arn}" ] && [ "${arn}" != "None" ]; then
      echo "Deleting load balancer ${name}."
      aws elbv2 delete-load-balancer --load-balancer-arn "${arn}" || true
    fi
  done
  sleep 15
  for name in tg-portal tg-rest tg-haystack tg-neo4j; do
    arn="$(aws elbv2 describe-target-groups --names "${name}" \
      --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
    if [ -n "${arn}" ] && [ "${arn}" != "None" ]; then
      echo "Deleting target group ${name}."
      aws elbv2 delete-target-group --target-group-arn "${arn}" || true
    fi
  done
}

delete_rds() {
  local id status
  for id in heavy-rental-academy heavy-rental-haystack-academy; do
    status="$(aws rds describe-db-instances --db-instance-identifier "${id}" \
      --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo missing)"
    if [ "${status}" = "missing" ]; then
      echo "RDS ${id}: already gone."
      continue
    fi
    if [ "${status}" != "deleting" ]; then
      echo "Deleting RDS ${id} (was ${status})."
      aws rds delete-db-instance --db-instance-identifier "${id}" \
        --skip-final-snapshot --delete-automated-backups >/dev/null || true
    fi
  done
  for id in heavy-rental-academy heavy-rental-haystack-academy; do
    if aws rds describe-db-instances --db-instance-identifier "${id}" >/dev/null 2>&1; then
      echo "Waiting for RDS ${id} to delete."
      aws rds wait db-instance-deleted --db-instance-identifier "${id}" || true
    fi
  done
  if aws rds describe-db-subnet-groups --db-subnet-group-name heavy-rental-data >/dev/null 2>&1; then
    echo "Deleting DB subnet group heavy-rental-data."
    aws rds delete-db-subnet-group --db-subnet-group-name heavy-rental-data || true
  fi
}

delete_secrets_and_ecr() {
  local name
  for name in \
    heavy-rental/portal heavy-rental/rest heavy-rental/haystack heavy-rental/neo4j \
    heavy-rental/ssh/portal heavy-rental/ssh/rest heavy-rental/ssh/haystack heavy-rental/ssh/neo4j
  do
    if aws secretsmanager describe-secret --secret-id "${name}" >/dev/null 2>&1; then
      echo "Deleting secret ${name}."
      aws secretsmanager delete-secret --secret-id "${name}" --force-delete-without-recovery >/dev/null || true
    fi
  done
  for name in heavy-rental-web-portal heavy-rental-rest-api heavy-rental-haystack heavy-rental-neo4j; do
    if aws ecr describe-repositories --repository-names "${name}" >/dev/null 2>&1; then
      echo "Deleting ECR repository ${name}."
      aws ecr delete-repository --repository-name "${name}" --force >/dev/null || true
    fi
  done
}

delete_launch_templates() {
  local prefix ids id
  for prefix in lt-portal- lt-rest- lt-haystack- lt-neo4j-; do
    ids="$(aws ec2 describe-launch-templates --output json \
      | jq -r --arg p "${prefix}" '.LaunchTemplates[]? | select(.LaunchTemplateName | startswith($p)) | .LaunchTemplateId')"
    for id in ${ids}; do
      echo "Deleting launch template ${id} (${prefix}*)."
      aws ec2 delete-launch-template --launch-template-id "${id}" >/dev/null || true
    done
  done
}

empty_and_delete_vpc() {
  local vpc="$1"
  local id eni

  echo "Emptying VPC ${vpc}."

  for id in $(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=${vpc}" \
    --query 'FlowLogs[].FlowLogId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    aws ec2 delete-flow-logs --flow-log-ids "${id}" || true
  done

  for id in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${vpc}" \
    --query 'NatGateways[?State!=`deleted` && State!=`deleting`].NatGatewayId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    echo "Deleting NAT Gateway ${id}."
    aws ec2 delete-nat-gateway --nat-gateway-id "${id}" >/dev/null || true
  done

  local deadline=$((SECONDS + 600))
  while [ "${SECONDS}" -lt "${deadline}" ]; do
    local left
    left="$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${vpc}" \
      --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || true)"
    if [ -z "${left}" ] || [ "${left}" = "None" ]; then
      break
    fi
    sleep 15
  done

  for id in $(aws ec2 describe-addresses --filters "Name=tag:Role,Values=nat" \
    --query 'Addresses[].AllocationId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    echo "Releasing NAT EIP ${id}."
    aws ec2 release-address --allocation-id "${id}" || true
  done
  for id in $(aws ec2 describe-addresses --filters "Name=tag:Name,Values=eip-nat-*" \
    --query 'Addresses[].AllocationId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    aws ec2 release-address --allocation-id "${id}" || true
  done

  for id in $(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=${vpc}" \
    --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    echo "Deleting VPC endpoint ${id}."
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "${id}" >/dev/null || true
  done

  for eni in $(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=${vpc}" \
    --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${eni}" ] || continue
    aws ec2 delete-network-interface --network-interface-id "${eni}" || true
  done

  local igw
  for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${vpc}" \
    --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${igw}" ] || continue
    aws ec2 detach-internet-gateway --internet-gateway-id "${igw}" --vpc-id "${vpc}" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "${igw}" || true
  done

  local sg
  for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc}" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${sg}" ] || continue
    aws ec2 delete-security-group --group-id "${sg}" || true
  done

  local subnet
  for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc}" \
    --query 'Subnets[].SubnetId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${subnet}" ] || continue
    aws ec2 delete-subnet --subnet-id "${subnet}" || true
  done

  local rtb
  for rtb in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${vpc}" \
    --query 'RouteTables[?Associations[?Main!=`true`]].RouteTableId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${rtb}" ] || continue
    aws ec2 delete-route-table --route-table-id "${rtb}" || true
  done

  echo "Deleting VPC ${vpc}."
  aws ec2 delete-vpc --vpc-id "${vpc}" || true
}

delete_observe() {
  local account bucket name id
  account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
  bucket="heavy-rental-observe-${account}-${DEPLOYMENT}"

  if aws cloudtrail get-trail --name "${OBSERVE_NAME}" >/dev/null 2>&1; then
    echo "Deleting CloudTrail ${OBSERVE_NAME}."
    aws cloudtrail delete-trail --name "${OBSERVE_NAME}" || true
  fi

  aws cloudwatch delete-dashboards --dashboard-names "${OBSERVE_NAME}" >/dev/null 2>&1 || true
  aws cloudwatch delete-alarms --alarm-names \
    hr-alb-portal-5xx hr-alb-rest-5xx hr-alb-haystack-5xx \
    hr-alb-portal-unhealthy hr-alb-rest-unhealthy hr-alb-haystack-unhealthy \
    hr-rds-sor-cpu hr-rds-haystack-cpu hr-rds-sor-storage hr-rds-haystack-storage \
    hr-asg-portal-inservice hr-asg-rest-inservice hr-asg-haystack-inservice hr-asg-neo4j-inservice \
    >/dev/null 2>&1 || true

  for name in portal rest haystack neo4j; do
    aws logs delete-log-group --log-group-name "/heavy-rental/${name}" >/dev/null 2>&1 || true
  done

  for id in $(aws sns list-topics --query "Topics[?contains(TopicArn, ':hr-academy-alarms')].TopicArn" --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    echo "Deleting SNS topic ${id}."
    aws sns delete-topic --topic-arn "${id}" || true
  done

  for id in $(aws ec2 describe-flow-logs --filter Name=tag:Name,Values="${OBSERVE_FLOW}" \
    --query 'FlowLogs[].FlowLogId' --output text 2>/dev/null | tr '\t' ' '); do
    [ -n "${id}" ] || continue
    echo "Deleting flow log ${id}."
    aws ec2 delete-flow-logs --flow-log-ids "${id}" || true
  done

  if [ -n "${account}" ] && aws s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1; then
    echo "Emptying and deleting observe bucket ${bucket}."
    aws s3 rm "s3://${bucket}" --recursive >/dev/null 2>&1 || true
    aws s3api delete-bucket --bucket "${bucket}" || true
  fi
}

delete_leftover_tfstate_lock() {
  local table="heavy-rental-tfstate-lock-${DEPLOYMENT}"
  if aws dynamodb describe-table --table-name "${table}" >/dev/null 2>&1; then
    echo "Deleting leftover state lock table ${table}."
    aws dynamodb delete-table --table-name "${table}" >/dev/null || true
  else
    echo "State lock table ${table}: already gone."
  fi
}

delete_asgs
delete_lbs_and_tgs

mapfile -t INSTANCES < <(aws ec2 describe-instances \
  --filters "Name=tag:Stack,Values=estate" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null \
  | tr '\t' '\n' | awk 'NF')
if [ "${#INSTANCES[@]}" -gt 0 ]; then
  echo "Terminating leftover estate instances: ${INSTANCES[*]}"
  aws ec2 terminate-instances --instance-ids "${INSTANCES[@]}" >/dev/null || true
  aws ec2 wait instance-terminated --instance-ids "${INSTANCES[@]}" || true
fi

delete_rds
delete_secrets_and_ecr
delete_launch_templates
delete_observe
delete_leftover_tfstate_lock

for vpc in $(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=heavy-rental-academy" \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null | tr '\t' ' '); do
  [ -n "${vpc}" ] || continue
  empty_and_delete_vpc "${vpc}"
done

echo "Sweep finished (region ${REGION}). Named leftovers and extra estate VPCs should be gone."
