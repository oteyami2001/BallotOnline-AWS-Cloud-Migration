# ✅ Migration Security Checklist

Work through each phase in order. An item is complete only when someone has checked it and recorded the evidence (a screenshot, a command's output, or a console view), with sensitive values redacted.

---

## Phase 1 — Before Migration

### Account and Identity

- [ ] Root account has MFA and no access keys
- [ ] Every human user has MFA ([`require-mfa.json`](iam-policies/require-mfa.json) attached to all user groups)
- [ ] Migration staff use the [`migration-operator`](iam-policies/migration-operator.json) policy, not administrator access
- [ ] IAM password policy enforced (length ≥ 14, reuse prevention)
- [ ] Governance stack deployed: CloudTrail logging, GuardDuty enabled, Access Analyzer active

### Network

- [ ] VPC deployed from `01-network.yaml`; no workload subnet has a route to the internet gateway
- [ ] Site-to-Site VPN tunnels `UP`; traffic between on-premises and AWS stays on the VPN
- [ ] Security groups match the design (no `0.0.0.0/0` inbound rules anywhere)
- [ ] VPC Flow Logs arriving in CloudWatch Logs

### Data

- [ ] Customer-managed KMS key created with rotation enabled
- [ ] Aurora created with `StorageEncrypted: true` and `require_secure_transport = ON`
- [ ] Source DMS password stored in Secrets Manager, not in files or shell history
- [ ] `dms_migration` user restricted to the DMS subnet, TLS required, `SELECT` only on the HR schema

---

## Phase 2 — During Migration

### Database (AWS DMS)

- [ ] Both DMS endpoints test **successful** with `SslMode: require`
- [ ] DMS replication instance is **not** publicly accessible
- [ ] Task logs in CloudWatch reviewed; no credentials or data samples appear in the logs
- [ ] DMS data validation enabled; `awsdms_validation_failures_v1` reviewed

### Servers (AWS MGN)

- [ ] Agent-installation credentials are short-lived and scoped to `AWSApplicationMigrationAgentInstallationPolicy`
- [ ] Replication servers have no public IPs; data routed over the VPN
- [ ] Staging and launched EBS volumes are encrypted
- [ ] Test instances launched with no public IP and the SSM instance profile

### Operations

- [ ] GuardDuty findings reviewed daily during the migration window
- [ ] Changes recorded (who, what, when) and visible in CloudTrail

---

## Phase 3 — Cutover

- [ ] Validation checklists signed off ([database](../database-migration/aurora/validation-queries.sql), [servers](../server-migration/hyper-v-to-aws/cutover-validation-checklist.md))
- [ ] Applications connect to Aurora over TLS with a least-privilege application user (not `hradmin`)
- [ ] FTP users moved to SFTP; plain FTP disabled
- [ ] DNS changes made with low TTLs; rollback path tested
- [ ] On-premises source kept intact and isolated until the rollback window closes

---

## Phase 4 — After Migration

### Clean Up

- [ ] Agent-installation IAM credentials deleted
- [ ] `dms_migration` user dropped from the source after the final sync
- [ ] DMS replication instance and endpoints deleted once no longer needed
- [ ] MGN source servers archived; staging resources removed
- [ ] Test instances terminated

### Harden

- [ ] Migrated EC2 instances patched with Systems Manager Patch Manager
- [ ] No SSH (22) or RDP (3389) open for administration; Session Manager used instead
- [ ] Security Hub (if enabled) critical and high findings resolved
- [ ] Trusted Advisor security checks reviewed
- [ ] IAM Access Analyzer shows no unexpected external access

### Ongoing

- [ ] CloudWatch alarms on root sign-in, IAM policy changes, security group changes, and CloudTrail changes ([monitoring](../monitoring/))
- [ ] Quarterly access review of IAM users and database accounts
- [ ] Backups restored in a test at least once
- [ ] On-premises servers and data securely decommissioned and disposed of

---

## Sign-off

| Phase | Reviewed By | Date | Notes |
|---|---|---|---|
| Before migration | | | |
| During migration | | | |
| Cutover | | | |
| After migration | | | |
