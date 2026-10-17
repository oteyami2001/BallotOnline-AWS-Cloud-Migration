# Migration Architecture

Source (on-premises) and target (AWS) architecture for the BallotOnline migration.

- **Source:** MySQL HR database; Hyper-V hosts running Intranet, FTP, and NTP servers.
- **Target:** Amazon VPC with Aurora MySQL in private subnets and EC2 instances for migrated servers.

Diagrams are stored in [`diagrams/`](diagrams/).
