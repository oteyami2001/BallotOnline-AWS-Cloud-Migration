# ✅ Post-Cutover Validation

Technical checks run at **T+1 hour** and completed by **T+24 hours** after [cutover](cutover-runbook.md). Each check links to the existing artifact that performs it, rather than repeating it here.

Record every result (Pass/Fail, who, when, evidence). Redact account IDs, endpoints, and IP addresses in any saved evidence.

---

## Aurora MySQL

| Check | How | Expected | Result |
|---|---|---|---|
| Connectivity over TLS | Connect with the application user to the **cluster endpoint**; [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) section 1 | Connected; `Ssl_cipher` not empty; `require_secure_transport = ON` | |
| Schema | Section 2: tables, columns, primary keys, indexes compared with the source | Identical; secondary indexes, FKs, views, routines, triggers recreated | |
| Row counts | Section 3, run on source (read-only) and target | Every table matches | |
| Critical data | Sections 4–5: content hashes, key ranges, NULL checks, sample records, non-ASCII names | Match the source | |
| DMS validation | Section 6: `awsdms_validation_failures_v1` | No rows | |
| Performance | Dashboard: CPU, connections, read/write latency; key HR pages timed | Within tolerance of the on-premises baseline | |
| Backups | RDS console: automated backups, latest restorable time; manual snapshot `post-cutover-<date>` | Present | |

## EC2 (Migrated Servers)

Full per-server steps: [`cutover-validation-checklist.md`](../server-migration/hyper-v-to-aws/cutover-validation-checklist.md).

| Check | How | Expected | Result |
|---|---|---|---|
| Instance health | EC2 status checks; [health-check Automation](../monitoring/systems-manager/automation-runbook.yaml) | 2/2 checks; runbook completes | |
| SSM connectivity | Fleet Manager / `aws ssm describe-instance-information` | `Online` for all three servers | |
| Intranet | HTTPS from the office; sign-in; page reading HR data | `200`, valid certificate, data from Aurora | |
| FTP / SFTP | `sftp` login, upload, download, checksum | Works for real accounts; plain FTP disabled | |
| NTP | `chronyc sources` / `w32tm /stripchart` from clients | Small offset; clients synced | |
| DNS | `nslookup` for each service name | Resolves to the new private IPs | |

## Security

| Check | How | Expected | Result |
|---|---|---|---|
| IAM | IAM console; [`require-mfa`](../security/iam-policies/require-mfa.json) attached; agent-install credentials deleted | MFA everywhere; no leftover migration keys | |
| Security groups | Review against [`02-security.yaml`](../infrastructure-as-code/cloudformation/02-security.yaml) | No `0.0.0.0/0` inbound; no SSH/RDP | |
| Encryption | Aurora, EBS, and snapshots encrypted with the KMS data key | Encrypted: yes | |
| CloudTrail | CloudTrail console / `aws cloudtrail get-trail-status` | Logging; log file validation on | |
| GuardDuty *(where configured)* | GuardDuty findings | No new high-severity findings | |
| Security checklist | [`security-checklist.md`](../security/security-checklist.md) phase 3 | Complete | |

## Monitoring and Operations

| Check | How | Expected | Result |
|---|---|---|---|
| CloudWatch dashboard | `ballotonline-operations` | All widgets show current data | |
| Alarm state | CloudWatch → Alarms | No alarm in `ALARM`; EC2 alarms created with the new instance IDs | |
| SNS notifications | Publish a test message to `ballotonline-alerts` | Email received | |
| Systems Manager | State Manager associations, Patch Manager compliance, Inventory | Associations succeeded; instances listed | |
| CloudWatch agent | `CWAgent` namespace | Memory and disk metrics for each server | |

---

## Sign-off

| Area | Validated By | Date | Notes |
|---|---|---|---|
| Aurora | | | |
| EC2 servers | | | |
| Security | | | |
| Monitoring | | | |
| **Service owner acceptance** | | | |
