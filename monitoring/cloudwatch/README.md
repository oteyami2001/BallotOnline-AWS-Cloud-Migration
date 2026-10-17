# Amazon CloudWatch

Alarms, dashboards, and alert routing for the BallotOnline environment, defined in [`06-monitoring.yaml`](../../infrastructure-as-code/cloudformation/06-monitoring.yaml).

## Alert Routing

All alarms and events publish to the **`ballotonline-alerts`** SNS topic, which is encrypted with its own KMS key and accepts messages only from CloudWatch and EventBridge in this account. Subscribe operations staff by email (`AlertEmail` parameter) or add chat/paging integrations later.

## Infrastructure Alarms

| Alarm | Metric | Condition | Why |
|---|---|---|---|
| `aurora-cpu-high` | `AWS/RDS CPUUtilization` | > 80% for 15 min | Undersized instance or runaway query |
| `aurora-connections-high` | `DatabaseConnections` | > 80 | Close to the db.t4g.medium connection limit |
| `aurora-memory-low` | `FreeableMemory` | < 256 MB for 15 min | Memory pressure, swapping |
| `aurora-replica-lag` | `AuroraReplicaLagMaximum` | > 1 s for 5 min | Reader serving stale data; failover target behind |
| `dms-cpu-high` | `AWS/DMS CPUUtilization` | > 80% for 15 min | Replication instance too small |
| `dms-storage-low` | `FreeStorageSpace` | < 10 GB | Cached changes filling the disk |
| `dms-cdc-source-latency` / `-target-latency` | `CDCLatencySource` / `CDCLatencyTarget` | > 60 s for 15 min | Changes not keeping up; cutover would take longer |
| `vpn-down` | `AWS/VPN TunnelState` | All tunnels down for 10 min | Migration traffic and staff access cut off |
| `<server>-system-check` | `StatusCheckFailed_System` | Failed 2 min | **Automatically recovers** the EC2 instance onto healthy hardware |
| `<server>-cpu-high` | `AWS/EC2 CPUUtilization` | > 80% for 15 min | Right-sizing needed |

DMS task, VPN, and EC2 alarms are created only when their IDs are supplied, so the stack can be deployed before cutover and updated afterwards.

## Security Alarms (from CloudTrail)

Metric filters on the CloudTrail log group (from [`05-governance.yaml`](../../infrastructure-as-code/cloudformation/05-governance.yaml)) feed the `BallotOnline/Security` namespace. Patterns follow the **CIS AWS Foundations Benchmark** monitoring controls.

| Alarm | Fires when |
|---|---|
| `security-root-usage` | The root account is used |
| `security-console-login-no-mfa` | An IAM user signs in to the console without MFA |
| `security-unauthorized-api-calls` | 10+ access-denied API calls in 5 minutes |
| `security-iam-policy-changes` | An IAM policy is created, changed, attached, or detached |
| `security-sg-changes` | A security group or rule is created, changed, or deleted |
| `security-cloudtrail-changes` | CloudTrail is changed or logging is stopped |
| `security-kms-key-disable` | A KMS key is disabled or scheduled for deletion |

## Event Rules (EventBridge)

| Rule | Source | Purpose |
|---|---|---|
| `guardduty-high-severity` | GuardDuty findings with severity ≥ 7 | Possible compromise needing immediate response |
| `aurora-failover` | RDS cluster failover events | Writer moved to the reader's AZ |
| `dms-task-state` | DMS replication task state changes | Task started, stopped, or failed |

## Dashboard

**`ballotonline-operations`** shows Aurora CPU, connections, replica lag, and read/write latency; DMS CPU and free storage; and hourly counts of each security event. The stack output `DashboardUrl` links to it.

## Logs

| Log group | Source | Retention |
|---|---|---|
| `/ballotonline/vpc-flow-logs` | VPC Flow Logs | 90 days |
| `/ballotonline/cloudtrail` | CloudTrail (KMS-encrypted) | 365 days |
| `/aws/rds/cluster/<cluster>/error`, `/slowquery` | Aurora | Default |
| `dms-tasks-<instance>` | DMS task logs | Default |
| `/ballotonline/ec2/linux/*`, `/ballotonline/ec2/windows/*` | CloudWatch agent on migrated servers | 90 days |
