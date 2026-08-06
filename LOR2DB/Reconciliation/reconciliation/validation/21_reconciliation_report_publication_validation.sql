/* ============================================================================
Object:       Reconciliation report publication validation
File:         21_reconciliation_report_publication_validation.sql

Purpose:
  Validate installation and safety boundaries without publishing a report,
  changing a reconciliation run, or executing P1-P4.

Expected:
  Every row returns passed = true.
============================================================================ */

WITH installed AS (
    SELECT
        p.oid,
        pg_get_functiondef(p.oid) AS definition
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'ops'
      AND p.proname = 'p_publish_lor_reconciliation_report'
      AND pg_get_function_identity_arguments(p.oid) =
          'IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text'
)
SELECT 'publication procedure installed' AS check_name,
       count(*) = 1 AS passed
FROM installed
UNION ALL
SELECT 'requires retained run parameter',
       position('p_lor_reconciliation_run_id' IN definition) > 0
FROM installed
UNION ALL
SELECT 'requires REPORTING status',
       position('v_run.status <> ''REPORTING''' IN definition) > 0
FROM installed
UNION ALL
SELECT 'does not select latest ingest',
       position('max(import_run_id)' IN lower(definition)) = 0
       AND position('order by import_run_id desc' IN lower(definition)) = 0
FROM installed
UNION ALL
SELECT 'does not execute promotion procedures',
       position('p1_promote' IN lower(definition)) = 0
       AND position('p2_promote' IN lower(definition)) = 0
       AND position('p3_promote' IN lower(definition)) = 0
       AND position('p4_promote' IN lower(definition)) = 0
FROM installed
UNION ALL
SELECT 'report hash column installed',
       EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_schema = 'ops'
             AND table_name = 'lor_reconciliation_run'
             AND column_name = 'report_sha256'
       );
