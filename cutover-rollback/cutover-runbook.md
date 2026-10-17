# 🚀 Cutover Runbook

Step-by-step procedure for moving BallotOnline's production workloads from the on-premises environment to AWS:

- **HR database:** MySQL → Aurora MySQL with AWS DMS
- **Intranet, FTP, and NTP servers:** Hyper-V → EC2 with AWS MGN

> **Scope:** this runbook is a procedure, not a record of an event. No production cutover was performed. In the UMGC course project, DMS was configured and run in a lab environment. The rest of this runbook is the recommended production procedure built on the artifacts in this repository.

---

## Roles

| Role | Responsibility during cutover |
|---|---|
| **Cutover lead** | Owns the timeline, runs the go/no-go meeting, makes the continue/rollback call with the service owner |
| **Database administrator (DBA)** | Source write freeze, final DMS sync, data validation |
| **Cloud engineer** | MGN cutover launches, EC2 validation, CloudFormation, monitoring |
| **Network engineer** | VPN, DNS changes and rollback |
| **Security lead** | Security validation, GuardDuty and CloudTrail review |
| **Service owner (HR / IT)** | Business sign-off, user acceptance, go/no-go vote |
| **Communications** | Stakeholder notices before, during, and after |

---

## Choosing the Database Cutover Method

| | **Option A: Full Load + CDC** (recommended) | **Option B: Full Load only** (as configured in the course project) |
|---|---|---|
| DMS task | `MigrationType=full-load-and-cdc` | `MigrationType=full-load` (`ccs640migration`) |
| What happens before the window | Full Load done days earlier; CDC keeps Aurora seconds behind | Nothing; the load runs inside the window |
| Write freeze during cutover | Minutes: wait for CDC latency to reach ~0 | Full duration of the load plus validation |
| Source requirements | Binary logging `ROW`, replication grants (see [`source-preparation.sql`](../database-migration/mysql/source-preparation.sql)) | `SELECT` only |
| Best for | Production with limited downtime | Small databases or long maintenance windows |

---

## T-7 Days: Readiness

