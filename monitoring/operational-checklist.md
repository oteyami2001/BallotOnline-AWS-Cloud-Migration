# ✅ Operational Checklist

Checkbox version of the [postmigration operations model](postmigration-operations.md). Copy a section into the operations log each time it is completed, and add the date, the name of whoever did it, and the evidence (screenshot or command output, with sensitive values redacted).

## Daily

- [ ] No CloudWatch alarm in `ALARM` state (dashboard `ballotonline-operations`)
- [ ] Intranet loads over HTTPS from the office
- [ ] SFTP login and a test upload/download work
- [ ] NTP responds; instance time offset is small
- [ ] No new GuardDuty finding with severity ≥ 7
- [ ] No `security-*` alarm fired (root use, no-MFA login, IAM / security group / CloudTrail / KMS changes)
- [ ] *(While migrating)* DMS task running, CDC latency normal; MGN replication `CONTINUOUS`
- [ ] Aurora latest restorable time is current

## Weekly

- [ ] Patch Manager: all `Project=BallotOnline` instances compliant
- [ ] State Manager associations succeeded (agent install/configure, patch scan, inventory)
- [ ] No unexplained failed Automation executions
- [ ] 7-day trends reviewed: CPU, memory, disk, connections, latency
- [ ] Aurora backups within retention; manual snapshot before any planned change
- [ ] All expected log groups still receiving data

## Monthly

- [ ] Trusted Advisor findings reviewed and assigned
- [ ] Cost Explorer reviewed; idle resources removed (old DMS instances, test EC2, unattached EBS, unused Elastic IPs)
- [ ] IAM credential report reviewed; unused users/keys removed; MFA confirmed
- [ ] IAM Access Analyzer: no unexpected external access
- [ ] Patch and Security Hub (if enabled) exceptions documented
- [ ] Capacity trends reviewed (Aurora `VolumeBytesUsed`, EC2 utilization)

## Quarterly

- [ ] Aurora point-in-time restore tested; validation queries pass
- [ ] One CloudFormation stack rebuilt in a test account or Region
- [ ] Measured recovery time compared with the proposed RTO/RPO
- [ ] Security controls and risk register reviewed
- [ ] Rightsizing recommendations acted on or declined with a reason
- [ ] Runbooks and this repository updated to match the environment

## Sign-off

| Period | Completed By | Date | Exceptions |
|---|---|---|---|
| | | | |
