# BallotOnline AWS Cloud Migration

**On-Premises → AWS** · MySQL → Aurora · Hyper-V → EC2 · DMS · MGN · CloudFormation · Security · Monitoring · DR

[![Validate](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml/badge.svg)](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml)

![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat-square)
![Amazon EC2](https://img.shields.io/badge/Amazon_EC2-FF9900?style=flat-square)
![Amazon Aurora](https://img.shields.io/badge/Amazon_Aurora-527FFF?style=flat-square)
![AWS DMS](https://img.shields.io/badge/AWS_DMS-01A88D?style=flat-square)
![AWS MGN](https://img.shields.io/badge/AWS_Application_Migration_Service-01A88D?style=flat-square)
![CloudFormation](https://img.shields.io/badge/CloudFormation-E7157B?style=flat-square)
![CloudWatch](https://img.shields.io/badge/CloudWatch-E7157B?style=flat-square)
![Systems Manager](https://img.shields.io/badge/Systems_Manager-E7157B?style=flat-square)
![IAM](https://img.shields.io/badge/IAM-DD344C?style=flat-square)
![KMS](https://img.shields.io/badge/KMS-DD344C?style=flat-square)
![GuardDuty](https://img.shields.io/badge/GuardDuty-DD344C?style=flat-square)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-333333?style=flat-square&logo=linux&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)

---

## Executive Summary

**BallotOnline** runs its HR database and internal services on aging on-premises infrastructure. A MySQL server holds employee records, and a single Microsoft Hyper-V host runs the Intranet, FTP, and NTP servers. The environment has limited capacity, no high availability, manual database administration, and little centralized security logging or monitoring.

The objective is to move these workloads to AWS with minimal disruption, while improving availability, security, and operations. Two strategies were chosen per workload:

- **Replatform** the MySQL HR database to **Amazon Aurora MySQL** using **AWS DMS**, which removes manual backups, patching, and failover work without application changes.
- **Rehost** the Hyper-V servers to **Amazon EC2** using **AWS Application Migration Service (MGN)**, the fastest and lowest-risk path for these workloads.

The target runs in a private, two-Availability-Zone VPC connected to the office by Site-to-Site VPN. Security is built in: least-privilege IAM with MFA, KMS encryption, TLS everywhere, Secrets Manager, CloudTrail, and GuardDuty. Operations use CloudWatch alarms, EventBridge, Systems Manager, and Trusted Advisor, backed by cutover, rollback, and disaster recovery runbooks.

The project began as UMGC coursework. This repository turns it into an engineering portfolio, with seven CloudFormation stacks, migration scripts, validation SQL, IAM policies, runbooks, and CI that checks everything on every pull request.

---

## Target Architecture

![BallotOnline AWS target architecture](architecture/diagrams/aws-target-architecture.svg)

Full design: [`architecture/migration-architecture.md`](architecture/migration-architecture.md). Before, during, and after-migration views, network and security design, and design decisions.

---

## What I Built

| Area | Implementation |
|---|---|
| **Database Migration** | MySQL → AWS DMS → Aurora MySQL: [source preparation SQL](database-migration/mysql/source-preparation.sql), [table mappings](database-migration/aws-dms/table-mappings.json) and [task settings](database-migration/aws-dms/task-settings.json), [validation SQL](database-migration/aurora/validation-queries.sql) |
| **Server Migration** | Hyper-V → AWS MGN → EC2: [runbook](server-migration/hyper-v-to-aws/README.md), agent install scripts, [MGN lifecycle script](server-migration/hyper-v-to-aws/scripts/mgn-lifecycle.sh), [validation checklist](server-migration/hyper-v-to-aws/cutover-validation-checklist.md) |
| **Networking** | VPC across two AZs; public, app, DB, and staging subnets; NAT; routing; Site-to-Site VPN; Flow Logs |
| **Infrastructure as Code** | [Seven AWS CloudFormation stacks](infrastructure-as-code/cloudformation/) with an ordered [`deploy.sh`](infrastructure-as-code/cloudformation/deploy.sh) |
| **Security** | IAM least privilege and [MFA policies](security/iam-policies/), KMS, Secrets Manager, TLS-only database, CloudTrail, GuardDuty, IAM Access Analyzer |
| **Monitoring** | CloudWatch alarms (22) and dashboard, CIS-style security alarms, SNS alerting, EventBridge rules |
| **Operations** | Systems Manager (Session Manager, Patch Manager, Inventory, read-only [Automation runbook](monitoring/systems-manager/automation-runbook.yaml)), [Trusted Advisor review](monitoring/trusted-advisor/README.md) |
| **Cutover & DR** | [Cutover runbook](cutover-rollback/cutover-runbook.md), [go/no-go](cutover-rollback/go-no-go-checklist.md), [rollback plan](cutover-rollback/rollback-plan.md), [DR](cutover-rollback/disaster-recovery.md): Aurora backups and PITR, EC2 recovery, rebuild from code |
| **CI** | [GitHub Actions](.github/workflows/validate.yml): `cfn-lint`, `shellcheck`, JSON/YAML syntax, SVG/XML checks, Markdown link check, secret-pattern scan |

---

## Project Scope and Evidence

| Label | Meaning | Examples |
|---|---|---|
| 🎓 **Academic work** | Activities performed in the UMGC BallotOnline cloud migration coursework | Migration strategy (replatform DB, rehost servers); AWS DMS endpoints `ccs640mysql` / `ccs640target` and Full Load task `ccs640migration` configured and run in the course lab, including the troubleshooting below; Hyper-V rehost planned; CloudFormation, CloudWatch, Systems Manager, and Trusted Advisor evaluated |
| 🛠️ **Portfolio implementation** | Code, templates, scripts, automation, diagrams, and runbooks created to turn the academic design into an engineering portfolio | Everything in this repository: CloudFormation stacks, scripts, SQL, IAM policies, runbooks, diagrams, CI |
| 📋 **Production recommendations** | Controls and practices recommended for a real deployment but not implemented or run | Proposed RTO/RPO targets, reverse-replication rollback, AWS Backup plans, cross-Region copies, alarms marked *recommended* |

> **Deployment status:** the infrastructure templates in this repository have been statically validated and tested where possible (`cfn-lint`, `shellcheck`, SQL against a local MySQL 8.0, AWS CLI parameter validation), but the complete environment has **not** been deployed as a production BallotOnline system in a live AWS account. No production cutover, rollback, or DR test was performed.

---

## Key Engineering Challenges

These issues came up while running AWS DMS in the course lab. The troubleshooting below is what the repository documents and now guards against. It is not a claim that a production migration was completed.

| Challenge | What happened | Troubleshooting approach | Where the repo addresses it |
|---|---|---|---|
| **Source endpoint connection failure** | Premigration assessment reported an ODBC-related failure connecting to the source MySQL | Checked source availability, credentials, routing, security rules, permissions, DNS | [DMS write-up](database-migration/aws-dms/README.md#issue-1--source-endpoint-connection-failure); endpoint tests are a blocking [go/no-go](cutover-rollback/go-no-go-checklist.md) item |
| **Hostname / DNS resolution (`DMS-00001`)** | Endpoint test: the MySQL server host name could not be resolved | Traced it to name resolution from the replication instance | The [CloudFormation README](infrastructure-as-code/cloudformation/README.md#-design-notes) explains why: the VPC resolver doesn't know on-prem names. Fix by using the private IP or a Route 53 Resolver outbound endpoint. |
| **"No tables were found at task initialization" (`FATAL_ERROR`)** | Task stopped with no tables selected | Checked connectivity, schema name, table-mapping rules, and the migration user's grants; reviewed task logs | [`table-mappings.json`](database-migration/aws-dms/table-mappings.json) with an exact schema name; `SHOW GRANTS` check in [`source-preparation.sql`](database-migration/mysql/source-preparation.sql) |
| **Schema and mapping considerations** | DMS creates tables and primary keys only | Inventory of views, routines, triggers, and tables without primary keys before migrating | Sections 4–7 of `source-preparation.sql`; schema checks in `validation-queries.sql` |
| **Database permissions** | The migration user needs read and replication rights, but no more | Dedicated `dms_migration` user, restricted to the DMS subnet, TLS required | `source-preparation.sql`, [security controls](security/security-controls.md#database-accounts) |
| **Migration validation** | A finished task does not prove the data is correct | Row counts, content hashes, spot checks, DMS row-level validation | [`validation-queries.sql`](database-migration/aurora/validation-queries.sql) with a sign-off checklist |

---

## Lessons Learned

- **Validate connectivity before migration.** Test both DMS endpoints before creating a task.
- **Test DNS resolution** from where the migration actually runs, not from your laptop.
- **Validate schema names and table mappings.** One wrong name selects zero tables.
- **Apply least privilege** to migration accounts and remove them afterwards.
- **Plan and test rollback before cutover.** Once users write to the target, rollback needs data reconciliation, not just a DNS change.
- **Treat monitoring as part of migration design,** not something added after go-live.
- **Infrastructure as Code improves repeatability,** for rebuilds, DR, and review.
- **Migration success needs technical and business validation:** correct data *and* users signing off.

---

## Repository Navigation

| Section | What you'll find |
|---|---|
| [Architecture](architecture/) | Target design, network/security design, five diagrams |
| [Database Migration](database-migration/) | DMS write-up and troubleshooting, source prep SQL, mappings and settings, validation SQL |
| [Server Migration](server-migration/hyper-v-to-aws/) | MGN runbook, agent install and lifecycle scripts, validation checklist |
| [Infrastructure as Code](infrastructure-as-code/cloudformation/) | Seven CloudFormation stacks and `deploy.sh` |
| [Security](security/) | Controls by layer, risk register, IAM policies, security checklist |
| [Monitoring](monitoring/) | Alarm catalog, CloudWatch, Systems Manager, Trusted Advisor, operations model |
| [Cutover & Rollback](cutover-rollback/) | Cutover runbook, go/no-go, rollback plan, post-cutover validation |
| [Disaster Recovery](cutover-rollback/disaster-recovery.md) | Backups, PITR, EC2 recovery, rebuild from code, RTO/RPO, business continuity |
| [Evidence](screenshots/) | Sanitized screenshot categories and redaction rules |
| [Interview Talking Points](docs/interview-talking-points.md) | STAR-style summaries of the project |

---

## Repository Status

| Item | Status |
|---|---|
| CI | [![Validate](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml/badge.svg)](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml) |
| Documentation | Complete for all phases: architecture, database, servers, IaC, security, monitoring, cutover, DR |
| Project type | Academic project (UMGC) + engineering portfolio |
| AWS deployment | Not deployed as a complete production environment; templates statically validated |
| Evidence | Screenshot categories defined; sanitized screenshots added only when available |

---

## Skills Demonstrated

`AWS Architecture` `Cloud Migration` `AWS DMS` `AWS MGN` `Amazon Aurora` `Amazon EC2` `CloudFormation` `IAM` `KMS` `CloudWatch` `Systems Manager` `Networking` `Security` `Linux` `MySQL` `Disaster Recovery` `GitHub Actions` `Troubleshooting`

---

## Repository Structure

```text
BallotOnline-AWS-Cloud-Migration/
├── architecture/
│   ├── migration-architecture.md      # before / during / after design
│   └── diagrams/                      # target, DMS, MGN, monitoring, cutover (SVG)
├── database-migration/
│   ├── mysql/source-preparation.sql
│   ├── aws-dms/                       # write-up, table-mappings.json, task-settings.json
│   └── aurora/validation-queries.sql
├── server-migration/hyper-v-to-aws/   # MGN runbook, scripts, validation checklist
├── infrastructure-as-code/cloudformation/
│   ├── 01-network.yaml … 07-operations.yaml
│   └── deploy.sh
├── security/                          # controls, checklist, IAM policies
├── monitoring/                        # CloudWatch, Systems Manager, Trusted Advisor, operations
├── cutover-rollback/                  # runbook, go/no-go, rollback, validation, DR, continuity
├── screenshots/                       # sanitized evidence by category
├── docs/interview-talking-points.md
└── .github/                           # CI workflow and link checker
```

---

## Academic Context and Author

This project originated as the **BallotOnline cloud migration** case study in the Master of Science in Cloud Computing Systems program at the **University of Maryland Global Campus (UMGC)**. The repository contains original work only; no course materials or assignment instructions are reproduced.

**Thierry A. Oteyami**, Cloud Engineer · Oracle DBA · Software Developer
GitHub: [@oteyami2001](https://github.com/oteyami2001)
