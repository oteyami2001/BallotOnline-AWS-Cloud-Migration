# 🔄 Cutover, Rollback, Disaster Recovery & Business Continuity

How BallotOnline's workloads move from the on-premises environment to AWS production, how to go back safely if they must, and how the new environment survives failures afterwards.

![BallotOnline cutover and rollback flow](../architecture/diagrams/cutover-rollback-flow.svg)

---

## 📌 Project Scope

| Category | What it covers |
|---|---|
| **1. UMGC course project** | The cutover and rollback strategy was **planned** for BallotOnline. AWS DMS endpoints and a Full Load task (`ccs640migration`) were configured and run in the course lab, including troubleshooting of endpoint and table-mapping errors. **No production cutover, rollback, or DR test took place.** |
| **2. Represented in this repository** | Procedures and checklists in this folder, linked to the repository's validation SQL, MGN scripts and checklist, CloudFormation stacks, and monitoring. None of it has been run against a real AWS account. |
| **3. Recommended production practice** | Timings, thresholds, proposed RTO/RPO targets, reverse-replication option, and test schedules. These are labeled *proposed* and need business approval. |

---

## Contents

| Document | Purpose |
|---|---|
| [`cutover-runbook.md`](cutover-runbook.md) | T-7 days → T+24 hours timeline, roles, database cutover options, step-by-step cutover |
| [`go-no-go-checklist.md`](go-no-go-checklist.md) | Formal decision checklist by category (`Check · Owner · Status · Evidence · Blocking?`) |
| [`rollback-plan.md`](rollback-plan.md) | Triggers, decision flow, data-consistency implications, database / server / DNS / MGN rollback |
| [`post-cutover-validation.md`](post-cutover-validation.md) | Aurora, EC2, security, and monitoring validation with sign-off |
| [`disaster-recovery.md`](disaster-recovery.md) | Backups, PITR, snapshots, EC2 recovery, rebuild from CloudFormation, secrets, logs, restore testing, RTO/RPO |
| [`business-continuity.md`](business-continuity.md) | Continuity during resource, AZ, database, VPN, security, and change failures; dependencies and escalation |

---

## Cutover at a Glance

```text
T-7 days    Readiness: rehearsal results, risks, backups, monitoring, rollback plan, DNS TTLs lowered
T-24 hours  DMS / Aurora / EC2 health, alarms, connectivity, go/no-go pre-check
T-1 hour    Team assembled, connectivity re-tested, GO / NO-GO decision
T0          Freeze writes → final DMS sync → validate → MGN cutover → validate → switch DNS/app
T+1 hour    Early validation, continue/rollback decision
T+24 hours  Full validation, backups, operational sign-off
Later       Rollback window closes → finalize MGN, delete DMS, decommission on-premises
```

**Key principle:** rollback is a simple switch-back only **until users write to Aurora**. After that, data written in AWS has to be brought back to MySQL. That's why the plan has a decision deadline and an optional reverse-replication task. See [data consistency after cutover](rollback-plan.md#data-consistency-after-cutover).

---

## Artifacts Reused from Earlier Phases

| Need | Artifact |
|---|---|
| Database validation | [`database-migration/aurora/validation-queries.sql`](../database-migration/aurora/validation-queries.sql) |
| Source preparation and DMS settings | [`database-migration/`](../database-migration/) |
| Server cutover commands | [`mgn-lifecycle.sh`](../server-migration/hyper-v-to-aws/scripts/mgn-lifecycle.sh) |
| Server validation | [`cutover-validation-checklist.md`](../server-migration/hyper-v-to-aws/cutover-validation-checklist.md) |
| Environment build and rebuild | [`infrastructure-as-code/cloudformation/`](../infrastructure-as-code/cloudformation/) |
| Security sign-off | [`security/security-checklist.md`](../security/security-checklist.md) |
| Alarms, dashboard, SSM | [`monitoring/`](../monitoring/) |
