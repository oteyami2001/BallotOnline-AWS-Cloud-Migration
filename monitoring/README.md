# 📊 Monitoring and Postmigration Operations

How the migrated BallotOnline environment is monitored, managed, optimized, and maintained after cutover.

![BallotOnline observability and operations](../architecture/diagrams/monitoring-operations.svg)

---

## 📌 Project Scope

| Category | What it covers |
|---|---|
| **1. UMGC course project** | CloudWatch, AWS Systems Manager, and AWS Trusted Advisor were **evaluated** as the postmigration monitoring and management services for BallotOnline. |
| **2. Implemented in this repository** | Alarms, dashboard, EventBridge rules, and the alert topic ([`06-monitoring.yaml`](../infrastructure-as-code/cloudformation/06-monitoring.yaml)); SSM patching, inventory, and CloudWatch agent associations ([`07-operations.yaml`](../infrastructure-as-code/cloudformation/07-operations.yaml)); a read-only Automation runbook; and a Trusted Advisor report script. Templates are validated with `cfn-lint` in CI. **None has been deployed to a real AWS account.** |
| **3. Recommended production practice** | Items marked *recommended* in [`alarms.yaml`](cloudwatch/alarms.yaml), and the operating schedule in [`postmigration-operations.md`](postmigration-operations.md). |

---

## Contents

| Document | Purpose |
|---|---|
| [`cloudwatch/README.md`](cloudwatch/README.md) | What is monitored, native vs. agent metrics, alarms, logs, VPC and migration monitoring |
| [`cloudwatch/alarms.yaml`](cloudwatch/alarms.yaml) | Catalog of every alarm and event rule, its source, and whether it is implemented or recommended |
| [`systems-manager/README.md`](systems-manager/README.md) | SSM Agent, Session Manager, Run Command, Automation, Patch Manager, Inventory, Parameter Store |
| [`systems-manager/automation-runbook.yaml`](systems-manager/automation-runbook.yaml) | Read-only instance health-check and diagnostics runbook |
| [`trusted-advisor/README.md`](trusted-advisor/README.md) | Category-by-category evaluation, support-plan availability, how it complements the other services |
| [`trusted-advisor/ta-report.sh`](trusted-advisor/ta-report.sh) | Lists Trusted Advisor findings by pillar (Support plan permitting) |
| [`postmigration-operations.md`](postmigration-operations.md) | Daily, weekly, monthly, and quarterly operating model with roles and escalation |
| [`operational-checklist.md`](operational-checklist.md) | Checkbox version for the operations log |

---

## How the Pieces Fit

| Service | Question it answers | Scope |
|---|---|---|
| **CloudWatch** | Is something wrong right now, and how is it trending? | Metrics, logs, alarms, dashboard |
| **EventBridge** | Did an important AWS event just happen? | GuardDuty findings, Aurora failover, DMS task state |
| **Systems Manager** | How do we access, patch, inspect, and fix the servers safely? | EC2 instances with the SSM Agent |
| **Trusted Advisor** | Does the account follow AWS best practices? | Account-wide, reviewed monthly |

## Deploy

```bash
cd infrastructure-as-code/cloudformation
export AWS_REGION=us-east-1

# After the aurora and governance stacks exist
ALERT_EMAIL=<ops-team-email> ./deploy.sh deploy monitoring
./deploy.sh deploy operations

# After cutover, add alarms for the migrated servers
INTRANET_INSTANCE_ID=<i-...> FTP_INSTANCE_ID=<i-...> NTP_INSTANCE_ID=<i-...> \
VPN_CONNECTION_ID=<vpn-...> ALERT_EMAIL=<ops-team-email> ./deploy.sh deploy monitoring
```

Confirm the SNS subscription email, or no alerts will be delivered.

## Monitoring by Migration Phase

| Phase | Focus | Key signals |
|---|---|---|
| During migration | Replication health | DMS CPU, free storage, CDC latency, task state; MGN replication state and lag; VPN tunnel state |
| Cutover | Target readiness | Aurora CPU, connections, latency; EC2 status checks; application checks |
| After migration | Steady state and security | Dashboard trends, security alarms, GuardDuty, patch compliance, Trusted Advisor |
