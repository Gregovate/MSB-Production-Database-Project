/* ============================================================================
File:        23_replacement_label_instruction_validation.sql
Validation:  Correct replacement-label instruction

Purpose:
  Verify the installed report view and current rows use the exact operator
  instruction "Print replacement label".

Safety:
  Read-only. Does not modify reconciliation or production data.

Revision History:
  2026-08-03  GAL / OpenAI  Initial validation.
============================================================================ */

WITH definition AS (
    SELECT pg_get_viewdef(
        'ops.v_lor_reconciliation_display_name_change_audit'::regclass,
        true
    ) AS sql_text
)
SELECT 'view uses correct fixed instruction'::text AS check_name,
       sql_text LIKE '%Print replacement label%' AS passed
FROM definition
UNION ALL
SELECT 'view no longer uses incorrect instruction',
       sql_text NOT LIKE '%Preprint replacement label%'
FROM definition
UNION ALL
SELECT 'all current report rows use correct instruction',
       NOT EXISTS (
           SELECT 1
           FROM ops.v_lor_reconciliation_display_name_change_audit
           WHERE follow_up <> 'Print replacement label'
       );
