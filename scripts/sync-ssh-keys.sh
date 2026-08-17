#!/usr/bin/env bash
# After ASGs are InService: PEM in Secrets Manager, public key via SSM.
# Never log the PEM. Never write the private key onto the guest.
set +x
set -euo pipefail

ASGS=(asg-portal asg-rest asg-haystack asg-neo4j)
ROLES=(portal rest haystack neo4j)
TIMEOUT="${SSH_WAIT_TIMEOUT:-900}"

wait_inservice() {
  local asg="$1"
  local start
  start="$(date +%s)"
  while true; do
    local desired in_svc
    desired="$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg}" \
      --query 'AutoScalingGroups[0].DesiredCapacity' --output text 2>/dev/null || echo none)"
    if [ "${desired}" = "none" ] || [ "${desired}" = "None" ] || [ -z "${desired}" ]; then
      echo "::error::${asg} is missing. Apply the estate first."
      exit 1
    fi
    if [ "${desired}" = "0" ]; then
      echo "::error::${asg} desired=0. Run apply or scale the group before sync-ssh-keys."
      exit 1
    fi
    in_svc="$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg}" \
      --query 'length(AutoScalingGroups[0].Instances[?LifecycleState==`InService`])' \
      --output text)"
    if [ "${in_svc}" -ge "${desired}" ]; then
      echo "${asg}: ${in_svc} InService (desired ${desired})."
      return 0
    fi
    if [ $(( $(date +%s) - start )) -ge "${TIMEOUT}" ]; then
      echo "::error::Timed out waiting for ${asg} InService (have ${in_svc}, want ${desired})."
      exit 1
    fi
    sleep 15
  done
}

instance_ids() {
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$1" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text
}

for asg in "${ASGS[@]}"; do
  wait_inservice "${asg}"
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  asg="${ASGS[$i]}"
  secret_id="heavy-rental/ssh/${role}"
  key_name="hr-academy-${role}"
  key_file="${WORKDIR}/${role}"

  existing="$(aws secretsmanager get-secret-value --secret-id "${secret_id}" \
    --query SecretString --output text 2>/dev/null || true)"
  if echo "${existing}" | jq -e '.private_key_pem | type=="string" and length>20' >/dev/null 2>&1; then
    echo "${secret_id}: reusing existing PEM."
    echo "${existing}" | jq -r '.private_key_pem' >"${key_file}"
    chmod 600 "${key_file}"
    ssh-keygen -y -f "${key_file}" >"${key_file}.pub"
  else
    ssh-keygen -t ed25519 -N '' -C "${key_name}" -f "${key_file}" >/dev/null
    pem="$(cat "${key_file}")"
    echo "::add-mask::${pem}"
    jq -n --arg key_name "${key_name}" --arg private_key_pem "${pem}" \
      '{key_name:$key_name,private_key_pem:$private_key_pem}' >"${WORKDIR}/${role}.json"
    aws secretsmanager put-secret-value \
      --secret-id "${secret_id}" \
      --secret-string "file://${WORKDIR}/${role}.json" \
      >/dev/null
  fi

  pub="$(cat "${key_file}.pub")"
  ids="$(instance_ids "${asg}")"
  if [ -z "${ids}" ]; then
    echo "::error::No InService instances on ${asg}."
    exit 1
  fi
  # shellcheck disable=SC2086
  aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "install ${key_name} public key" \
    --instance-ids ${ids} \
    --parameters "commands=[
      \"set -euo pipefail\",
      \"install -d -m 700 -o ec2-user -g ec2-user /home/ec2-user/.ssh\",
      \"touch /home/ec2-user/.ssh/authorized_keys\",
      \"chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys\",
      \"chmod 600 /home/ec2-user/.ssh/authorized_keys\",
      \"grep -qxF '${pub}' /home/ec2-user/.ssh/authorized_keys || echo '${pub}' >> /home/ec2-user/.ssh/authorized_keys\"
    ]" \
    >/dev/null
  echo "${asg}: public key installed via SSM (PEM not on guest)."
done

echo "SSH secrets written. Private keys not printed."
