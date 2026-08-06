/* ============================================================================
Object:       LOR preflight application least-privilege grants
Filename:     grant_lor_preflight_app.sql
Revision:     2026-08-06 V0.2.0

Purpose:
  Grant the existing login role lor_preflight_app only the reads and secured
  reconciliation entry points required by backend.py and the immutable report
  publisher. This script does not create the login or store its password.

Revision history:
  2026-08-06  GAL / OpenAI  Added current-snapshot read access and the unified
                           reconciliation Start function for the lor2db page.
  2026-08-05  GAL / OpenAI  Initial application-role grant set.
============================================================================ */

BEGIN;

DO $block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lor_preflight_app') THEN
        RAISE EXCEPTION
            'Role lor_preflight_app does not exist; create the LOGIN separately with a secured password';
    END IF;
END;
$block$;

GRANT USAGE ON SCHEMA ops, ref, lor_snap TO lor_preflight_app;

GRANT SELECT ON
    ops.lor_reconciliation_run,
    ops.lor_reconciliation_group,
    ops.lor_reconciliation_action,
    ops.lor_reconciliation_result,
    ops.lor_reconciliation_source_run,
    ops.lor_reconciliation_source_preview,
    ops.lor_reconciliation_source_scene,
    ops.v_lor_reconciliation_run_review,
    ops.v_lor_reconciliation_group_review,
    ops.v_lor_reconciliation_operator_display_review,
    ops.v_lor_reconciliation_operator_stage_review,
    ops.v_lor_reconciliation_operator_scene_review,
    ops.v_lor_reconciliation_operator_scene_display_review,
    ref.display,
    ref.stage,
    ref.lor_scene
TO lor_preflight_app;

GRANT SELECT ON lor_snap.v_current_run TO lor_preflight_app;

GRANT EXECUTE ON FUNCTION
    ops.f_record_lor_reconciliation_action(bigint,bigint,text,text,jsonb,text),
    ops.f_record_lor_reconciliation_bulk_action(bigint,bigint[],text,text,text),
    ops.f_lor_reconciliation_display_name_changes_report(bigint),
    ops.f_start_lor_reconciliation(text)
TO lor_preflight_app;

GRANT EXECUTE ON PROCEDURE
    ops.p_finish_lor_reconciliation(bigint,text),
    ops.p_cancel_lor_reconciliation(bigint,text,text),
    ops.p_publish_lor_reconciliation_report(bigint,text,text,text,text)
TO lor_preflight_app;

COMMIT;

SELECT
    '2026-08-06-lor-preflight-app-grants-v2' AS applied_revision,
    current_user AS applied_by;
