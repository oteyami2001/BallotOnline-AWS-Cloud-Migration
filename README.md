# ☁️ BallotOnline AWS Cloud Migration

![AWS](https://img.shields.io/badge/AWS-Cloud_Migration-orange?style=for-the-badge&logo=amazonwebservices)
![Amazon Aurora](https://img.shields.io/badge/Amazon_Aurora-MySQL-blue?style=for-the-badge&logo=amazonrds)
![AWS DMS](https://img.shields.io/badge/AWS_DMS-Database_Migration-orange?style=for-the-badge&logo=amazonwebservices)
![CloudFormation](https://img.shields.io/badge/AWS-CloudFormation-orange?style=for-the-badge&logo=amazonwebservices)
![MySQL](https://img.shields.io/badge/MySQL-Database-blue?style=for-the-badge&logo=mysql)
![Linux](https://img.shields.io/badge/Linux-Server-black?style=for-the-badge&logo=linux)

[![Validate](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml/badge.svg)](https://github.com/oteyami2001/BallotOnline-AWS-Cloud-Migration/actions/workflows/validate.yml)

End-to-end AWS cloud migration project for BallotOnline, including MySQL-to-Aurora migration with AWS DMS, Hyper-V server migration, CloudFormation, security, monitoring, cutover, rollback, and postmigration optimization.

---

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [Project Objectives](#-project-objectives)
- [Migration Architecture](#️-migration-architecture)
- [Cloud Migration Strategy](#-cloud-migration-strategy)
- [AWS Services Used](#️-aws-services-used)
- [AWS Database Migration Service](#️-aws-database-migration-service)
- [Security Architecture](#-security-architecture)
- [Infrastructure as Code](#️-infrastructure-as-code)
- [Monitoring and Management](#-monitoring-and-management)
- [Cutover Strategy](#-cutover-strategy)
- [Rollback Strategy](#️-rollback-strategy)
- [Postmigration Activities](#-postmigration-activities)
- [Cloud Migration Recommendations](#-cloud-migration-recommendations)
- [Repository Structure](#-repository-structure)
- [Skills Demonstrated](#-skills-demonstrated)
- [Academic Context](#-academic-context)
- [Author](#-author)

---

## 📌 Project Overview

The **BallotOnline AWS Cloud Migration Project** is an academic cloud engineering project completed as part of the Cloud Computing Systems program at the **University of Maryland Global Campus (UMGC)**.

The project evaluates, designs, and implements a migration strategy for BallotOnline's existing IT infrastructure to Amazon Web Services (AWS).

The migration focuses on two major workloads:

1. Migrating an on-premises **MySQL HR database** to **Amazon Aurora MySQL**.
2. Migrating **Microsoft Hyper-V virtual servers** hosting infrastructure services to AWS.

The project also covers migration planning, security, automation, monitoring, validation, cutover, rollback, and postmigration optimization.

---

## 🎯 Project Objectives

The primary objectives of this project are to:

- Assess BallotOnline's existing infrastructure.
- Select appropriate cloud migration strategies.
- Compare cloud migration tools.
- Migrate an on-premises MySQL database to AWS.
- Implement AWS Database Migration Service (AWS DMS).
- Design a Hyper-V-to-AWS migration strategy.
- Automate AWS infrastructure deployment.
- Implement security and monitoring controls.
- Validate migrated workloads.
- Develop cutover and rollback procedures.
- Evaluate postmigration optimization opportunities.

---

## 🏗️ Migration Architecture

### Source Environment — On-Premises Infrastructure

- MySQL HR Database
- Microsoft Hyper-V
- Intranet Server
- FTP Server
- NTP Server
- Local Network Infrastructure

### Target AWS Environment

- Amazon VPC
- Amazon EC2
- Amazon Aurora MySQL
- AWS Database Migration Service
- AWS Application Migration Service
- AWS CloudFormation
- Amazon CloudWatch
- AWS Systems Manager
- AWS Trusted Advisor
- AWS IAM
- Security Groups

### High-Level Architecture

![BallotOnline AWS target architecture](architecture/diagrams/aws-target-architecture.svg)

See [`architecture/migration-architecture.md`](architecture/migration-architecture.md) for the full before / during / after design.

#### Text Overview

```text
            ON-PREMISES                                   AWS CLOUD (VPC)
 ┌──────────────────────────────┐           ┌──────────────────────────────────────┐
 │                              │           │                                      │
 │  MySQL HR Database  ─────────┼── DMS ───▶│  Amazon Aurora MySQL (private subnet)│
 │                              │           │                                      │
 │  Hyper-V Hosts               │           │                                      │
 │   ├─ Intranet Server ────────┼── MGN ───▶│  Amazon EC2 (Intranet)               │
 │   ├─ FTP Server      ────────┼── MGN ───▶│  Amazon EC2 (FTP)                    │
 │   └─ NTP Server      ────────┼── MGN ───▶│  Amazon EC2 (NTP)                    │
 │                              │           │                                      │
 └──────────────────────────────┘           │  CloudFormation · IAM · Security     │
                                            │  Groups · CloudWatch · Systems       │
                                            │  Manager · Trusted Advisor           │
                                            └──────────────────────────────────────┘
```

---

## 🔄 Cloud Migration Strategy

Two primary migration approaches were selected.

| Workload | Strategy | AWS Tool | Target |
|----------|----------|----------|--------|
| MySQL HR database | **Replatform** | AWS DMS | Amazon Aurora MySQL |
| Hyper-V servers (Intranet, FTP, NTP) | **Rehost** (lift-and-shift) | AWS Application Migration Service | Amazon EC2 |

### 🗄️ Database Migration — Replatform

The BallotOnline HR MySQL database is migrated from the existing environment to **Amazon Aurora MySQL**.

```text
On-Premises MySQL
        |
        v
AWS Database Migration Service
        |
        v
Amazon Aurora MySQL
```

AWS DMS is used to migrate the database while minimizing service interruption. The migration process includes:

- Source database preparation
- Target database preparation
- AWS DMS endpoints
- Replication configuration
- Full Load
- Change Data Capture (CDC)
- Data validation
- Application testing
- Final cutover

### 🖥️ Hyper-V Migration — Rehost

BallotOnline's Hyper-V workloads use a rehosting (lift-and-shift) migration strategy.

```text
On-Premises Hyper-V
        |
        v
AWS Application Migration Service
        |
        v
Amazon EC2
```

The migrated workloads include services such as:

- Intranet
- FTP
- NTP

The migration process includes replication, testing, validation, cutover, and rollback planning.

---

## 🛠️ AWS Services Used

| AWS Service | Purpose |
|-------------|---------|
| Amazon EC2 | Hosts migrated server workloads |
| Amazon Aurora | Managed MySQL-compatible database |
| AWS DMS | Database migration and replication |
| AWS Application Migration Service | Server migration |
| Amazon VPC | Network isolation |
| AWS IAM | Identity and access management |
| AWS CloudFormation | Infrastructure automation |
| Amazon CloudWatch | Monitoring and logging |
| AWS Systems Manager | Infrastructure management and automation |
| AWS Trusted Advisor | Security, cost, performance, and reliability recommendations |

---

## 🗄️ AWS Database Migration Service

AWS DMS plays a central role in migrating the BallotOnline HR database.

### Migration Stages

1. **Source Preparation** — Configure the existing MySQL database to support migration and replication.
2. **Target Preparation** — Deploy and configure Amazon Aurora MySQL.
3. **DMS Configuration** — Configure:
   - Source endpoint
   - Target endpoint
   - Replication resources
   - Network connectivity
   - Security groups
   - IAM permissions
4. **Full Load** — Transfer existing data from the source database to Amazon Aurora.
5. **Change Data Capture (CDC)** — Capture database changes occurring during the migration.
6. **Validation** — Validate the migrated database before production cutover.
7. **Cutover** — Redirect applications to the AWS-hosted database after successful testing.

---

## 🔐 Security Architecture

Security is incorporated throughout the migration. Key controls include:

- AWS Identity and Access Management (IAM)
- Principle of least privilege
- Multi-Factor Authentication (MFA)
- Security Groups
- Private networking
- Encryption in transit
- Encryption at rest
- Database access controls
- Logging and monitoring
- IAM roles
- AWS security best practices

---

## ⚙️ Infrastructure as Code

AWS CloudFormation is used to automate infrastructure deployment. Four stacks (network, security, Aurora, DMS) live in [`infrastructure-as-code/cloudformation/`](infrastructure-as-code/cloudformation/) and are linted on every pull request. Infrastructure as Code helps provide:

- Repeatable deployments
- Standardized configurations
- Version-controlled infrastructure
- Reduced configuration errors
- Faster disaster recovery
- Easier environment recreation

---

## 📊 Monitoring and Management

Monitoring is deployed by the [`06-monitoring`](infrastructure-as-code/cloudformation/06-monitoring.yaml) and [`07-operations`](infrastructure-as-code/cloudformation/07-operations.yaml) stacks. See [`monitoring/`](monitoring/) for every alarm, event rule, and Systems Manager association.

### Amazon CloudWatch

CloudWatch provides:

- Infrastructure monitoring
- Metrics
- Logs
- Alarms
- Performance monitoring

### AWS Systems Manager

Systems Manager provides centralized infrastructure management and automation. Example capabilities include:

- Automation
- Patch management
- Remote management
- Inventory
- Operational visibility

### AWS Trusted Advisor

Trusted Advisor is evaluated for recommendations related to:

- Cost optimization
- Performance
- Security
- Fault tolerance
- Service limits

---

## 🔄 Cutover Strategy

Before production cutover, the migrated environment is validated through:

1. Database validation
2. Application testing
3. Network testing
4. Security validation
5. Performance testing
6. User acceptance testing
7. Final data synchronization

After successful validation, production traffic can be redirected to the AWS environment.

---

## ↩️ Rollback Strategy

A rollback plan is maintained in case critical problems occur during migration. Rollback considerations include:

- Maintaining the original environment during cutover
- Database backups
- Migration checkpoints
- DNS rollback
- Application rollback
- Database synchronization
- Recovery procedures

> The legacy environment should remain available until the AWS environment has been fully validated.

---

## 📈 Postmigration Activities

After migration, the AWS environment is evaluated for:

| Area | Focus |
|------|-------|
| **Performance** | Monitor CPU, memory, database performance, network activity, and application response times. |
| **Security** | Review IAM permissions, Security Groups, encryption, logging, and security recommendations. |
| **Cost** | Identify underutilized resources and opportunities for cost optimization. |
| **Reliability** | Evaluate backup, disaster recovery, high availability, and fault tolerance. |
| **Automation** | Use CloudFormation and Systems Manager to reduce manual administration. |

---

## 💡 Cloud Migration Recommendations

The final architecture emphasizes:

- Least-privilege IAM
- MFA
- Encryption at rest and in transit
- Automated infrastructure deployment
- Centralized monitoring
- Database backups
- Disaster recovery
- Continuous optimization
- Regular security assessments
- Infrastructure as Code

---

## 📁 Repository Structure

```text
BallotOnline-AWS-Cloud-Migration/
│
├── README.md
│
├── architecture/
│   ├── diagrams/
│   └── migration-architecture.md
│
├── database-migration/
│   ├── aws-dms/
│   ├── mysql/
│   └── aurora/
│
├── server-migration/
│   └── hyper-v-to-aws/
│
├── infrastructure-as-code/
│   └── cloudformation/
│
├── security/
│   ├── security-controls.md
│   ├── security-checklist.md
│   └── iam-policies/
│
├── monitoring/
│   ├── cloudwatch/
│   ├── systems-manager/
│   └── trusted-advisor/
│
├── cutover-rollback/
│   └── strategy.md
│
├── screenshots/
│
└── docs/
    ├── migration-plan/
    └── postmigration-report/
```

---

## 🧰 Skills Demonstrated

This project demonstrates practical knowledge of:

`AWS` `Cloud Architecture` `Cloud Migration` `AWS DMS` `Amazon Aurora` `MySQL` `Amazon EC2` `AWS Application Migration Service` `AWS CloudFormation` `Amazon CloudWatch` `AWS Systems Manager` `AWS Trusted Advisor` `IAM` `Cloud Security` `Infrastructure as Code` `Database Migration` `Disaster Recovery` `Cutover & Rollback Planning`

---

## 🎓 Academic Context

| | |
|---|---|
| **Program** | Master of Science – Cloud Computing Systems |
| **University** | University of Maryland Global Campus (UMGC) |
| **Project** | BallotOnline Cloud Migration |
| **Author** | Thierry A. Oteyami |

This repository documents an academic cloud migration project and is intended to demonstrate cloud engineering, architecture, migration, security, and automation skills.

> **Note:** Credentials, AWS account IDs, IP addresses, private endpoints, and other sensitive details have been removed or replaced with placeholders.

---

## 👨‍💻 Author

**Thierry A. Oteyami**
Cloud Engineer | Oracle DBA | Software Developer

Areas of expertise:

- AWS
- Oracle Cloud Infrastructure
- Oracle Database
- Terraform
- Kubernetes
- Docker
- Cloud Migration
- Database Migration
- Infrastructure Automation

---

## ⭐ Project Purpose

This repository serves both as documentation of the BallotOnline cloud migration project and as a portfolio demonstration of practical AWS Cloud Engineering and Cloud Migration skills.
