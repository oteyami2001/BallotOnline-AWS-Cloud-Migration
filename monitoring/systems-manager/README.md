# AWS Systems Manager

Day-to-day management of the migrated Intranet, FTP, and NTP servers without opening SSH or RDP. Defined in [`07-operations.yaml`](../../infrastructure-as-code/cloudformation/07-operations.yaml).

## Prerequisites

Each migrated EC2 instance needs:

1. The **`ballotonline-ec2-managed`** instance profile (`AmazonSSMManagedInstanceCore` + `CloudWatchAgentServerPolicy`), set in the AWS MGN launch template.
2. Tags, also set in the launch template:

   | Tag | Value | Used by |
   |---|---|---|
   | `Project` | `BallotOnline` | Patching, inventory, agent install, IAM scoping |
   | `BallotOnlineOS` | `Linux` or `Windows` | Chooses the CloudWatch agent configuration |

3. Outbound HTTPS to Systems Manager endpoints (through the NAT gateway, or VPC interface endpoints).

## Capabilities Used

| Capability | How BallotOnline uses it | Defined in |
|---|---|---|
| **SSM Agent** | Required on every managed instance. Hyper-V servers migrated with MGN do not necessarily have it, so turn on MGN's post-launch action that installs the SSM Agent, or install it during test launch. | MGN launch settings |
| **Session Manager** | Browser or CLI shell on Linux and Windows servers with no inbound ports, bastion host, or SSH keys | IAM + instance profile |
| **Run Command** | Run the same command on many servers at once (for example, restart a service or collect logs), targeted by tag | Ad hoc |
| **Automation** | Repeatable, multi-step procedures. The example runbook is read-only. | [`automation-runbook.yaml`](automation-runbook.yaml) |
| **Patch Manager** | Daily scan, weekly install | `07-operations.yaml` |
| **Inventory** | Installed software, services, network configuration | `07-operations.yaml` |
| **Parameter Store** | CloudWatch agent configuration (`AmazonCloudWatch-*` parameters). Secrets stay in Secrets Manager. | `07-operations.yaml` |

## Session Manager Instead of SSH/RDP

Before migration, the Hyper-V servers were administered over SSH or RDP. On AWS, Session Manager replaces both:

| | SSH / RDP | Session Manager |
|---|---|---|
| Inbound ports | 22 / 3389 open in a security group | **None.** The agent connects outbound over HTTPS. |
| Credentials | SSH keys or local passwords to distribute and rotate | IAM permissions, with MFA enforced by [`require-mfa.json`](../../security/iam-policies/require-mfa.json) |
| Network path | VPN or bastion host | Systems Manager service endpoint (NAT or VPC endpoints) |
| Audit | Server-side logs only | Every session start/stop in CloudTrail; session output can be logged to CloudWatch Logs or S3 |

That is why the security groups in [`02-security.yaml`](../../infrastructure-as-code/cloudformation/02-security.yaml) open no administrative ports.

## Automation Runbook

[`automation-runbook.yaml`](automation-runbook.yaml) is a **read-only** health check:

1. Reads the instance state and EC2 status checks.
2. Stops if the instance is not `running` or the SSM Agent is not `Online`.
3. Detects Linux or Windows.
4. Collects uptime, memory, disk, key service status, time sync, and listening ports.

It never restarts, patches, or reconfigures anything, so it is safe to run first whenever an alarm fires. Register and run it:

```bash
aws ssm create-document --name BallotOnline-InstanceHealthCheck \
  --document-type Automation --document-format YAML \
  --content file://automation-runbook.yaml

aws ssm start-automation-execution --document-name BallotOnline-InstanceHealthCheck \
  --parameters InstanceId=<i-...>
```

## State Manager Associations

| Association | Document | Schedule | What it does |
|---|---|---|---|
| `install-cloudwatch-agent` | `AWS-ConfigureAWSPackage` | Every 30 days | Installs or updates the CloudWatch agent |
| `configure-cloudwatch-agent-linux` / `-windows` | `AmazonCloudWatch-ManageAgent` | Every 30 days | Applies the agent config from Parameter Store |
| `patch-scan` | `AWS-RunPatchBaseline` (Scan) | Daily | Reports missing patches to Patch Manager compliance |
| `patch-install` | `AWS-RunPatchBaseline` (Install) | Sundays 03:00 UTC | Installs patches one server at a time, rebooting if needed |
| `inventory` | `AWS-GatherSoftwareInventory` | Daily | Collects installed applications, services, network config, Windows updates |

Patching uses the AWS default patch baselines for each operating system. Installing on **one server at a time**, with **at most one error**, stops a bad patch from taking down every service at once.

## CloudWatch Agent

Configurations are stored in Parameter Store as `AmazonCloudWatch-ballotonline-linux` and `AmazonCloudWatch-ballotonline-windows`. The `AmazonCloudWatch-` prefix is required for the instance role to read them.

| OS | Metrics (namespace `CWAgent`) | Logs |
|---|---|---|
| Linux | `mem_used_percent`, `disk used_percent` (/), `swap_used_percent` | `/var/log/messages`, `/var/log/secure` |
| Windows | `Memory % Committed Bytes In Use`, `LogicalDisk % Free Space` (C:) | System, Application, and Security event logs |

EC2 does not report memory or disk usage by default, so the agent fills the main gap left after the move from Hyper-V.

## Everyday Tasks

| Task | How |
|---|---|
| Open a shell on a server | Systems Manager → Session Manager → Start session (or `aws ssm start-session --target i-...`) |
| Check patch compliance | Systems Manager → Patch Manager → Compliance reporting |
| Find which servers run a package | Systems Manager → Inventory |
| Run a command on all servers | `aws ssm send-command --document-name AWS-RunShellScript --targets Key=tag:Project,Values=BallotOnline ...` |
