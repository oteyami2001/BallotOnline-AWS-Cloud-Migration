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
