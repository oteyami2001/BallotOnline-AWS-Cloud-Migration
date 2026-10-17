#!/usr/bin/env bash
# =====================================================================
# BallotOnline — AWS Application Migration Service (MGN) lifecycle helper
# =====================================================================
# Drives source servers through the MGN migration lifecycle:
#
#   status   -> show lifecycle and replication state
#   test     -> launch test instances
#   cleanup  -> terminate test instances
#   ready    -> mark servers ready for cutover
#   cutover  -> launch cutover (production) instances
#   finalize -> finalize cutover (stops replication)
#   archive  -> archive source servers after the rollback window
#
# Usage:
#   AWS_REGION=us-east-1 ./mgn-lifecycle.sh <action> <source-server-id> [...]
#
# Example:
#   ./mgn-lifecycle.sh status s-11111111111111111 s-22222222222222222
#
# Requires: AWS CLI v2, credentials with MGN permissions
#           (for example the AWSApplicationMigrationFullAccess managed policy).
# Source server IDs come from the MGN console or `status` with no IDs.
# =====================================================================
set -euo pipefail

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[[ $# -ge 1 ]] || usage
action="$1"; shift
servers=("$@")

: "${AWS_REGION:?Set AWS_REGION, for example: export AWS_REGION=us-east-1}"
mgn() { aws mgn --region "$AWS_REGION" "$@"; }

require_servers() {
  if [[ ${#servers[@]} -eq 0 ]]; then
    echo "Error: '$action' needs at least one source server ID." >&2
    exit 1
  fi
}

confirm() {
  local prompt="$1" answer
  read -r -p "$prompt Type 'yes' to continue: " answer
  [[ "$answer" == "yes" ]] || { echo "Cancelled."; exit 1; }
}

case "$action" in
  status)
    filter=()
    if [[ ${#servers[@]} -gt 0 ]]; then
      filter=(--filters "sourceServerIDs=$(IFS=,; echo "${servers[*]}")")
    fi
    mgn describe-source-servers "${filter[@]}" \
      --query 'items[].{ID:sourceServerID,Host:sourceProperties.identificationHints.hostname,Lifecycle:lifeCycle.state,Replication:dataReplicationInfo.dataReplicationState,Lag:dataReplicationInfo.lagDuration,LaunchedInstance:launchedInstance.ec2InstanceID}' \
      --output table
    ;;

  test)
    require_servers
    echo "Launching test instances for: ${servers[*]}"
    mgn start-test --source-server-ids "${servers[@]}" --query 'job.{JobID:jobID,Status:status}' --output table
    ;;

  cleanup)
    require_servers
    confirm "Terminate TEST instances for ${servers[*]}?"
    mgn terminate-target-instances --source-server-ids "${servers[@]}" --query 'job.{JobID:jobID,Status:status}' --output table
    ;;

  ready)
    require_servers
    for id in "${servers[@]}"; do
      echo "Marking $id ready for cutover"
      mgn change-server-life-cycle-state --source-server-id "$id" \
        --life-cycle state=READY_FOR_CUTOVER --query 'lifeCycle.state' --output text
    done
    ;;

  cutover)
    require_servers
    confirm "Launch PRODUCTION cutover instances for ${servers[*]}? Make sure source writes are stopped."
    mgn start-cutover --source-server-ids "${servers[@]}" --query 'job.{JobID:jobID,Status:status}' --output table
    ;;

  finalize)
    require_servers
    confirm "Finalize cutover for ${servers[*]}? Replication will stop and test instances will be removed."
    for id in "${servers[@]}"; do
      mgn finalize-cutover --source-server-id "$id" --query 'lifeCycle.state' --output text
    done
    ;;

  archive)
    require_servers
    confirm "Archive source servers ${servers[*]}? Only do this after the rollback window closes."
    for id in "${servers[@]}"; do
      mgn mark-as-archived --source-server-id "$id" --query 'isArchived' --output text
    done
    ;;

  *)
    usage
    ;;
esac
