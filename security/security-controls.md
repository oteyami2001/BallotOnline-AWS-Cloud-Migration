# 🔐 BallotOnline Security Controls

This document describes the security controls applied to the BallotOnline AWS migration, how each one is implemented, and where it lives in this repository.

The migrated workloads include the **HR database**, which holds employee personal information (PII). Controls are therefore designed to protect confidentiality and integrity first, during the migration as well as after it.

---

## 1. Shared Responsibility

| AWS is responsible for | BallotOnline is responsible for |
|---|---|
| Physical data centers, hardware, and the global network | IAM users, roles, MFA, and permissions |
| Hypervisor and managed-service infrastructure | Security group and network design |
| Aurora storage, patching of the managed database engine (when scheduled) | Database users, grants, and TLS enforcement |
| Availability of DMS, MGN, CloudTrail, GuardDuty | Encryption choices and KMS key policies |
| | Guest OS patching and hardening of migrated EC2 servers |
| | Logging, monitoring, and incident response |
| | Protecting credentials and sensitive data in this repository |

---

## 2. Defense in Depth

```text
┌───────────────────────────────────────────────────────────────┐
│ Governance & Detection   CloudTrail · GuardDuty · Access      │
│                          Analyzer · Security Hub (optional)   │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ Identity             IAM least privilege · MFA · roles,   │ │
│ │                      no long-term keys on servers         │ │
│ │ ┌───────────────────────────────────────────────────────┐ │ │
│ │ │ Network          Private subnets · VPN · security     │ │ │
│ │ │                  groups per workload · Flow Logs      │ │ │
│ │ │ ┌───────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Compute      SSM Session Manager · patching ·     │ │ │ │
│ │ │ │              no public IPs                        │ │ │ │
│ │ │ │ ┌───────────────────────────────────────────────┐ │ │ │ │
│ │ │ │ │ Data     KMS encryption at rest · TLS in      │ │ │ │ │
│ │ │ │ │          transit · Secrets Manager · backups  │ │ │ │ │
│ │ │ │ └───────────────────────────────────────────────┘ │ │ │ │
│ │ │ └───────────────────────────────────────────────────┘ │ │ │
│ │ └───────────────────────────────────────────────────────┘ │ │
│ └───────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

---

## 3. Identity and Access Management

| Control | Implementation | Where |
|---|---|---|
| MFA for every human user | Deny-unless-MFA policy; console users must enroll MFA before doing anything else | [`iam-policies/require-mfa.json`](iam-policies/require-mfa.json) |
| Least privilege for migration staff | Operator policy: read migration state, run DMS/MGN steps on `Project=BallotOnline` resources only, MFA required; destructive actions explicitly denied | [`iam-policies/migration-operator.json`](iam-policies/migration-operator.json) |
| Root account protection | MFA on root, no root access keys, root used only for account-level tasks | Account setup ([checklist](security-checklist.md)) |
| No long-term keys on servers | EC2 uses an instance profile (`AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`) | `02-security.yaml` → `Ec2ManagedRole` |
| Short-lived migration credentials | MGN agent installed with `AWSApplicationMigrationAgentInstallationPolicy` credentials that are deleted afterwards | [Server migration](../server-migration/hyper-v-to-aws/) |
| Service roles, not users | DMS uses `dms-vpc-role` and `dms-cloudwatch-logs-role`; CloudTrail and Flow Logs use dedicated roles | `02-security.yaml`, `01-network.yaml`, `05-governance.yaml` |
| Unintended access detection | IAM Access Analyzer reports resources shared outside the account | `05-governance.yaml` |

### Database Accounts

| Account | Where | Privileges |
|---|---|---|
| `dms_migration` | Source MySQL | `SELECT` on HR schema, `REPLICATION CLIENT`, `REPLICATION SLAVE`; only from the DMS subnet; TLS required |
| `hradmin` (master) | Aurora | Administrative; password generated and stored by Secrets Manager; not used by applications |
| Application user | Aurora | Only the privileges the intranet application needs, `REQUIRE SSL` |

---

## 4. Network Security

| Control | Implementation | Where |
|---|---|---|
| Private by default | Workloads, Aurora, and DMS run in private subnets with no public IPs | `01-network.yaml` |
| Encrypted hybrid connectivity | Site-to-Site VPN (IPsec) for migration and staff traffic | `01-network.yaml` (`CreateVpn`) |
| One security group per workload | Only required ports: 443 (intranet), 22 (SFTP), UDP 123 (NTP), 1500 (MGN staging) | `02-security.yaml` |
| Database isolation | Aurora accepts 3306 only from the intranet and DMS security groups (group references, not IP ranges) | `02-security.yaml` → `AuroraSecurityGroup` |
| DMS outbound only | No inbound rules; outbound limited to 3306, 443, and DNS | `02-security.yaml` → `DmsSecurityGroup` |
| Outbound internet only via NAT | Private subnets reach the internet only for patching, through NAT gateways | `01-network.yaml` |
| Network audit trail | VPC Flow Logs (all traffic) to CloudWatch Logs, 90-day retention | `01-network.yaml` |
| No SSH/RDP exposure | Administration through Systems Manager Session Manager | `02-security.yaml` instance profile |

---

## 5. Data Protection

| Control | Implementation | Where |
|---|---|---|
| Encryption at rest | Customer-managed KMS key (rotation on) for Aurora storage, Performance Insights, DMS storage, and EBS | `02-security.yaml` → `DataKey`; `03-aurora.yaml`; `04-dms.yaml` |
| Separate key for audit logs | Dedicated KMS key for CloudTrail and its CloudWatch log group | `05-governance.yaml` → `AuditKey` |
| Encryption in transit | `require_secure_transport = ON` on Aurora; DMS endpoints use `SslMode: require`; IPsec VPN; MGN replication encrypted | `03-aurora.yaml`, `04-dms.yaml` |
| Secrets management | Aurora password generated by Secrets Manager; DMS endpoints read credentials with dynamic references; no passwords in templates or scripts | `03-aurora.yaml`, `04-dms.yaml` |
| Backups | Aurora automated backups (7 days), snapshot on stack deletion, deletion protection | `03-aurora.yaml` |
| Data integrity during migration | DMS row-level validation, row counts, and content hashes before cutover | [`validation-queries.sql`](../database-migration/aurora/validation-queries.sql) |
| Secure file transfer | FTP users moved to SFTP so credentials are not sent in clear text | [Server migration](../server-migration/hyper-v-to-aws/) |

---

## 6. Logging, Detection, and Response

| Control | Implementation | Where |
|---|---|---|
| API audit trail | Multi-Region CloudTrail with log file validation, KMS-encrypted, TLS-only S3 bucket with versioning and public access blocked | `05-governance.yaml` |
| Searchable audit logs | CloudTrail delivered to CloudWatch Logs for metric filters and alarms | `05-governance.yaml` → `TrailLogGroup` |
| Threat detection | Amazon GuardDuty analyzes CloudTrail, VPC Flow Logs, and DNS logs | `05-governance.yaml` |
| Posture management | AWS Security Hub with default standards (optional) | `05-governance.yaml` (`EnableSecurityHub`) |
| Database logs | Aurora error and slow-query logs exported to CloudWatch | `03-aurora.yaml` |
| Migration logs | DMS task logs in CloudWatch | `04-dms.yaml` task settings |
| Alerting | CloudWatch alarms and SNS notifications | [`monitoring/`](../monitoring/) |

### Incident Response (summary)

1. **Detect:** a GuardDuty finding, CloudWatch alarm, or user report.
2. **Contain:** isolate the instance (swap its security group for one with no rules), disable the affected credentials, and stop the DMS task if data is at risk.
3. **Preserve evidence:** take EBS and Aurora snapshots; CloudTrail logs are already immutable through log file validation.
4. **Eradicate and recover:** rebuild from CloudFormation and restore from backups.
5. **Review:** record the root cause and update the controls and this document.

---

## 7. Migration-Specific Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| HR data exposed in transit during migration | Low | High | VPN, TLS on DMS endpoints, MGN encryption in transit |
| Over-privileged migration accounts | Medium | High | Dedicated `dms_migration` user, operator policy limited to project resources, short-lived MGN credentials |
| Credentials leaked in the repository or screenshots | Medium | High | Secrets Manager, `.gitignore`, screenshot redaction rules, no keys in scripts |
| Database reachable from the internet | Low | High | Private subnets, no public IPs, security group references |
| Data loss or corruption during cutover | Low | High | Validation queries, DMS validation, backups, rollback plan |
| Source environment decommissioned too early | Medium | Medium | Keep source until the rollback window closes; archive only after sign-off |
| Misconfiguration drift after migration | Medium | Medium | Infrastructure as Code, CI validation, Security Hub, Trusted Advisor |
| Unnoticed malicious activity | Low | High | CloudTrail, GuardDuty, alarms on root use and IAM changes |

---

## 8. Repository Hygiene

This is a public portfolio repository, so it must never contain:

- AWS account IDs, access keys, or secret keys
- Passwords, connection strings, or Secrets Manager values
- Real hostnames, public IPs, or private IP plans from the course environment
- Unredacted screenshots

Placeholders (`<REPLACE_WITH_STRONG_PASSWORD>`, `10.0.%`, `<SOURCE_ARN>`) are used throughout. The [`.gitignore`](../.gitignore) blocks common credential and key files.

---

## Related Documents

- [Security checklist](security-checklist.md)
- [IAM policies](iam-policies/)
- [CloudFormation stacks](../infrastructure-as-code/cloudformation/)
- [Target architecture](../architecture/migration-architecture.md)