| # | Task | Owner | Evidence |
|---|---|---|---|
| 1 | Confirm migration readiness: DMS task has completed at least one successful Full Load in a rehearsal; MGN servers are `READY_FOR_CUTOVER` after a successful test launch | Cutover lead | DMS table statistics; `mgn-lifecycle.sh status` output |
| 2 | Review the open risks in the [risk register](../security/security-controls.md#7-migration-specific-risks); every high risk has a mitigation or acceptance | Cutover lead, Security lead | Updated risk register |
| 3 | Verify backups: source MySQL full backup taken and restore-tested; Hyper-V VM checkpoints/exports exist; Aurora automated backups enabled | DBA, Cloud engineer | Backup job logs, restore test result |
| 4 | Verify monitoring: [`06-monitoring`](../infrastructure-as-code/cloudformation/06-monitoring.yaml) deployed, SNS subscription confirmed, dashboard shows data | Cloud engineer | Test alarm notification received |
| 5 | Confirm the [rollback plan](rollback-plan.md): triggers agreed, decision deadline set, reverse-sync approach chosen | Cutover lead, DBA | Signed rollback plan |
| 6 | Confirm stakeholder responsibilities, contact list, and escalation path | Cutover lead | Contact sheet |
| 7 | Lower DNS TTLs for the Intranet, FTP, NTP, and database records (for example to 60 seconds) | Network engineer | DNS record export |
| 8 | Announce the maintenance window to users | Communications | Sent notice |

## T-24 Hours: Final Checks

| # | Task | Owner | How |
|---|---|---|---|
| 1 | DMS status: task healthy, CDC latency low (Option A), last validation clean | DBA | DMS console; `awsdms_validation_failures_v1` empty |
| 2 | Aurora health: writer and reader available, no alarms, backups current | DBA | RDS console; dashboard `ballotonline-operations` |
| 3 | Migrated EC2 health: test instances passed the [validation checklist](../server-migration/hyper-v-to-aws/cutover-validation-checklist.md); replication `CONTINUOUS` | Cloud engineer | `mgn-lifecycle.sh status` |
| 4 | Review CloudWatch alarms: nothing in `ALARM` | Cloud engineer | CloudWatch → Alarms |
| 5 | Application and network connectivity: VPN tunnels up; Intranet test instance can reach Aurora over TLS | Network engineer | `vpn-down` alarm `OK`; test query |
| 6 | Confirm the maintenance window and hold the [go/no-go](go-no-go-checklist.md) pre-check | Cutover lead | Calendar confirmation; pre-check results |

## T-1 Hour: Assemble

| # | Task | Owner |
|---|---|---|
| 1 | Notify stakeholders that cutover starts in one hour | Communications |
| 2 | Confirm every role is present on the bridge call | Cutover lead |
| 3 | Verify source ↔ target connectivity: DMS endpoint test-connection succeeds for `ccs640mysql` and `ccs640target` | DBA |
| 4 | Re-read the rollback triggers and the decision deadline aloud | Cutover lead |
| 5 | Run the **go/no-go** meeting. Any unresolved blocking item = **NO-GO**. | Cutover lead, Service owner |

---

## T0: Cutover Window

Rollback is simple **until step 6**. After step 6, users write to Aurora, and rolling back means bringing those writes back to MySQL (see [rollback plan](rollback-plan.md#data-consistency-after-cutover)).

| # | Step | Owner | Verification |
|---|---|---|---|
| 1 | **Restrict writes:** put the HR application in maintenance mode, then block writes on the source MySQL (`SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;`). Stop services on the source Hyper-V VMs that accept uploads (FTP). | DBA, Cloud engineer | Test write is rejected; no active write sessions |
| 2 | **Final database sync.** *Option A:* wait until DMS CDC latency is ~0 and no new changes arrive, then stop the task. *Option B:* run the Full Load task and wait for `Load complete`. | DBA | DMS table statistics: all tables `Table completed`; latency 0 |
| 3 | **Validate consistency:** run [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) on source and target: row counts, content hashes, critical records; DMS validation failures = 0 | DBA | Signed validation output |
| 4 | **MGN cutover:** launch cutover instances for the servers whose source services are now stopped: `mgn-lifecycle.sh cutover s-...` | Cloud engineer | Instances `running`, 2/2 status checks |
| 5 | **Validate workloads** on the cutover instances: Intranet (HTTPS, login, HR data from Aurora), SFTP (login, upload/download), NTP (clients sync) | Cloud engineer, Service owner | [Post-cutover validation](post-cutover-validation.md) sections EC2 and Aurora |
| 6 | **Switch connectivity:** point the Intranet application at the Aurora **cluster endpoint**; update DNS records for Intranet, FTP, and NTP to the EC2 private IPs. Lift maintenance mode. | Network engineer, DBA | DNS resolves to new IPs; users can sign in |
| 7 | **Monitor:** watch the dashboard, alarms, application errors, and GuardDuty for the first hour | Cloud engineer, Security lead | No critical alarms |
| 8 | Announce that cutover is complete, and keep the bridge open until T+1h | Communications | Notice sent |

Keep the on-premises MySQL **read-only but running**, and the Hyper-V VMs **powered off but intact**, until the rollback window closes.

---

## T+1 Hour: Early Validation

- [ ] Intranet, SFTP, and NTP working for real users (not only test accounts)
- [ ] CloudWatch alarms reviewed; no critical alarm open
- [ ] Aurora CPU, connections, and latency within normal ranges; no failover events
- [ ] Application and OS logs show no new error patterns
- [ ] User access confirmed through the service desk
- [ ] **Continue / rollback decision recorded** (see [rollback plan](rollback-plan.md))

## T+24 Hours: Stabilization and Sign-off

- [ ] Full [post-cutover validation](post-cutover-validation.md) completed
- [ ] Aurora automated backup and a manual snapshot `post-cutover-<date>` exist
- [ ] EC2 instances in Patch Manager and Inventory; CloudWatch agent reporting memory and disk
- [ ] Security review: no new GuardDuty findings or security alarms; CloudTrail logging
- [ ] DMS task stopped and kept until the rollback window closes, then delete the DMS stack (`./deploy.sh delete dms`)
- [ ] **Operational sign-off** from the service owner and operations team
- [ ] After the rollback window: `mgn-lifecycle.sh finalize`, then `archive`; restore normal DNS TTLs; schedule on-premises decommissioning

---

## Related

- [Go/no-go checklist](go-no-go-checklist.md) · [Rollback plan](rollback-plan.md) · [Post-cutover validation](post-cutover-validation.md)
- [DMS write-up](../database-migration/aws-dms/README.md) · [MGN runbook](../server-migration/hyper-v-to-aws/README.md) · [Security checklist](../security/security-checklist.md)
