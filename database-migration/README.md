# Database Migration (Replatform)

![BallotOnline AWS DMS migration flow](../architecture/diagrams/aws-dms-migration-flow.svg)

Full write-up: [`aws-dms/README.md`](aws-dms/README.md)

MySQL HR database → AWS DMS (full load + CDC) → Amazon Aurora MySQL.

| Folder | Contents |
|---|---|
| [`mysql/`](mysql/) | [`source-preparation.sql`](mysql/source-preparation.sql): binary logging checks, schema assessment, least-privilege DMS user |
| [`aws-dms/`](aws-dms/) | [Migration write-up](aws-dms/README.md), [`table-mappings.json`](aws-dms/table-mappings.json), [`task-settings.json`](aws-dms/task-settings.json) |
| [`aurora/`](aurora/) | [`validation-queries.sql`](aurora/validation-queries.sql): schema, row-count, and content-hash checks before cutover |
