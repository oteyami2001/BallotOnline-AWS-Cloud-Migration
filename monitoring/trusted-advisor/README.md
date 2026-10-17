# AWS Trusted Advisor

Trusted Advisor inspects the AWS account and recommends improvements based on AWS best practices. For BallotOnline it is the **periodic, account-wide review** that follows migration. It is not a real-time monitoring tool.

---

## Availability by Support Plan

What Trusted Advisor shows depends on the account's AWS Support plan:

| Support plan | What is available |
|---|---|
| **Basic and Developer** | A limited set of core checks: selected **security** checks (for example S3 bucket permissions, security groups with unrestricted ports, IAM use, MFA on the root account, EBS/RDS public snapshots) and the **service quotas** checks. |
| **Business, Enterprise On-Ramp, Enterprise** | The full set of checks across all categories, plus programmatic access through the Trusted Advisor API (used by [`ta-report.sh`](ta-report.sh)) and integrations such as EventBridge and Security Hub. |

The exact list of checks changes over time. Confirm against the Trusted Advisor console for the account rather than assuming any specific check is available.

---

## Category Evaluation for BallotOnline

| Category | What it looks for | Relevance after migration | Example finding and response |
|---|---|---|---|
| **Cost optimization** | Idle or underused resources, purchase options | **High.** The DMS instance, MGN staging resources, and test instances are easy to forget after cutover. | *Low-utilization EC2* → right-size the rehosted servers; *idle RDS* → confirm the DMS stack is deleted |
| **Performance** | Over-used instances and volumes, configuration limits | **Medium.** Rehosted servers keep their on-premises sizing. | *High-utilization EC2* → compare with CloudWatch trends and resize |
| **Security** | Open ports, IAM hygiene, MFA, public snapshots or buckets, logging | **High.** HR data (PII) is now in AWS. | *Security group with unrestricted access* → should never appear given [`02-security.yaml`](../../infrastructure-as-code/cloudformation/02-security.yaml); investigate any drift |
| **Fault tolerance** | Backups, Multi-AZ, redundancy | **High.** Validates the DR design. | *RDS backups / Multi-AZ* → confirms the Aurora reader and backup retention; *VPN tunnel redundancy* → check both tunnels are configured on the office device |
| **Service limits (quotas)** | Usage approaching account quotas | **Medium.** Most relevant while building and migrating. | *VPC or EC2 quota near limit* → request an increase before the next change |
| **Operational excellence** | Logging and configuration practices | Medium | Confirms CloudTrail and related settings from [`05-governance.yaml`](../../infrastructure-as-code/cloudformation/05-governance.yaml) |

---

## How Trusted Advisor Complements Other Services

| Service | Timing | Scope | Relationship to Trusted Advisor |
|---|---|---|---|
| **CloudWatch** | Real time (minutes) | Specific metrics and logs | Detects incidents now. Trusted Advisor finds slow-burning configuration issues that never trip an alarm. |
| **Systems Manager** | On demand / scheduled | Inside the EC2 instances | Fixes and patches servers. Trusted Advisor points to which resources need attention. |
| **Security Hub** | Continuous | Security controls against standards | Deeper, continuous security posture; can include Trusted Advisor results |
| **GuardDuty** | Continuous | Threat detection from logs | Detects active threats; Trusted Advisor checks configuration |
| **Compute Optimizer** | Daily analysis | EC2, EBS, and more | More detailed right-sizing than the Trusted Advisor cost checks |

None of these replaces the others. Trusted Advisor is the monthly "is the account set up well?" review in the [operating model](../postmigration-operations.md).

---

## Report Script

[`ta-report.sh`](ta-report.sh) lists every recommendation in `error` or `warning` state using the Trusted Advisor API:

```bash
./ta-report.sh            # all pillars
./ta-report.sh security   # one pillar
```

It needs one of the higher Support plans. With Basic or Developer support, review the core checks in the console instead.

## Review Cadence

| When | Action |
|---|---|
| Right after cutover | Review every category. Fix every security **error** before closing the migration. |
| Monthly | Run the report or review the console; record findings, owners, and due dates. |
| Quarterly | Act on cost recommendations together with Compute Optimizer. |

---

## Project Scope

- **UMGC course project:** Trusted Advisor was evaluated as part of BallotOnline's postmigration review.
- **This repository:** documents the evaluation and provides the report script. The script was validated against the AWS CLI's parameter checks, not run against a real account.
- **Recommended practice:** the review cadence above.
