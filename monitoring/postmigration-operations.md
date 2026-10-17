# 🛠️ Postmigration Operations Model

How BallotOnline's AWS environment would be run after cutover: what is checked, how often, with which tool, and what counts as evidence. The checkbox version is in [`operational-checklist.md`](operational-checklist.md).

> **Scope:** this is a recommended operating model built around the monitoring resources in this repository. It was not carried out against a live BallotOnline environment. See [Project scope](#-project-scope).

---

## Roles

| Role | Responsibility |
|---|---|
| **Cloud operations engineer** | Daily and weekly checks, alarm response, patching, runbooks |
| **Database administrator** | Aurora health, backups, restores, DMS (while in use) |
| **Security lead** | GuardDuty findings, security alarms, IAM reviews |
| **Service owner (HR / IT)** | Approves changes, accepts DR and cost decisions |

---

## Daily

| Check | Tool | Healthy result | If not |
|---|---|---|---|
| Critical alarms | CloudWatch → Alarms, `ballotonline-operations` dashboard | No alarm in `ALARM` state | Follow the alarm's runbook; run the [health-check Automation](systems-manager/automation-runbook.yaml) on affected EC2 instances |
| Application availability | Intranet over HTTPS, SFTP login, NTP query from the office | All three respond | [Post-cutover validation](../cutover-rollback/post-cutover-validation.md) steps for the failing service |
| Security events | GuardDuty findings, `security-*` alarms, SNS alert emails | No new high-severity finding or alarm | Security lead triages per the [incident response outline](../security/security-controls.md#6-logging-detection-and-response) |
| Migration / replication status *(only while DMS or MGN are still running)* | DMS task status and CDC latency; `mgn-lifecycle.sh status` | Task running, latency low; replication `CONTINUOUS` | Check VPN, source availability, and DMS task logs |
| Backups completed | RDS console → automated backups | Latest restorable time within the last few minutes | Investigate before any change window |

## Weekly

| Check | Tool | Healthy result |
|---|---|---|
| Patch compliance | Systems Manager → Patch Manager compliance | All `Project=BallotOnline` instances compliant after Sunday's install |
| State Manager association status | Systems Manager → State Manager | Agent install/configure, patch scan, and inventory associations `Success` |
| Failed automation | Systems Manager → Automation executions | No `Failed` executions, or each one explained |
| Performance trends | CloudWatch dashboard (7-day view) | CPU, connections, latency, memory and disk (agent) within normal ranges |
| Backup status | Aurora automated backups and snapshots; AWS Backup if adopted | Retention met; manual snapshot exists before planned changes |
| Log health | CloudWatch Logs | Flow Logs, CloudTrail, Aurora and EC2 OS logs still arriving |

## Monthly

| Check | Tool | Output |
|---|---|---|
| Trusted Advisor review | Console, or [`ta-report.sh`](trusted-advisor/ta-report.sh) where the Support plan allows | List of findings with owner and due date |
| Cost review | AWS Cost Explorer, Budgets | Spend vs. budget; idle resources (DMS, test instances, unused EIPs) removed |
| IAM / access review | IAM credential report, Access Analyzer | Unused users and keys removed; MFA on every user; no unexpected external access |
| Patch / compliance review | Patch Manager, Security Hub (if enabled) | Exceptions documented with a fix date |
| Capacity planning | CloudWatch trends, Aurora `VolumeBytesUsed` | Right-sizing or scaling decisions recorded |

## Quarterly

| Activity | How | Evidence |
|---|---|---|
| Disaster recovery test | Follow [`disaster-recovery.md`](../cutover-rollback/disaster-recovery.md): restore Aurora to a point in time, rebuild a stack from CloudFormation | Measured recovery time vs. the proposed RTO/RPO |
| Restore test | Restore an Aurora snapshot to a temporary cluster and run [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) | Row counts and hashes match; temporary cluster deleted |
| Security architecture review | Re-check [`security-controls.md`](../security/security-controls.md) and [`security-checklist.md`](../security/security-checklist.md) | Updated risk register |
| Rightsizing | AWS Compute Optimizer, Trusted Advisor, CloudWatch | Instance type changes planned or declined with reason |
| Documentation / runbook review | This repository | Runbooks match the running environment; outdated steps fixed |

---

## Escalation

| Severity | Examples | Response |
|---|---|---|
| **Critical** | Intranet or HR database down; GuardDuty high-severity finding; root account used | Immediate; on-call engineer + service owner; security lead for security events |
| **High** | Aurora failover; VPN down; repeated failed automation | Same business day |
| **Medium** | Patch non-compliance; Trusted Advisor warning; rising trends | Within the week |
| **Low** | Documentation gaps, cost optimizations | Next monthly review |

---

## 📌 Project Scope

| | |
|---|---|
| **UMGC course project** | CloudWatch, Systems Manager, and Trusted Advisor were evaluated as postmigration services for BallotOnline. |
| **This repository** | Implements the alarms, dashboard, event rules, SSM associations, health-check runbook, and Trusted Advisor report script as code. All templates pass `cfn-lint`; **none has been deployed to a real AWS account.** |
| **Recommended practice** | The schedules, roles, and escalation levels on this page. |
