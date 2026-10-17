# Database Migration (Replatform)

MySQL HR database → AWS DMS (full load + CDC) → Amazon Aurora MySQL.

- [`mysql/`](mysql/) — source database preparation (binary logging, replication user, schema review)
- [`aws-dms/`](aws-dms/) — replication instance, endpoints, tasks, table mappings
- [`aurora/`](aurora/) — target cluster configuration and post-load validation
