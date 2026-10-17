# 🛟 Disaster Recovery

How BallotOnline's AWS environment would be recovered from failures ranging from a single instance to a full Region outage.

> **Scope:** recommended DR design built on the CloudFormation stacks in this repository. No DR test or restore has been performed against a real AWS account. The course project identified disaster recovery as a migration benefit and planning area.

---

## RTO and RPO Are Business Decisions

- **RTO (Recovery Time Objective):** how long a service can be down.
- **RPO (Recovery Point Objective):** how much recent data can be lost.

The business sets these targets based on the impact of downtime and data loss, and the architecture is chosen and funded to meet them. AWS does not guarantee them.

### Proposed Targets (require business approval)

These are **starting proposals** for discussion with BallotOnline's HR and IT owners. They are not commitments, and they must be confirmed by restore tests.

| Workload | Proposed RTO | Proposed RPO | Basis |
|---|---|---|---|
| HR database (Aurora) | 4 hours | 15 minutes | Aurora point-in-time recovery within the backup retention period |
| Intranet server | 8 hours | 24 hours | Rebuild from an AMI or EBS snapshot (daily) |
| FTP / SFTP server | 8 hours | 24 hours | Daily snapshot; uploaded files since the last snapshot may be lost |
| NTP server | 24 hours | Not applicable (stateless) | Clients can fall back to Amazon Time Sync or other approved sources |
| Whole environment (Region loss) | 24–48 hours | 24 hours | Rebuild from CloudFormation plus cross-Region backup copies (recommended enhancement) |

---

## DR Strategy

**Backup and restore**, plus **Multi-AZ high availability** inside the primary Region:

| Layer | In-Region protection (in the templates) | Recovery from backups | Recommended enhancement |
|---|---|---|---|
| Aurora | Writer + reader in two AZs, automatic failover | Automated backups (7-day PITR), manual snapshots | Copy snapshots to a second Region (or use AWS Backup copy rules) |
| EC2 servers | Auto-recover alarm on system check failure | Rebuild from AMI/EBS snapshots | AWS Backup plan with daily snapshots and a cross-Region copy |
| Infrastructure | Defined in CloudFormation | Redeploy with [`deploy.sh`](../infrastructure-as-code/cloudformation/deploy.sh) | Pre-validated deploy to the DR Region |
| Secrets and config | Secrets Manager, Parameter Store | Re-created by stacks; Aurora generates a new secret on restore | Replicate critical secrets to the DR Region |
| Audit logs | CloudTrail bucket versioned and retained (365 days) | Bucket outlives stacks (`DeletionPolicy: Retain`) | S3 cross-Region replication for log archives |

---

## Aurora Recovery

### Automated backups and point-in-time recovery (PITR)

Aurora backs up continuously. Within the retention period (7 days in [`03-aurora.yaml`](../infrastructure-as-code/cloudformation/03-aurora.yaml)), the cluster can be restored to any second, usually up to about five minutes before the present. A restore creates a **new cluster**, and instances must then be added to it:

```bash
# 1. Restore the cluster to a point in time (for example, just before a bad change)
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier <cluster-id> \
  --db-cluster-identifier ballotonline-hr-restored \
  --restore-to-time 2026-01-15T09:30:00Z \
  --db-subnet-group-name <db-subnet-group> \
  --vpc-security-group-ids <aurora-sg-id> \
  --kms-key-id <data-key-arn>

# 2. Add a writer instance to the restored cluster
aws rds create-db-instance \
  --db-instance-identifier ballotonline-hr-restored-writer \
  --db-cluster-identifier ballotonline-hr-restored \
  --engine aurora-mysql \
  --db-instance-class db.t4g.medium
```

Then validate with [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) and repoint the application to the restored cluster endpoint.

### Manual snapshots

Manual snapshots are kept until deleted, beyond the automated retention period. Take one before every planned change and right after cutover:

```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier <cluster-id> \
  --db-cluster-snapshot-identifier post-cutover-2026-01-15
```

