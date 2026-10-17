-- =====================================================================
-- BallotOnline HR Database — Aurora MySQL Target Validation
-- =====================================================================
-- Purpose : Confirm the AWS DMS migration copied the HR database
--           completely and correctly before production cutover.
-- Run on  : The Aurora MySQL TARGET (writer endpoint).
--           Queries marked [SOURCE + TARGET] must also be run on the
--           on-premises MySQL source so the results can be compared.
--
-- Placeholders (replace before running):
--   ballotonline_hr  -> migrated schema name
--   employees        -> example table; repeat checks for each critical table
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Confirm you are connected to Aurora, over TLS
-- ---------------------------------------------------------------------
SELECT @@aurora_version AS aurora_version,
       VERSION()        AS mysql_compatible_version;

SHOW SESSION STATUS LIKE 'Ssl_cipher';          -- non-empty value = TLS in use
SHOW VARIABLES     LIKE 'require_secure_transport';


-- ---------------------------------------------------------------------
-- 2. Schema validation  [SOURCE + TARGET]
--    Table list and column definitions should match.
-- ---------------------------------------------------------------------
SELECT table_name, engine, table_collation
FROM   information_schema.tables
WHERE  table_schema = 'ballotonline_hr'
  AND  table_type   = 'BASE TABLE'
ORDER  BY table_name;

SELECT table_name, ordinal_position, column_name, column_type,
       is_nullable, column_key
FROM   information_schema.columns
WHERE  table_schema = 'ballotonline_hr'
  AND  table_name IN (SELECT table_name FROM information_schema.tables
                     WHERE table_schema = 'ballotonline_hr' AND table_type = 'BASE TABLE')
ORDER  BY table_name, ordinal_position;

-- Primary keys present on every table
SELECT t.table_name,
       IF(c.constraint_name IS NULL, 'MISSING', 'OK') AS primary_key
FROM   information_schema.tables t
LEFT   JOIN information_schema.table_constraints c
       ON  c.table_schema    = t.table_schema
       AND c.table_name      = t.table_name
       AND c.constraint_type = 'PRIMARY KEY'
WHERE  t.table_schema = 'ballotonline_hr'
  AND  t.table_type   = 'BASE TABLE'
ORDER  BY t.table_name;

-- Note: AWS DMS creates tables and primary keys, but NOT secondary
-- indexes, foreign keys, views, routines, or triggers. Recreate those
-- from a schema-only dump and confirm them here:
SELECT table_name, index_name, non_unique, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM   information_schema.statistics
WHERE  table_schema = 'ballotonline_hr'
GROUP  BY table_name, index_name, non_unique
ORDER  BY table_name, index_name;


-- ---------------------------------------------------------------------
-- 3. Exact row counts  [SOURCE + TARGET]
--    Generates one COUNT(*) per table. Run the generated statements on
--    both databases; every count must match.
-- ---------------------------------------------------------------------
SELECT CONCAT(
         'SELECT ''', table_name, ''' AS table_name, COUNT(*) AS row_count FROM `',
         table_schema, '`.`', table_name, '` UNION ALL'
       ) AS row_count_statement
FROM   information_schema.tables
WHERE  table_schema = 'ballotonline_hr'
  AND  table_type   = 'BASE TABLE'
ORDER  BY table_name;


-- ---------------------------------------------------------------------
-- 4. Content fingerprint per table  [SOURCE + TARGET]
--    Row count + order-independent hash of every column. Matching
--    results give high confidence the data is identical.
--    Example for the employees table — adjust the column list per table.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                           AS row_count,
       SUM(CRC32(CONCAT_WS('|',
             emp_no, first_name, last_name, gender,
             birth_date, hire_date)))                     AS content_hash
FROM   ballotonline_hr.employees;


-- ---------------------------------------------------------------------
-- 5. Spot checks on critical business data  [SOURCE + TARGET]
-- ---------------------------------------------------------------------
-- Key ranges and date boundaries
SELECT MIN(emp_no)    AS min_emp_no,
       MAX(emp_no)    AS max_emp_no,
       MIN(hire_date) AS earliest_hire,
       MAX(hire_date) AS latest_hire
FROM   ballotonline_hr.employees;

-- NULLs in columns that should always be populated
SELECT SUM(first_name IS NULL) AS null_first_name,
       SUM(last_name  IS NULL) AS null_last_name,
       SUM(hire_date  IS NULL) AS null_hire_date
FROM   ballotonline_hr.employees;

-- Sample records (pick the same keys on source and target)
SELECT *
FROM   ballotonline_hr.employees
WHERE  emp_no IN (10001, 10050, 10100)
ORDER  BY emp_no;

-- Character data survived intact (accents, non-Latin names)
SELECT emp_no, first_name, last_name
FROM   ballotonline_hr.employees
WHERE  first_name REGEXP '[^ -~]' OR last_name REGEXP '[^ -~]'
LIMIT  20;


-- ---------------------------------------------------------------------
-- 6. AWS DMS built-in validation results (TARGET only)
--    Populated when ValidationSettings.EnableValidation = true
--    (see ../aws-dms/task-settings.json). Expect zero rows.
-- ---------------------------------------------------------------------
SELECT *
FROM   awsdms_control.awsdms_validation_failures_v1
ORDER  BY FAILURE_TIME DESC
LIMIT  50;


-- ---------------------------------------------------------------------
-- 7. Application readiness (TARGET only)
--    Application account exists with least-privilege access.
-- ---------------------------------------------------------------------
SELECT user, host, ssl_type
FROM   mysql.user
WHERE  user NOT IN ('rdsadmin', 'mysql.sys', 'mysql.session', 'mysql.infoschema');


-- =====================================================================
-- Sign-off checklist (all must be true before cutover)
--   [ ] Table list and column definitions match the source
--   [ ] Every table has a primary key
--   [ ] Secondary indexes, foreign keys, views, routines, triggers recreated
--   [ ] Exact row counts match for every table
--   [ ] Content hashes match for critical tables
--   [ ] No rows in awsdms_validation_failures_v1
--   [ ] Application connects over TLS and passes smoke tests
-- =====================================================================
