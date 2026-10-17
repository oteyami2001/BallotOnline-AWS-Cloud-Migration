# AWS Trusted Advisor

Trusted Advisor checks the account against AWS best practices. It is used after migration to confirm the environment is secure, resilient, and not wasting money.

## Pillars

| Pillar | Example checks relevant to BallotOnline |
|---|---|
| **Security** | Security groups with unrestricted access, MFA on root, IAM use, exposed access keys, S3 bucket permissions |
| **Fault tolerance** | Aurora Multi-AZ, RDS backups, EBS snapshots, VPN tunnel redundancy |
| **Cost optimization** | Idle RDS instances, low-utilization EC2, unassociated Elastic IPs, Savings Plans opportunities |
| **Performance** | High-utilization EC2, overutilized EBS volumes |
| **Service limits** | VPC, EC2, and RDS quotas close to their limits |
| **Operational excellence** | CloudTrail and logging configuration, resource tagging |

## Report Script

[`ta-report.sh`](ta-report.sh) lists every recommendation in `error` or `warning` state using the Trusted Advisor API:

```bash
./ta-report.sh            # all pillars
./ta-report.sh security   # one pillar
```

> The Trusted Advisor API requires a **Business, Enterprise On-Ramp, or Enterprise** Support plan. With Basic Support, the core security and service-limit checks are available in the Trusted Advisor console.

## Review Cadence

| When | Action |
|---|---|
| Right after cutover | Review all pillars; fix every security **error** before closing the migration |
| Monthly | Run the report; record findings and owners |
| Quarterly | Act on cost recommendations (right-sizing, Savings Plans), alongside AWS Compute Optimizer |

Trusted Advisor complements, but does not replace, **Security Hub** (continuous control checks), **GuardDuty** (threat detection), and **Access Analyzer** (external access), which are deployed by the [governance stack](../../infrastructure-as-code/cloudformation/05-governance.yaml).
