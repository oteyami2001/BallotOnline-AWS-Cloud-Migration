# 🗄️ BallotOnline Database Migration — AWS DMS

![BallotOnline AWS DMS migration flow](../../architecture/diagrams/aws-dms-migration-flow.svg)

## Overview

This section documents the migration of BallotOnline's on-premises **MySQL HR database** to **Amazon Aurora MySQL** using **AWS Database Migration Service (AWS DMS)**.

The database workload uses a **replatforming strategy** because the existing MySQL database is moved to a managed AWS relational database platform rather than being hosted on a traditional virtual machine.

The migration workflow includes source and target preparation, network connectivity, endpoint configuration, replication, Full Load, Change Data Capture (CDC), validation, troubleshooting, and final cutover.

---

## 🎯 Migration Objective

The objective is to migrate the BallotOnline HR database to AWS while minimizing service interruption and maintaining data integrity.

| | |
|---|---|
| **Source** | On-premises MySQL database (BallotOnline HR data) |
| **Target** | Amazon Aurora MySQL-Compatible Edition |
| **Migration Service** | AWS Database Migration Service (AWS DMS) |
| **Migration Strategy** | Replatform |

---

## 🏗️ Migration Architecture

```text
┌──────────────────────┐
│ BallotOnline         │
│ On-Premises          │
│                      │
│ MySQL HR Database    │
└──────────┬───────────┘
           │
           │ Secure Connectivity
           │ TCP 3306
           ▼
┌──────────────────────────┐
│ AWS Database Migration   │
│ Service                  │
│                          │
│ Source Endpoint          │
│ Replication              │
│ Full Load + CDC          │
│ Target Endpoint          │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Amazon Aurora MySQL      │
│ BallotOnline HR Database │
└──────────────────────────┘
```

---

## 🔄 Migration Workflow

The migration is divided into the following stages:

1. Assess the source MySQL database
2. Prepare the source database
3. Provision Amazon Aurora MySQL
4. Configure network connectivity
5. Configure security groups
6. Create the AWS DMS source endpoint
7. Create the AWS DMS target endpoint
8. Test endpoint connectivity
9. Configure replication resources
10. Create the migration task
11. Run Full Load
12. Enable Change Data Capture where required
13. Validate migrated data
14. Test applications
15. Perform final synchronization
16. Execute production cutover

---

## 1. Source Database Preparation

The source environment contains the existing BallotOnline MySQL HR database.

Before migration, the source database should be evaluated for:

- Database version compatibility
- User permissions
- Network accessibility
- Database size
- Table structure
- Primary keys
- Character sets
- Binary logging
- Replication requirements

The migration account should receive only the permissions necessary for AWS DMS.

## 2. Amazon Aurora Target

Amazon Aurora MySQL-Compatible Edition is used as the target database.

Aurora provides a managed relational database platform that reduces administrative overhead associated with traditional database infrastructure.

The target environment should be configured with:

- Appropriate DB instance sizing
- Private networking
- Security groups
- Encryption
- Backup configuration
- Monitoring
- Parameter groups
- High availability where required

## 3. AWS DMS Endpoints

AWS DMS uses endpoints to connect to source and target databases.

| Endpoint | Represents | Project Endpoint Name |
|---|---|---|
| Source | BallotOnline MySQL database | `ccs640mysql` |
| Target | AWS-hosted target database | `ccs640target` |

> Endpoint names are included for educational documentation. Credentials, account identifiers, hostnames, and sensitive connection information are intentionally excluded.

## 4. Network Connectivity

AWS DMS must be able to communicate with both databases.

Important considerations include:

- DNS resolution
- Routing
- Security groups
- Network ACLs
- Database firewall rules
- Database port accessibility
- VPN or other private connectivity
- DMS subnet configuration

For MySQL-compatible databases, TCP port **3306** is commonly required.

Security rules should restrict database connectivity to authorized resources rather than exposing databases publicly.

## 5. Endpoint Testing

Before creating the migration task, both endpoints should be tested.

Expected result:

```text
Source Endpoint → Successful
Target Endpoint → Successful
```

A failed endpoint test should be resolved before starting migration. Common causes include:

- Incorrect hostname
- DNS resolution failure
- Incorrect credentials
- Security group restrictions
- Routing problems
- Database unavailable
- Incorrect port
- Missing permissions

## 6. Migration Task

The project migration task was configured using:

| Setting | Value |
|---|---|
| Task Name | `ccs640migration` |
| Migration Mode | `Full Load` |
| Target Table Preparation Mode | `DROP_AND_CREATE` |

The migration task transfers the selected source tables to the target database.

## 7. Full Load

During Full Load, AWS DMS copies existing records from the source database to the target.

```text
Source MySQL
     │
     │ Existing Data
     ▼
   AWS DMS
     │
     ▼
Aurora MySQL
```

After Full Load, the migrated tables should be validated before production cutover.

## 8. Change Data Capture (CDC)

For migrations requiring minimal downtime, CDC can capture changes made to the source database while migration is occurring.

