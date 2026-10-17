# Target: Amazon Aurora MySQL

Validation of the migrated BallotOnline HR database before production cutover.

| File | Purpose |
|---|---|
| [`validation-queries.sql`](validation-queries.sql) | Schema, row-count, content-hash, and DMS validation checks |

## Validation approach

Queries marked **[SOURCE + TARGET]** run on both databases, and the results are compared side by side.

| Check | How |
|---|---|
| Connection | Aurora version and TLS cipher in use |
| Schema | Table list, column definitions, primary keys, indexes |
| Completeness | Exact `COUNT(*)` for every table |
| Correctness | Order-independent content hash per table (`SUM(CRC32(CONCAT_WS(...)))`) |
| Business data | Key ranges, date boundaries, NULL checks, sample records, non-ASCII names |
| DMS validation | Rows in `awsdms_control.awsdms_validation_failures_v1` (expect none) |
| Access | Application accounts and their TLS requirement |

The script ends with a **sign-off checklist**. Every item must pass before cutover.

## Remember

AWS DMS creates tables and primary keys only. Secondary indexes, foreign keys, views, stored routines, and triggers must be recreated from a schema-only dump:

```bash
mysqldump --no-data --routines --triggers --events ballotonline_hr > schema.sql
```

> Tested against MySQL 8.0. The `@@aurora_version` check and the DMS validation table only exist on Aurora with DMS validation turned on.
