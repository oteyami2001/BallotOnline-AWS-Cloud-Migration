-- =====================================================================
-- BallotOnline HR Database — Source MySQL Preparation for AWS DMS
-- =====================================================================
-- Purpose : Assess and prepare the on-premises MySQL HR database as an
--           AWS DMS source (Full Load + optional CDC).
-- Run as  : A MySQL administrator on the SOURCE server.
-- Target  : MySQL 5.7 / 8.0
--
-- Placeholders (replace before running):
--   ballotonline_hr          -> source schema name
--   10.0.%                   -> CIDR pattern of the DMS replication subnet
--   <REPLACE_WITH_STRONG_PASSWORD>
--
-- Never commit real passwords, hostnames, or IP addresses to Git.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Server version and basic information
-- ---------------------------------------------------------------------
SELECT VERSION()                AS mysql_version,
       @@hostname               AS host_name,
       @@port                   AS port,
       @@character_set_server   AS server_charset,
       @@collation_server       AS server_collation;


-- ---------------------------------------------------------------------
-- 2. Binary logging (required for CDC)
--    Expected values for AWS DMS CDC:
--      log_bin          = ON
--      binlog_format    = ROW
--      binlog_row_image = FULL
--      server_id        = any non-zero value
--      binlog retention = at least 24 hours
-- ---------------------------------------------------------------------
SHOW VARIABLES WHERE Variable_name IN (
    'log_bin',
    'binlog_format',
    'binlog_row_image',
    'server_id',
    'binlog_expire_logs_seconds',   -- MySQL 8.0
    'expire_logs_days'              -- MySQL 5.7
);

-- If the values above are wrong, set them in my.cnf and restart MySQL:
--
--   [mysqld]
--   server_id                  = 1
--   log_bin                    = mysql-bin
--   binlog_format              = ROW
--   binlog_row_image           = FULL
--   binlog_expire_logs_seconds = 86400   # MySQL 8.0 (use expire_logs_days = 1 on 5.7)


-- ---------------------------------------------------------------------
-- 3. Schema size (helps size the DMS replication instance and Aurora)
-- ---------------------------------------------------------------------
SELECT table_schema                                        AS schema_name,
       COUNT(*)                                            AS table_count,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM   information_schema.tables
WHERE  table_schema = 'ballotonline_hr'
  AND  table_type   = 'BASE TABLE'
GROUP  BY table_schema;


-- ---------------------------------------------------------------------
-- 4. Table inventory: engine, approximate rows, charset
--    AWS DMS CDC works best with InnoDB tables.
-- ---------------------------------------------------------------------
SELECT t.table_name,
       t.engine,
       t.table_rows                      AS approx_rows,
       t.table_collation,
       ROUND((t.data_length + t.index_length) / 1024 / 1024, 2) AS size_mb
FROM   information_schema.tables t
WHERE  t.table_schema = 'ballotonline_hr'
  AND  t.table_type   = 'BASE TABLE'
ORDER  BY size_mb DESC;


-- ---------------------------------------------------------------------
-- 5. Tables WITHOUT a primary key
--    DMS can migrate them, but CDC updates/deletes and data validation
--    need a primary or unique key. Fix these before migrating.
-- ---------------------------------------------------------------------
SELECT t.table_name
FROM   information_schema.tables t
LEFT   JOIN information_schema.table_constraints c
       ON  c.table_schema    = t.table_schema
       AND c.table_name      = t.table_name
       AND c.constraint_type = 'PRIMARY KEY'
WHERE  t.table_schema = 'ballotonline_hr'
  AND  t.table_type   = 'BASE TABLE'
  AND  c.constraint_name IS NULL;


-- ---------------------------------------------------------------------
-- 6. Non-InnoDB tables (convert before CDC if possible)
-- ---------------------------------------------------------------------
SELECT table_name, engine
FROM   information_schema.tables
WHERE  table_schema = 'ballotonline_hr'
  AND  table_type   = 'BASE TABLE'
  AND  engine      <> 'InnoDB';


-- ---------------------------------------------------------------------
-- 7. Objects DMS does NOT migrate automatically
--    Views, routines, triggers, and events must be recreated on Aurora
--    separately (for example, from a schema-only mysqldump).
-- ---------------------------------------------------------------------
SELECT 'VIEW'    AS object_type, table_name   AS object_name
FROM   information_schema.views    WHERE table_schema   = 'ballotonline_hr'
UNION ALL
SELECT routine_type,              routine_name
FROM   information_schema.routines WHERE routine_schema = 'ballotonline_hr'
UNION ALL
SELECT 'TRIGGER',                 trigger_name
FROM   information_schema.triggers WHERE trigger_schema = 'ballotonline_hr'
UNION ALL
SELECT 'EVENT',                   event_name
FROM   information_schema.events   WHERE event_schema   = 'ballotonline_hr';


-- ---------------------------------------------------------------------
-- 8. Dedicated, least-privilege DMS migration user
--    - Restricted to the DMS replication subnet (not '%')
--    - TLS required
--    - Read-only on the HR schema plus the replication privileges CDC needs
-- ---------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'dms_migration'@'10.0.%'
    IDENTIFIED BY '<REPLACE_WITH_STRONG_PASSWORD>'
    REQUIRE SSL;

GRANT SELECT
    ON ballotonline_hr.* TO 'dms_migration'@'10.0.%';

-- Needed only for CDC (reading the binary log)
GRANT REPLICATION CLIENT, REPLICATION SLAVE
    ON *.* TO 'dms_migration'@'10.0.%';

FLUSH PRIVILEGES;


-- ---------------------------------------------------------------------
-- 9. Verify the grants
--    If SELECT on the schema is missing, the DMS task can fail with:
--      "No tables were found at task initialization."
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'dms_migration'@'10.0.%';


-- ---------------------------------------------------------------------
-- 10. Baseline row counts (save the output — compare after Full Load)
--     Generates one exact COUNT(*) statement per table.
-- ---------------------------------------------------------------------
SELECT CONCAT(
         'SELECT ''', table_name, ''' AS table_name, COUNT(*) AS row_count FROM `',
         table_schema, '`.`', table_name, '` UNION ALL'
       ) AS row_count_statement
FROM   information_schema.tables
WHERE  table_schema = 'ballotonline_hr'
  AND  table_type   = 'BASE TABLE'
ORDER  BY table_name;
-- Copy the generated lines, remove the final "UNION ALL", and run them.
-- Run the same statements on Aurora after the load (see ../aurora/validation-queries.sql).
