#!/usr/bin/env bash
# =====================================================================
# BallotOnline — Deploy or delete the CloudFormation stacks in order
# =====================================================================
# Stacks (each depends on the exports of the ones before it):
#   1. network   01-network.yaml   VPC, subnets, NAT, VPN, flow logs
#   2. security  02-security.yaml  security groups, KMS key, IAM roles
#   3. aurora    03-aurora.yaml    Aurora MySQL cluster
#   4. dms       04-dms.yaml       DMS instance, endpoints, task
#   5. governance 05-governance.yaml CloudTrail, GuardDuty, Access Analyzer
#                                    (independent; deployed with "all")
#
# Usage:
#   ./deploy.sh deploy [network|security|governance|aurora|dms|all]
#   ./deploy.sh delete [dms|aurora|governance|security|network|all]
#   ./deploy.sh status
#
# Environment variables:
#   AWS_REGION            required, e.g. us-east-1
#   ENV_NAME              optional, default "ballotonline"
#   CREATE_VPN            optional, "true" to create the Site-to-Site VPN
#   CUSTOMER_GATEWAY_IP   required when CREATE_VPN=true
#   ON_PREM_CIDR          optional, default 192.168.0.0/16
#   SOURCE_SERVER_NAME    required for the dms stack (on-prem MySQL host/IP)
#   MIGRATION_TYPE        optional, default full-load
#   ENABLE_GUARDDUTY      optional, default true (false if a detector exists)
#   ENABLE_SECURITY_HUB   optional, default false
#
# Cost note: NAT gateways, Aurora, and the DMS instance bill hourly.
# Run "./deploy.sh delete all" when you are done.
# =====================================================================
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION, for example: export AWS_REGION=us-east-1}"
ENV_NAME="${ENV_NAME:-ballotonline}"
here="$(cd "$(dirname "$0")" && pwd)"
cfn() { aws cloudformation --region "$AWS_REGION" "$@"; }

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

stack_name() { echo "${ENV_NAME}-$1"; }

deploy_stack() {
  local layer="$1" template="$2"; shift 2
  echo "== Deploying $(stack_name "$layer") from ${template}"
  cfn deploy \
    --stack-name "$(stack_name "$layer")" \
    --template-file "${here}/${template}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --tags Project=BallotOnline Environment="$ENV_NAME" \
    --parameter-overrides EnvironmentName="$ENV_NAME" "$@"
}

delete_stack() {
  local name
  name="$(stack_name "$1")"
  echo "== Deleting ${name}"
  cfn delete-stack --stack-name "$name"
  cfn wait stack-delete-complete --stack-name "$name"
}

deploy_layer() {
  case "$1" in
    network)
      deploy_stack network 01-network.yaml \
        CreateVpn="${CREATE_VPN:-false}" \
        CustomerGatewayIp="${CUSTOMER_GATEWAY_IP:-}" \
        OnPremisesCidr="${ON_PREM_CIDR:-192.168.0.0/16}"
      ;;
    security)
      deploy_stack security 02-security.yaml
      ;;
    aurora)
      deploy_stack aurora 03-aurora.yaml
      ;;
    governance)
      deploy_stack governance 05-governance.yaml \
        EnableGuardDuty="${ENABLE_GUARDDUTY:-true}" \
        EnableSecurityHub="${ENABLE_SECURITY_HUB:-false}"
      ;;
    dms)
      : "${SOURCE_SERVER_NAME:?Set SOURCE_SERVER_NAME to the on-premises MySQL host or IP}"
      deploy_stack dms 04-dms.yaml \
        SourceServerName="$SOURCE_SERVER_NAME" \
        MigrationType="${MIGRATION_TYPE:-full-load}"
      ;;
    *) usage ;;
  esac
}

delete_layer() {
  case "$1" in
    aurora)
      # Deletion protection is on by default; turn it off before deleting.
      local cluster
      cluster="$(cfn describe-stacks --stack-name "$(stack_name aurora)" \
        --query "Stacks[0].Outputs[?OutputKey=='ClusterIdentifier'].OutputValue" --output text 2>/dev/null || true)"
      if [[ -n "$cluster" && "$cluster" != "None" ]]; then
        read -r -p "Delete Aurora cluster ${cluster}? A final snapshot is kept. Type 'yes': " answer
        [[ "$answer" == "yes" ]] || { echo "Cancelled."; exit 1; }
        aws rds modify-db-cluster --region "$AWS_REGION" --db-cluster-identifier "$cluster" \
          --no-deletion-protection --apply-immediately >/dev/null
      fi
      delete_stack aurora
      ;;
    dms|governance|security|network)
      delete_stack "$1"
      ;;
    *) usage ;;
  esac
}

[[ $# -ge 1 ]] || usage
action="$1"
target="${2:-all}"

case "$action" in
  deploy)
    if [[ "$target" == "all" ]]; then
      for layer in network security governance aurora; do deploy_layer "$layer"; done
      if [[ -n "${SOURCE_SERVER_NAME:-}" ]]; then
        deploy_layer dms
      else
        echo "Skipping dms stack: set SOURCE_SERVER_NAME and run './deploy.sh deploy dms'."
      fi
    else
      deploy_layer "$target"
    fi
    ;;
  delete)
    if [[ "$target" == "all" ]]; then
      for layer in dms aurora governance security network; do delete_layer "$layer"; done
    else
      delete_layer "$target"
    fi
    ;;
  status)
    cfn describe-stacks \
      --query "Stacks[?starts_with(StackName, '${ENV_NAME}-')].{Stack:StackName,Status:StackStatus,Updated:LastUpdatedTime}" \
      --output table
    ;;
  *) usage ;;
esac
