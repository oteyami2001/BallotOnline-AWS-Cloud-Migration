# 📸 Evidence

Sanitized screenshots that back up the work described in this repository, organized by category.

> **Only real project screenshots go here.** Nothing in this folder is mocked up or generated. A category with no images means no sanitized evidence has been added for it yet. Diagrams belong in [`architecture/diagrams/`](../architecture/diagrams/), not here.

## Categories

| Folder | Evidence | Status |
|---|---|---|
| [`architecture/`](architecture/) | VPC, subnets, routing, security groups, VPN | No screenshots yet |
| [`dms/`](dms/) | DMS instance, endpoints, connection tests, task settings, table statistics, troubleshooting errors | No screenshots yet |
| [`cloudformation/`](cloudformation/) | Stack lists, events, outputs (sandbox deployments only) | No screenshots yet |
| [`monitoring/`](monitoring/) | CloudWatch dashboard, alarms, SNS, EventBridge, log groups | No screenshots yet |
| [`security/`](security/) | IAM/MFA, KMS, CloudTrail, GuardDuty, Access Analyzer | No screenshots yet |
| [`systems-manager/`](systems-manager/) | Managed instances, Session Manager, Patch Manager, Inventory, Automation | No screenshots yet |
| [`trusted-advisor/`](trusted-advisor/) | Category summaries and findings | No screenshots yet |

Update the **Status** column when images are added, and say whether each one comes from the **UMGC course lab** or a **personal sandbox account**.

## Naming

`<category>/<yyyy-mm-dd>-<short-description>.png`, for example `dms/2025-03-02-source-endpoint-test.png`.

Avoid the words `secret` or `password` in file names: the repository's `.gitignore` excludes files with those names.

## Redaction Checklist

Every screenshot must be checked before it is committed. Blur or crop, don't just draw a thin box over the text.

- [ ] AWS account IDs (console header, ARNs, URLs)
- [ ] Access keys, secret keys, session tokens
- [ ] Passwords, connection strings, Secrets Manager values
- [ ] Hostnames and endpoints (RDS endpoints, DMS server names, EC2 DNS names)
- [ ] Public IP addresses, and private IP addresses that reveal the real network
- [ ] Student IDs, names of other students or instructors, course portal details
- [ ] Personal information (email addresses, phone numbers, HR records)
- [ ] Browser and session details (bookmarks, other tabs, user menus, signed-in account names)
- [ ] Image metadata removed (for example with `exiftool -all= file.png`)

If any item can't be redacted cleanly, don't add the screenshot.
