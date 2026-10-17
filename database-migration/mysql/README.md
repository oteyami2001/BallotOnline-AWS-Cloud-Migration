# Source: On-Premises MySQL

Preparation of the BallotOnline HR database as an AWS DMS source.

| File | Purpose |
|---|---|
| [`source-preparation.sql`](source-preparation.sql) | Assessment queries and setup for the DMS migration user |

## What the script does

1. Reports the MySQL version, character set, and collation.
2. Checks binary logging settings needed for CDC (`log_bin = ON`, `binlog_format = ROW`, `binlog_row_image = FULL`, binlog retention ≥ 24 hours).
3. Measures schema size so the DMS replication instance and Aurora can be sized.
4. Lists tables by storage engine, size, and collation.
5. Finds tables **without a primary key**. CDC and DMS data validation need one.
6. Finds non-InnoDB tables.
7. Lists views, routines, triggers, and events. **DMS does not migrate these**, so they have to be recreated on Aurora separately.
8. Creates a dedicated `dms_migration` user:
   - limited to the DMS replication subnet (not `'%'`)
   - TLS required
   - `SELECT` on the HR schema only, plus `REPLICATION CLIENT` / `REPLICATION SLAVE` for CDC
9. Shows the grants. If `SELECT` is missing, the task fails with *"No tables were found at task initialization."*
10. Generates exact row-count queries to record a baseline before the Full Load.

## Usage

```bash
# Replace the placeholders in the script first (schema name, subnet, password)
mysql -u admin -p < source-preparation.sql
```

> Tested against MySQL 8.0. Placeholders such as `ballotonline_hr`, `10.0.%`, and `<REPLACE_WITH_STRONG_PASSWORD>` must be replaced. Never commit real values.
