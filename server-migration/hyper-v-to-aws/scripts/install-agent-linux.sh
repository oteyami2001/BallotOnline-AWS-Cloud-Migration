#!/usr/bin/env bash
# =====================================================================
# BallotOnline — Install the AWS Replication Agent on a Linux Hyper-V guest
# =====================================================================
# Run on each Linux source server (for example the FTP or NTP server).
#
# 1. Checks outbound connectivity the agent needs (TCP 443).
# 2. Downloads the installer for the target Region.
# 3. Installs the agent using short-lived credentials read from the
#    environment — never hard-code keys in this file.
#
# Usage:
#   export AWS_REGION=us-east-1
#   export AWS_ACCESS_KEY_ID=...        # IAM user/role with the
#   export AWS_SECRET_ACCESS_KEY=...    # AWSApplicationMigrationAgentInstallationPolicy
#   export AWS_SESSION_TOKEN=...        # optional, for temporary credentials
#   sudo -E ./install-agent-linux.sh
# =====================================================================
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo -E $0)." >&2
  exit 1
fi

bucket_host="aws-application-migration-service-${AWS_REGION}.s3.${AWS_REGION}.amazonaws.com"
mgn_host="mgn.${AWS_REGION}.amazonaws.com"
installer="aws-replication-installer-init"

echo "== Pre-flight: outbound TCP 443"
for host in "$mgn_host" "$bucket_host"; do
  if timeout 5 bash -c "exec 3<>/dev/tcp/${host}/443" 2>/dev/null; then
    echo "  OK    ${host}:443"
  else
    echo "  FAIL  ${host}:443 — check firewall, proxy, and DNS before continuing." >&2
    exit 1
  fi
done

echo "== Pre-flight: free disk space for the agent (needs ~2 GB in /var/lib)"
df -h /var/lib | tail -1

echo "== Downloading installer"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
curl -fsSL -o "${workdir}/${installer}" "https://${bucket_host}/latest/linux/${installer}"
chmod +x "${workdir}/${installer}"

echo "== Installing AWS Replication Agent"
args=(--region "$AWS_REGION"
      --aws-access-key-id "$AWS_ACCESS_KEY_ID"
      --aws-secret-access-key "$AWS_SECRET_ACCESS_KEY"
      --no-prompt)
if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
  args+=(--aws-session-token "$AWS_SESSION_TOKEN")
fi
"${workdir}/${installer}" "${args[@]}"

echo
echo "Done. The server now appears in the MGN console under 'Source servers'."
echo "Initial sync uses TCP 1500 to the replication servers in the staging subnet."