```text
Initial Data
     │
     ▼
 FULL LOAD
     │
     ▼
Source Changes
     │
     ▼
    CDC
     │
     ▼
Aurora MySQL
```

This allows the source system to remain operational during much of the migration process.

---

## 🔧 Troubleshooting & Lessons Learned

Real-world cloud migrations frequently require troubleshooting. Several important issues were encountered during the BallotOnline migration exercise.

### Issue 1 — Source Endpoint Connection Failure

A premigration assessment reported a source connection failure.

The connection returned an ODBC-related error indicating that AWS DMS could not successfully establish the required source database connection.

**Areas investigated:**

- Source database availability
- MySQL credentials
- Network routing
- Security rules
- Database permissions
- DNS resolution

### Issue 2 — MySQL Hostname Resolution Failure

Testing the source endpoint produced an error indicating that the MySQL server hostname could not be resolved.

The AWS DMS error included:

```text
DMS-00001
```

The underlying problem was related to DNS/hostname resolution.

**Lesson learned:** AWS DMS requires reliable network connectivity and name resolution between its replication resources and the source database. Endpoint testing should therefore be completed successfully before migration tasks are started.

### Issue 3 — No Tables Found

The migration task later reported:

```text
No tables were found at task initialization.
```

The task stopped with:

```text
FATAL_ERROR
```

**Potential causes:**

- Incorrect table mapping rules
- Source connectivity problems
- Incorrect schema selection
- Insufficient database permissions
- Source tables not matching selection rules

**Troubleshooting approach:**

1. Confirm source endpoint connectivity.
2. Verify database credentials.
3. Confirm source schemas and tables exist.
4. Review table mapping rules.
5. Confirm the migration account can read required tables.
6. Review AWS DMS task logs.
7. Run premigration assessments again.
8. Restart the task only after connectivity and mapping issues are resolved.

---

## 🧠 Key Lessons Learned

The exercise demonstrated that database migration involves much more than copying data. Important lessons included:

- Test connectivity before creating migration tasks.
- Validate DNS resolution.
- Use restrictive security rules.
- Confirm source database permissions.
- Validate table mappings.
- Review DMS logs when failures occur.
- Perform premigration assessments.
- Never perform production cutover before validating migrated data.
- Maintain rollback procedures.
- Protect database credentials and sensitive connection information.

---

## 🔐 Security Considerations

Database migration security should include:

- Least-privilege IAM
- Restricted Security Groups
- Encryption at rest
- Encryption in transit
- Secure credential management
- Private database networking where possible
- CloudWatch logging and monitoring
- Database authentication controls
- Removal of credentials from source code and repositories

> Sensitive values are intentionally excluded from this GitHub repository.

---

## ✅ Migration Validation

After successful migration, validation should confirm:

| Category | Checks |
|---|---|
| **Schema validation** | Expected databases exist · Expected tables exist · Column definitions are correct |
| **Data validation** | Row counts · Sample records · Critical business data · Null values · Data types |
| **Application validation** | Application connectivity · Authentication · Queries · Transactions · Performance |

---

## 🚀 Cutover

A production cutover should occur only after successful validation.

Recommended sequence:

```text
Validate Target
      ↓
Confirm CDC Synchronization
      ↓
Schedule Cutover
      ↓
Restrict Source Writes
      ↓
Complete Final Synchronization
      ↓
Validate Target
      ↓
Redirect Application
      ↓
Monitor Production
```

The source environment should remain available during the initial validation period to support rollback if necessary.

---

## ↩️ Rollback

If critical problems occur after cutover, the rollback procedure may include:

1. Stop application traffic to the new target.
2. Assess data consistency.
3. Redirect the application to the original environment where appropriate.
4. Restore required database state.
5. Investigate the migration problem.
6. Correct the issue.
7. Repeat validation before another cutover attempt.

---

## 📊 AWS Services Involved

| Service | Role |
|---|---|
| AWS DMS | Database migration and replication |
| Amazon Aurora MySQL | Target database platform |
| Amazon VPC | Network isolation |
| AWS IAM | Access control |
| Security Groups | Network access control |
| Amazon CloudWatch | Monitoring and logging |

---

## 📸 Evidence

Sanitized project screenshots can be stored in [`screenshots/database-migration/`](../../screenshots/).

Screenshots should never expose:

- AWS account IDs
- Passwords
- Access keys
- Secret keys
- Private hostnames
- Sensitive IP addresses
- Database credentials
- Connection strings

---

## 🎓 Skills Demonstrated

This migration demonstrates practical experience with:

`AWS Database Migration Service` `MySQL` `Amazon Aurora` `Database Migration` `Replatforming` `Endpoint Configuration` `Network Troubleshooting` `DNS Troubleshooting` `Full Load` `Change Data Capture` `Data Validation` `Cloud Security` `Migration Cutover` `Rollback Planning` `CloudWatch Monitoring`

---

## 👨‍💻 Author

**Thierry A. Oteyami**
Cloud Engineer | Oracle DBA | Software Developer
BallotOnline AWS Cloud Migration Project
