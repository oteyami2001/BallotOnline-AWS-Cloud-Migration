# ✅ Server Cutover Validation Checklist

Use this checklist for every **test launch** and again after the **cutover launch**. Record results (pass/fail, who, when) in the migration log. Replace `<instance-ip>` and hostnames with your values. Never commit real addresses.

---

## 1. All Servers

| # | Check | Command / Method | Expected |
|---|---|---|---|
| 1.1 | EC2 status checks | EC2 console or `aws ec2 describe-instance-status --instance-ids <id>` | 2/2 checks passed |
| 1.2 | Managed by Systems Manager | `aws ssm describe-instance-information` | Instance listed, `Online` |
| 1.3 | Remote access without SSH/RDP | Session Manager → Start session | Shell opens |
| 1.4 | No public IP | EC2 console → Networking | Public IPv4: none |
| 1.5 | Volumes encrypted | EC2 console → Storage | Encrypted: yes (KMS) |
| 1.6 | Hostname and disks match source | `hostname`; `df -h` / `Get-Volume` | Same as source |
| 1.7 | Time source | Linux: `chronyc sources` · Windows: `w32tm /query /status` | Amazon Time Sync or BallotOnline NTP, offset < 100 ms |
| 1.8 | CloudWatch agent / alarms | CloudWatch console | Metrics arriving, alarms `OK` |
| 1.9 | Old IPs/hostnames not hard-coded | Search configs for on-premises addresses | None found |

## 2. Intranet Server

| # | Check | Command / Method | Expected |
|---|---|---|---|
| 2.1 | Web service running | `systemctl status <web-service>` / `Get-Service W3SVC` | Running |
| 2.2 | HTTPS reachable over VPN | `curl -I https://<instance-ip>` from an office workstation | `HTTP 200` (or redirect to login) |
| 2.3 | TLS certificate valid | Browser / `openssl s_client -connect <instance-ip>:443` | Valid, not expired, correct name |
| 2.4 | Login works | Sign in with a test account | Success |
| 2.5 | Database connectivity (if used) | Load a page that reads HR data | Data shown from Aurora |
| 2.6 | Response time | Compare with on-premises baseline | Within agreed tolerance |

## 3. FTP / SFTP Server

| # | Check | Command / Method | Expected |
|---|---|---|---|
| 3.1 | Service running | `systemctl status sshd` (SFTP) or FTP service | Running |
| 3.2 | Login over VPN | `sftp <test-user>@<instance-ip>` | Session opens |
| 3.3 | Upload | `put test-file.txt` | File stored |
| 3.4 | Download | `get test-file.txt` | Checksum matches (`sha256sum`) |
| 3.5 | Directory permissions | List user home folders | Users confined to their folders |
| 3.6 | Existing data present | Compare file counts/sizes with source | Match |
| 3.7 | Port exposure | Security group review | Only 22 (and 21 + passive range if FTP kept) from VPN CIDR |

## 4. NTP Server

| # | Check | Command / Method | Expected |
|---|---|---|---|
| 4.1 | Service running | `systemctl status chronyd` | Running |
| 4.2 | Server synced upstream | `chronyc tracking` | `Leap status: Normal`, small offset |
| 4.3 | Clients can query | From a client: `chronyc sources` / `w32tm /stripchart /computer:<instance-ip> /samples:3` | Responses with low offset |
| 4.4 | UDP 123 allowed | Security group review | UDP 123 from VPC and on-premises CIDRs only |

> **Recommendation:** EC2 instances can use Amazon Time Sync Service (`169.254.169.123`) directly. Once on-premises clients no longer need this server, it can be retired.

## 5. Cutover Only

| # | Check | Expected |
|---|---|---|
| 5.1 | Source services stopped before cutover launch | No writes on source after final sync |
| 5.2 | DNS updated | Records resolve to new EC2 private IPs |
| 5.3 | Users confirm access | Intranet, SFTP, and time sync working for staff |
| 5.4 | Monitoring for 24–48 hours | No critical alarms |
| 5.5 | Rollback still possible | Source VMs intact and powered off |
| 5.6 | Cutover finalized | `mgn-lifecycle.sh finalize` run after sign-off |

---

## Sign-off

| Server | Test Launch | Cutover | Validated By | Date |
|---|---|---|---|---|
| Intranet | ☐ | ☐ | | |
| FTP | ☐ | ☐ | | |
| NTP | ☐ | ☐ | | |
