# Diagrams

| File | Description |
|---|---|
| [`aws-target-architecture.svg`](aws-target-architecture.svg) | Target AWS architecture: on-premises MySQL and Hyper-V, Site-to-Site VPN, VPC across two Availability Zones, DMS → Aurora and MGN → EC2 migration paths, and regional security/operations services. |
| [`aws-dms-migration-flow.svg`](aws-dms-migration-flow.svg) | HR database migration: MySQL → AWS DMS (source endpoint `ccs640mysql`, task `ccs640migration`, target endpoint `ccs640target`) → Aurora MySQL, with the two issues hit during the project and the migration stages. |
| [`aws-mgn-server-migration-flow.svg`](aws-mgn-server-migration-flow.svg) | Server migration: Hyper-V VMs with the AWS Replication Agent → staging subnet (replication servers, EBS, snapshots) → test and cutover EC2 instances, plus the MGN lifecycle. |
| [`monitoring-operations.svg`](monitoring-operations.svg) | Observability: EC2, Aurora, DMS, VPC/VPN, CloudTrail/GuardDuty → CloudWatch and EventBridge → SNS → operations, with Systems Manager and Trusted Advisor as complementary services. |

![BallotOnline AWS target architecture](aws-target-architecture.svg)

![BallotOnline AWS DMS migration flow](aws-dms-migration-flow.svg)

![BallotOnline AWS MGN server migration flow](aws-mgn-server-migration-flow.svg)

![BallotOnline observability and operations](monitoring-operations.svg)

The diagram is plain SVG, so it renders on GitHub and can be edited in any text editor or imported into draw.io.
