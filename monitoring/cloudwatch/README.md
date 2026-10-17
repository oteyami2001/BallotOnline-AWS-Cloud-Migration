# Amazon CloudWatch

Alarms, dashboards, and alert routing for the BallotOnline environment, defined in [`06-monitoring.yaml`](../../infrastructure-as-code/cloudformation/06-monitoring.yaml).

Every alarm and event rule, with its source and whether it is implemented or only recommended, is listed in [`alarms.yaml`](alarms.yaml).

## Where Metrics Come From

| Source | Needs extra setup? | Examples | Provided by |
|---|---|---|---|
| **Native AWS metrics** | No: published automatically | EC2 `CPUUtilization`, `StatusCheckFailed_*`, network; Aurora `CPUUtilization`, `DatabaseConnections`, `FreeableMemory`, `AuroraReplicaLagMaximum`, `VolumeBytesUsed`; DMS `CPUUtilization`, `FreeStorageSpace`, `CDCLatencySource/Target`; VPN `TunnelState` | The AWS service |
| **CloudWatch agent metrics** | Yes: agent installed and configured on each instance | Memory (`mem_used_percent`, `Memory % Committed Bytes In Use`), disk (`used_percent`, `LogicalDisk % Free Space`), swap | [`07-operations.yaml`](../../infrastructure-as-code/cloudformation/07-operations.yaml) via Systems Manager |
| **Agent log collection** | Yes: same agent | `/var/log/messages`, `/var/log/secure`, Windows System/Application/Security event logs | `07-operations.yaml` |
| **Service log exports** | Yes: enabled in the template | Aurora error and slow-query logs, DMS task logs, VPC Flow Logs, CloudTrail | `03-aurora`, `04-dms`, `01-network`, `05-governance` |
| **Log-derived metrics** | Yes: metric filters | `BallotOnline/Security` counts (root use, IAM changes, ...) | `06-monitoring.yaml` |

> EC2 does **not** report memory or disk usage on its own. Before the agent is installed, a migrated server can run out of memory or disk without any alarm firing.

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

## Aurora Storage and Availability

- **Storage:** Aurora storage grows automatically (up to 128 TiB), so "disk full" is not the main risk. Watch `VolumeBytesUsed` for unexpected growth and its cost. A budget-based alarm is listed as *recommended* in `alarms.yaml`.
- **Availability:** the writer and reader run in different Availability Zones. A failover publishes an RDS event, which the `aurora-failover` rule sends to SNS. Applications must connect through the **cluster endpoint**, not an instance endpoint, so they follow the writer after a failover.
- **Backups:** automated backups give point-in-time recovery for the retention period (7 days in `03-aurora.yaml`). Backup checks are part of the [operating model](../postmigration-operations.md).

## Network and VPC Activity

| Signal | Where | Use |
|---|---|---|
| VPN `TunnelState` | `AWS/VPN` metric, `vpn-down` alarm | Hybrid connectivity during migration and for staff access |
| VPC Flow Logs | `/ballotonline/vpc-flow-logs` | Rejected connections, unexpected destinations, troubleshooting security groups |
| Security group changes | `security-sg-changes` alarm | Detect unreviewed firewall changes |

Example CloudWatch Logs Insights query for the most frequently rejected connections:

```text
fields @timestamp, srcAddr, dstAddr, dstPort, action
| filter action = "REJECT"
| stats count(*) as rejected by srcAddr, dstAddr, dstPort
| sort rejected desc
| limit 20
```

## Migration Monitoring (DMS and MGN)

| Service | What to watch | How |
|---|---|---|
| AWS DMS | Task state, full-load progress, CDC latency, validation failures, instance CPU and storage | Alarms and the `dms-task-state` rule in `06-monitoring.yaml`; DMS console table statistics; [`validation-queries.sql`](../../database-migration/aurora/validation-queries.sql) |
| AWS MGN | Replication state (`CONTINUOUS`, `STALLED`), lag, backlog, lifecycle state | MGN console or [`mgn-lifecycle.sh status`](../../server-migration/hyper-v-to-aws/scripts/mgn-lifecycle.sh). There is no CloudWatch alarm for MGN in the templates, so it is checked manually during the migration window. |

DMS and MGN alarms only matter while migration is running. Delete the DMS stack and archive the MGN source servers after cutover so they stop costing money and stop raising alarms.

## Logs

| Log group | Source | Retention |
|---|---|---|
| `/ballotonline/vpc-flow-logs` | VPC Flow Logs | 90 days |
| `/ballotonline/cloudtrail` | CloudTrail (KMS-encrypted) | 365 days |
| `/aws/rds/cluster/<cluster>/error`, `/slowquery` | Aurora | Default |
| `dms-tasks-<instance>` | DMS task logs | Default |
| `/ballotonline/ec2/linux/*`, `/ballotonline/ec2/windows/*` | CloudWatch agent on migrated servers | 90 days |
