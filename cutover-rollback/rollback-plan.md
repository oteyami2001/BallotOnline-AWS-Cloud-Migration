# ↩️ Rollback Plan

How BallotOnline returns to the on-premises environment if the AWS cutover fails, and why rollback gets harder the longer the new environment takes production writes.

> **Scope:** recommended procedure. No production rollback was performed. The course project planned a rollback strategy, and this document expands it using the repository's artifacts.

---

## Rollback Triggers

Example thresholds below are **proposed** and need agreement from the service owner before cutover.

| Trigger | Example condition | Typical response |
|---|---|---|
| **Data integrity failure** | Row counts or content hashes differ on critical tables; DMS validation failures that can't be explained | Rollback if not fixed before the decision deadline |
| **Application unavailable** | Intranet or SFTP unavailable for more than 30 minutes after cutover | Fix if the cause is clear (DNS, security group), else rollback |
| **Severe performance degradation** | Response times more than 3× the on-premises baseline for core HR pages | Tune or resize if possible within the window, else rollback |
| **Critical security issue** | High-severity GuardDuty finding, exposed data, or a missing control (for example TLS not enforced) | Contain first; rollback if the environment can't be trusted |
| **Network / connectivity failure** | VPN down, so office users can't reach AWS | Restore the VPN or switch to the backup tunnel; rollback if not restored within the window |
| **Unacceptable DMS synchronization problem** | Final sync can't complete, CDC latency won't drain, or tables suspended | Stay on source (no-go) or rollback |

---

## Decision Flow

```text
 Problem detected (alarm, validation failure, user report)
        │
        ▼
 Assess severity ──── Low / workaround exists ───▶ Continue on AWS, log issue, fix after cutover
        │
     High / critical
        │
        ▼
 Can it be resolved within the cutover window
 and before the rollback decision deadline?
        │                         │
       Yes                        No
        │                         │
        ▼                         ▼
 Fix, re-validate,         Have users written to Aurora yet?
 continue                         │                 │
                                 No                Yes
                                  │                 │
                                  ▼                 ▼
                     Simple rollback       Rollback with data reconciliation
                     (switch back)         (reverse sync or replay; see below)
```

The **cutover lead and service owner** decide together. The decision and its reasoning go in the cutover log.

---

## Data Consistency After Cutover

Rollback is **not** just switching DNS back once the application has written to Aurora:

| Situation | What happens on rollback |
|---|---|
| **Before writes on Aurora** (cutover steps 1–5) | The source MySQL was read-only and unchanged. Lift `read_only` on the source, point the application back, revert DNS. No data is lost. |
| **After writes on Aurora** (step 6 onwards) | Any HR records created or changed in AWS exist **only in Aurora**. Pointing the application back to MySQL without bringing them over **loses those changes** and may leave the two databases inconsistent. |

Options when Aurora has new writes, in order of preference:

1. **Reverse replication (prepare before cutover).** A DMS task with Aurora as source and the on-premises MySQL as target, created in advance and started at cutover, keeps MySQL current. It requires binary logging on Aurora (`binlog_format = ROW` in the cluster parameter group, **not** set in `03-aurora.yaml` today) and a DMS user on Aurora. It costs extra effort, so decide during planning.
2. **Targeted replay.** Identify rows changed since cutover (for example by `updated_at` timestamps or audit tables), export them from Aurora, and apply them to MySQL. This only works if the schema records change times.
3. **Accept data loss.** Only with explicit, written approval from the service owner, and only for a short window with few changes.

Because of this, set a **rollback decision deadline** (for example T+4 hours). After it, problems are fixed forward on AWS unless option 1 is in place.

---

## Rollback Procedures

### Database

1. Put the HR application in maintenance mode (stop new writes to Aurora).
2. If Aurora received writes, reconcile them using the option chosen above.
3. On the source MySQL: `SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;`
4. Point the application connection string back to the on-premises MySQL.
5. Run [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) (row counts and hashes) against MySQL for critical tables.
6. Keep Aurora running and take a snapshot, `rollback-<date>`, for investigation.

### Application and Servers (AWS MGN)

| Server | State | Rollback |
|---|---|---|
| Intranet | Stateless app tier | Start the Hyper-V VM, revert DNS, stop the EC2 instance (don't terminate) |
| FTP / SFTP | **Stateful**: users may have uploaded files to EC2 | Copy files uploaded after cutover from EC2 back to the Hyper-V VM *before* reverting DNS, then start the VM |
| NTP | Stateless | Start the VM and revert DNS; or keep clients on Amazon Time Sync if acceptable |

**MGN considerations:**

- **Don't finalize cutover** (`mgn-lifecycle.sh finalize`) until the rollback window closes. Finalizing stops replication and cleans up replication resources.
- The source VMs stay **powered off but intact** during the window, so starting them is the rollback.
- After a rollback, the source servers are still registered in MGN. Fix the issue, run a new test launch, and schedule another cutover. Data replication continues in the background, or can be restarted.

### DNS and Network

1. Revert the Intranet, FTP, and NTP records to the on-premises addresses. Low TTLs, set at T-7 days, make this take effect in minutes.
2. Check that clients resolve the old addresses (`nslookup`), and flush client DNS caches if needed.
3. Keep the VPN up. It's still needed for investigation and the next attempt.

---

## After a Rollback

- [ ] Users notified that service is back on the original environment
- [ ] Source database validated; application working on premises
- [ ] Root cause recorded; fixes assigned
- [ ] AWS resources kept for investigation (snapshots, stopped instances, logs)
- [ ] Lessons learned added to the runbooks
- [ ] New go/no-go scheduled only after the blocking cause is fixed and re-tested

## Related

- [Cutover runbook](cutover-runbook.md) · [Go/no-go checklist](go-no-go-checklist.md) · [Business continuity](business-continuity.md)
