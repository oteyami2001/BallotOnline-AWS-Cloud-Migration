# 🚦 Go/No-Go Checklist

Used at **T-24 hours** (pre-check) and **T-1 hour** (final decision) before the [cutover window](cutover-runbook.md).

## Decision Rule

- Every check marked **Blocking = Yes** must be **Pass** with evidence.
- **Any unresolved blocking check means NO-GO.** No exceptions are granted during the meeting.
- A non-blocking failure can be accepted only if the service owner records the risk and a fix date.
- On NO-GO, production stays on the on-premises environment, replication keeps running, and a new window is scheduled.

**Status values:** Pass · Fail · N/A (with reason)

---

## Database

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| DMS endpoints `ccs640mysql` and `ccs640target` test successfully | DBA | | `describe-connections` output | Yes |
| Rehearsal Full Load completed with all tables `Table completed` | DBA | | DMS table statistics | Yes |
| CDC latency below agreed threshold (Option A only) | DBA | | CloudWatch `CDCLatencySource/Target` | Yes |
| Validation from the rehearsal: row counts and content hashes match | DBA | | [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) output | Yes |
| Secondary indexes, foreign keys, views, routines, triggers recreated on Aurora | DBA | | Schema comparison | Yes |
| Source MySQL backup taken and restore-tested | DBA | | Backup log, restore test | Yes |
| Aurora writer and reader available; automated backups on | DBA | | RDS console | Yes |

## Servers

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| MGN replication `CONTINUOUS` with low lag for Intranet, FTP, NTP | Cloud engineer | | `mgn-lifecycle.sh status` | Yes |
| Test launches passed the [server validation checklist](../server-migration/hyper-v-to-aws/cutover-validation-checklist.md) | Cloud engineer | | Signed checklist | Yes |
| Launch templates use private subnets, correct security groups, SSM instance profile, tags | Cloud engineer | | Launch template review | Yes |
| Hyper-V VM checkpoints/exports exist | Cloud engineer | | Hyper-V export list | Yes |
| Instance sizes reviewed | Cloud engineer | | Sizing note | No |

## Networking

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| Site-to-Site VPN tunnels up; `vpn-down` alarm `OK` | Network engineer | | VPN console | Yes |
| DNS TTLs lowered at least 24 hours ago | Network engineer | | DNS export | Yes |
| DNS change and rollback records prepared | Network engineer | | Change ticket | Yes |
| Office clients can reach the app subnet on 443, 22, UDP 123 | Network engineer | | Test from office | Yes |

## Security

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| [Security checklist](../security/security-checklist.md) phases 1–2 complete | Security lead | | Signed checklist | Yes |
| No open high-severity GuardDuty findings | Security lead | | GuardDuty console | Yes |
| Aurora and EBS encrypted; TLS required on Aurora | Security lead | | Console / `validation-queries.sql` section 1 | Yes |
| Application uses a least-privilege DB user (not `hradmin`) | DBA | | `SHOW GRANTS` | Yes |
| No security group allows `0.0.0.0/0` inbound | Security lead | | Security group review | Yes |

## Monitoring

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| Monitoring stack deployed; dashboard shows data | Cloud engineer | | Dashboard screenshot | Yes |
| SNS subscription confirmed; test notification received | Cloud engineer | | Email received | Yes |
| CloudTrail logging; security alarms in `OK` | Security lead | | CloudTrail status | Yes |
| SSM Agent online on test instances | Cloud engineer | | Fleet Manager | No |

## Backup

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| Source database backup restorable | DBA | | Restore test | Yes |
| Hyper-V VMs exported or checkpointed | Cloud engineer | | Export list | Yes |
| Aurora backup retention set (7 days) | DBA | | RDS console | Yes |
| Post-cutover manual snapshot step assigned | DBA | | Runbook owner | No |

## Application Validation

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| Intranet test instance reads and writes HR data on Aurora | Service owner | | UAT sign-off | Yes |
| SFTP upload/download tested with a real user account | Service owner | | UAT sign-off | Yes |
| NTP clients sync against the test instance or Amazon Time Sync plan approved | Cloud engineer | | `chronyc` / `w32tm` output | Yes |
| Performance within tolerance of the on-premises baseline | Service owner | | Timing comparison | No |

## Business / Stakeholder Readiness

| Check | Owner | Status | Evidence | Blocking? |
|---|---|---|---|---|
| Maintenance window approved and communicated | Communications | | Notice | Yes |
| All cutover roles present and contactable | Cutover lead | | Roll call | Yes |
| Rollback plan and decision deadline agreed | Cutover lead, Service owner | | Signed plan | Yes |
| No conflicting business event (payroll run, audit) during the window | Service owner | | Calendar | Yes |
| Service desk briefed | Communications | | Briefing note | No |

---

## Decision Record

| Field | Value |
|---|---|
| Meeting time | |
| Decision | ☐ GO  ☐ NO-GO |
| Blocking items open | |
| Accepted non-blocking risks | |
| Rollback decision deadline | |
| Cutover lead | |
| Service owner | |
