# 🏢 Business Continuity

How BallotOnline keeps critical HR and internal services running, or degrades them gracefully, when parts of the AWS environment or its connections fail.

> **Scope:** recommended continuity planning based on the target architecture. Not tested against a live environment.

---

## Critical Services and Dependencies

| Service | Business use | Depends on |
|---|---|---|
| HR database (Aurora) | Employee records used by HR processes | Aurora cluster, Intranet app, Secrets Manager, KMS |
| Intranet | Staff access to HR and internal information | EC2 (app subnet), Aurora, DNS, VPN (office access) |
| SFTP | File exchange with staff and partners | EC2, EBS, DNS, VPN |
| NTP | Consistent time for logs, authentication, and file timestamps | EC2 or Amazon Time Sync |

Shared dependencies: **Site-to-Site VPN**, **DNS**, **IAM/MFA** (for administrators), **NAT gateway** (patching only), **monitoring and alerting**, and the **operations team**.

---

## Scenarios

| Scenario | Impact | Continuity measure | Expected behavior | Escalate to |
|---|---|---|---|---|
| **AWS resource failure** (single EC2 instance or volume) | One service down | EC2 auto-recover; rebuild from snapshot ([DR](disaster-recovery.md#ec2-recovery)) | Minutes (auto-recover) to hours (rebuild) | Cloud engineer → service owner if > 1 hour |
| **Availability Zone failure** | Services in AZ A unavailable | Aurora fails over to the reader in AZ B automatically; launch EC2 replacements in AZ B's app subnet; second NAT gateway if `SingleNatGateway=false` | Database back within minutes; servers within hours unless pre-built in AZ B | Cutover lead / operations manager |
| **Database failure or corruption** | HR data unavailable or wrong | Multi-AZ failover for hardware; **point-in-time restore** for corruption or bad changes | Failover: minutes. PITR: hours (see proposed RTO) | DBA → service owner immediately |
| **Network / VPN interruption** | Office users can't reach AWS; services keep running | Two VPN tunnels; restore the office device; temporary access for administrators through Session Manager over the internet | Users affected until the VPN is restored | Network engineer → ISP / AWS Support |
| **Security incident** | Possible data exposure or loss of trust in the environment | [Incident response](../security/security-controls.md#6-logging-detection-and-response): isolate, revoke credentials, snapshot for evidence, rebuild from code | Service may be deliberately taken offline | Security lead → management, legal / HR for PII |
| **Failed deployment or change** | Service degraded after a change | Manual snapshot before every change; CloudFormation rollback on failed updates; revert to the previous template version in Git | Roll back the change; PITR if data was affected | Change owner → cutover lead |

---

## Degraded-Mode Operation

| If this is down | Keep operating by |
|---|---|
| Aurora writer (during failover) | Short read-only period; applications reconnect to the cluster endpoint |
| Intranet | Communicate through email; HR uses the latest exported reports for urgent lookups |
| SFTP | Exchange urgent files through an approved alternative, then upload them once the service is restored |
| NTP server | Clients use Amazon Time Sync (EC2) or an approved backup time source |
| VPN | Administrators use Session Manager; users wait or use an approved remote-access fallback |

## Escalation and Communication

| Level | Trigger | Who is informed | When |
|---|---|---|---|
| 1 | Single alarm, no user impact | On-call cloud engineer | Immediately (SNS) |
| 2 | User-visible degradation of one service | + Service owner, service desk | Within 30 minutes |
| 3 | Outage of HR data or multiple services, or any security incident | + Operations manager, security lead, management | Immediately |
| 4 | Suspected PII exposure | + Legal / compliance, HR leadership | Per incident and notification policy |

Status updates go out at least hourly during a level 3–4 event, and continue until resolution and the post-incident review.

## Keeping the Plan Current

- Review this plan quarterly with the [operating model](../monitoring/postmigration-operations.md).
- Update the dependency list whenever the architecture changes.
- Run a tabletop exercise at least once a year ([DR testing](disaster-recovery.md#backup-validation-and-restore-testing)).
