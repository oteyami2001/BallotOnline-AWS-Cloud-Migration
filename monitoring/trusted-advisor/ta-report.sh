#!/usr/bin/env bash
# =====================================================================
# BallotOnline — AWS Trusted Advisor findings report
# =====================================================================
# Lists Trusted Advisor recommendations that need attention (status
# "error" or "warning"), grouped by pillar: security, fault tolerance,
# cost optimization, performance, service limits, operational excellence.
#
# Usage:
#   ./ta-report.sh                 # all pillars
#   ./ta-report.sh security        # one pillar
#
# Pillars: security | fault_tolerance | cost_optimizing | performance |
#          service_limits | operational_excellence
#
# Requires: AWS CLI v2 and the trustedadvisor:ListRecommendations permission.
# The Trusted Advisor API needs a Business, Enterprise On-Ramp, or
# Enterprise Support plan. With Basic Support, review the core checks in
# the Trusted Advisor console instead.
# =====================================================================
set -euo pipefail

pillars=(security fault_tolerance cost_optimizing performance service_limits operational_excellence)
if [[ $# -ge 1 ]]; then
  case " ${pillars[*]} " in
    *" $1 "*) pillars=("$1") ;;
    *) echo "Unknown pillar: $1" >&2; sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
fi

# The Trusted Advisor API is served from us-east-1.
ta() { aws trustedadvisor --region us-east-1 "$@"; }

echo "Trusted Advisor report — $(date -u '+%Y-%m-%d %H:%M UTC')"
for pillar in "${pillars[@]}"; do
  for status in error warning; do
    echo
    echo "== ${pillar} · ${status}"
    ta list-recommendations \
      --pillar "$pillar" \
      --status "$status" \
      --query 'recommendationSummaries[].{Check:name,Warnings:resourcesAggregates.warningCount,Errors:resourcesAggregates.errorCount,Updated:lastUpdatedAt}' \
      --output table
  done
done
