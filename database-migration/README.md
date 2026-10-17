# Database Migration (Replatform)

![BallotOnline AWS DMS migration flow](../architecture/diagrams/aws-dms-migration-flow.svg)

Full write-up: [`aws-dms/README.md`](aws-dms/README.md)

MySQL HR database → AWS DMS (full load + CDC) → Amazon Aurora MySQL.

- [`mysql/`](mysql/) — source database preparation (binary logging, replication user, schema review)
- [`aws-dms/`](aws-dms/) — replication instance, endpoints, tasks, table mappings
- [`aurora/`](aurora/) — target cluster configuration and post-load validation
