# 📊 Monitoring and Management

How the migrated BallotOnline environment is watched, alerted on, patched, and reviewed. Everything here is deployed by two CloudFormation stacks and one report script.

```text
 Aurora · DMS · VPN · EC2 ──metrics──┐
 CloudTrail logs ──metric filters────┤
                                     ▼
                       ┌──────────────────────────┐
                       │ Amazon CloudWatch        │
                       │ alarms · dashboard · logs│
                       └────────────┬─────────────┘
 GuardDuty · RDS · DMS events       │ alarm / event
        └──── EventBridge ──────────┤
                                    ▼
                       ┌──────────────────────────┐
                       │ SNS topic (encrypted)    │──▶ Operations team (email)
                       └──────────────────────────┘

 AWS Systems Manager ── patch scan (daily) · patch install (weekly)
                        inventory · CloudWatch agent on EC2
 AWS Trusted Advisor ── security · fault tolerance · cost · performance · limits
```

| Area | What it covers | Details |
|---|---|---|
| [`cloudwatch/`](cloudwatch/) | Up to 22 alarms (infrastructure and security), security metric filters, EventBridge rules, operations dashboard, SNS alerts | [`06-monitoring.yaml`](../infrastructure-as-code/cloudformation/06-monitoring.yaml) |
| [`systems-manager/`](systems-manager/) | Patch scanning and installation, software inventory, CloudWatch agent for memory, disk, and OS logs | [`07-operations.yaml`](../infrastructure-as-code/cloudformation/07-operations.yaml) |
| [`trusted-advisor/`](trusted-advisor/) | Best-practice review across six pillars, with a report script | [`ta-report.sh`](trusted-advisor/ta-report.sh) |

## Deploy

```bash
cd infrastructure-as-code/cloudformation
export AWS_REGION=us-east-1

# After the aurora and governance stacks exist
ALERT_EMAIL=ops@example.com ./deploy.sh deploy monitoring
./deploy.sh deploy operations

# After cutover, add alarms for the migrated servers
INTRANET_INSTANCE_ID=i-... FTP_INSTANCE_ID=i-... NTP_INSTANCE_ID=i-... \
VPN_CONNECTION_ID=vpn-... ALERT_EMAIL=ops@example.com ./deploy.sh deploy monitoring
```

Confirm the SNS subscription email, or no alerts will be delivered.

## Monitoring by Migration Phase

| Phase | Focus | Key signals |
|---|---|---|
| During migration | Replication health | DMS CPU, free storage, CDC latency, task state changes; MGN replication lag; VPN tunnel state |
| Cutover | Target readiness | Aurora CPU, connections, latency; EC2 status checks; application errors |
| After migration | Steady state and security | Dashboard trends, security alarms, GuardDuty findings, patch compliance, Trusted Advisor |
