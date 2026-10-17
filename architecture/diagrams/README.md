# Diagrams

| File | Description |
|---|---|
| [`aws-target-architecture.svg`](aws-target-architecture.svg) | Target AWS architecture: on-premises MySQL and Hyper-V, Site-to-Site VPN, VPC across two Availability Zones, DMS → Aurora and MGN → EC2 migration paths, and regional security/operations services. |
| [`aws-dms-migration-flow.svg`](aws-dms-migration-flow.svg) | HR database migration: MySQL → AWS DMS (source endpoint `ccs640mysql`, task `ccs640migration`, target endpoint `ccs640target`) → Aurora MySQL, with the two issues hit during the project and the migration stages. |

![BallotOnline AWS target architecture](aws-target-architecture.svg)

![BallotOnline AWS DMS migration flow](aws-dms-migration-flow.svg)

The diagram is plain SVG, so it renders on GitHub and can be edited in any text editor or imported into draw.io.