Restore one with `aws rds restore-db-cluster-from-snapshot --snapshot-identifier ... --engine aurora-mysql`, then add an instance as above. Deleting the Aurora stack also leaves a final snapshot (`DeletionPolicy: Snapshot`).

---

## EC2 Recovery

| Failure | Recovery | In repository? |
|---|---|---|
| Underlying host failure | CloudWatch `StatusCheckFailed_System` alarm runs **EC2 auto-recover** (same instance ID, IP, and volumes) | Yes, `06-monitoring.yaml` |
| Guest OS failure | Diagnose with the [health-check runbook](../monitoring/systems-manager/automation-runbook.yaml) and Session Manager or the EC2 serial console, then reboot | Runbook yes; reboot is manual |
| Instance or volume lost / corrupted | Launch from the latest AMI or EBS snapshot into the same subnet and security group, with the SSM instance profile, then update DNS | Snapshots: **recommended** (AWS Backup plan not in templates) |
| AZ failure | Launch from snapshot into AZ B's app subnet (`10.0.12.0/24`), which exists for this purpose | Subnet yes; procedure manual |

AWS MGN is a migration tool, not a DR tool. After the cutover is finalized, it no longer replicates from the source. **AWS Elastic Disaster Recovery** is the related service for continuous DR replication, if the business needs a tighter RPO/RTO for these servers.

---

## Infrastructure Reconstruction

All networking, security, database, monitoring, and operations resources are code:

```bash
cd infrastructure-as-code/cloudformation
export AWS_REGION=<dr-region>
./deploy.sh deploy all          # network → security → governance → aurora → monitoring → operations
```

Considerations when rebuilding in another Region:

- **KMS keys are regional.** Snapshots copied across Regions must be re-encrypted with a key in the DR Region.
- **Restore instead of create:** for a real recovery, restore Aurora from a copied snapshot rather than creating an empty cluster from `03-aurora.yaml`.
- **The VPN** needs a new customer gateway configuration on the office device.
- **Names and quotas:** check service quotas in the DR Region in advance.

## Secrets and Configuration Recovery

| Item | Where it lives | Recovery |
|---|---|---|
| Aurora master password | Secrets Manager (managed by RDS) | A restored cluster can be given a newly managed secret; rotate application credentials afterwards |
| Application DB user password | Secrets Manager (recommended) | Recreate the user on the restored cluster from documented grants |
| CloudWatch agent config | Parameter Store (`07-operations.yaml`) | Redeployed by the stack |
| Infrastructure definitions | This Git repository | Clone and deploy |
| Runbooks and contacts | This repository + offline copy | Keep a printed or offline copy for when AWS console access is unavailable |

## Log Retention

| Log | Retention | Note |
|---|---|---|
| CloudTrail (S3) | 365 days, Glacier IR after 90 | Bucket retained when the stack is deleted |
| CloudTrail (CloudWatch Logs) | 365 days | For alarms and searches |
| VPC Flow Logs | 90 days | |
| EC2 OS logs | 90 days | From the CloudWatch agent |

---

## Backup Validation and Restore Testing

A backup only counts once a restore from it has been tested. Proposed schedule (see the [operating model](../monitoring/postmigration-operations.md#quarterly)):

| Test | Frequency | Pass criteria |
|---|---|---|
| Aurora PITR to a temporary cluster | Quarterly | Validation queries match the production snapshot time; elapsed time recorded vs. proposed RTO |
| Aurora snapshot restore | Quarterly (alternate with PITR) | Same as above |
| EC2 rebuild from snapshot | Twice a year | Service passes [post-cutover validation](post-cutover-validation.md) checks |
| CloudFormation rebuild in a sandbox account | Yearly or after major template changes | All stacks deploy cleanly |
| Tabletop exercise (AZ loss, security incident) | Yearly | Runbooks updated with gaps found |

Delete temporary restored resources after each test to control cost.

## Related

- [Business continuity](business-continuity.md) · [Rollback plan](rollback-plan.md) · [CloudFormation stacks](../infrastructure-as-code/cloudformation/)
