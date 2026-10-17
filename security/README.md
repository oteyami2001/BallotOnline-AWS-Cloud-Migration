# 🔐 Security

Security controls for the BallotOnline AWS migration, from identity and network design to encryption, logging, and threat detection.

| Document | Contents |
|---|---|
| [`security-controls.md`](security-controls.md) | Shared responsibility, defense in depth, controls by layer (identity, network, data, detection), incident response, migration risk register |
| [`security-checklist.md`](security-checklist.md) | Step-by-step checks before, during, and after migration, plus sign-off |
| [`iam-policies/`](iam-policies/) | Least-privilege IAM policies (MFA enforcement, migration operator) and an access matrix |

## Project Scope

- **UMGC course project:** security controls (IAM least privilege, MFA, security groups, encryption, logging) were evaluated as part of the BallotOnline design.
- **This repository:** implements them as CloudFormation templates and IAM policies. The templates, including the governance stack (CloudTrail, GuardDuty, Access Analyzer, Security Hub), **pass `cfn-lint` but have not been deployed to a real AWS account.** The IAM policies were linted with Parliament.
- **Recommended practice:** the checklist items and the incident response outline.

## Implemented as Code

| Control Area | CloudFormation Stack |
|---|---|
| Private subnets, VPN, Flow Logs | [`01-network.yaml`](../infrastructure-as-code/cloudformation/01-network.yaml) |
| Security groups, KMS data key, SSM instance profile, DMS roles | [`02-security.yaml`](../infrastructure-as-code/cloudformation/02-security.yaml) |
| Encrypted Aurora, TLS required, Secrets Manager password | [`03-aurora.yaml`](../infrastructure-as-code/cloudformation/03-aurora.yaml) |
| DMS over TLS, credentials via dynamic references | [`04-dms.yaml`](../infrastructure-as-code/cloudformation/04-dms.yaml) |
| CloudTrail, GuardDuty, IAM Access Analyzer, Security Hub | [`05-governance.yaml`](../infrastructure-as-code/cloudformation/05-governance.yaml) |

## Key Principles

- **Least privilege:** every person, server, and service gets only the access it needs
- **MFA everywhere:** no console or migration action without MFA
- **Private by default:** nothing is reachable from the internet
- **Encrypt everything:** KMS at rest, TLS and IPsec in transit
- **No secrets in code:** Secrets Manager and dynamic references only
- **Log and detect:** CloudTrail, Flow Logs, and GuardDuty from day one
