/* ============================================================================
Object:   Rollback-only validation of true no-op reconciliation writes
Filename: 25_true_noop_reconciliation_write_validation.sql

Safety:
  Runs inside one transaction ending in ROLLBACK. It does not call Finish or
  any promotion procedure. Temporary UPDATE statements target at most one row
  per guarded table and must be cancelled by the BEFORE UPDATE guards.

Revision history:
  2026-08-05  GAL / OpenAI  Initial true no-op write validation.
============================================================================ */

BEGIN;

DO $validation$
DECLARE
    v_definition text;
    v_rows bigint;
BEGIN
    SELECT pg_get_functiondef(
        'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;
    IF v_definition LIKE '%OR b.last_seen_import_run_id IS DISTINCT FROM v_import_run_id%' THEN
        RAISE EXCEPTION 'P1 still treats a new ingest ID as a binding change';
    END IF;

    SELECT pg_get_functiondef(
        'ref.p3_promote_scene_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;
    IF v_definition LIKE '%OR ref.lor_scene.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id%' THEN
        RAISE EXCEPTION 'P3 still treats a new ingest ID as a scene change';
    END IF;

    SELECT pg_get_functiondef(
        'ref.p4_promote_scene_display_from_reconciliation(bigint)'::regprocedure
    ) INTO v_definition;
    IF v_definition LIKE '%OR ref.lor_scene_display.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id%' THEN
        RAISE EXCEPTION 'P4 still treats a new ingest ID as a membership change';
    END IF;

    SELECT pg_get_functiondef(
        'ops.p_finish_lor_reconciliation(bigint,text)'::regprocedure
    ) INTO v_definition;
    IF v_definition LIKE '%OR s.source_import_run_id <> v_import_run_id%' THEN
        RAISE EXCEPTION 'Finish still requires unchanged scenes to receive the newest ingest ID';
    END IF;

    IF to_regprocedure('ref.trg_stage_lor_binding_require_change()') IS NULL
       OR to_regprocedure('ref.trg_lor_scene_require_change()') IS NULL
       OR to_regprocedure('ref.trg_lor_scene_display_require_change()') IS NULL THEN
        RAISE EXCEPTION 'One or more database-level no-op guards are missing';
    END IF;

    UPDATE ref.stage_lor_binding
       SET last_seen_import_run_id = last_seen_import_run_id,
           updated_at = clock_timestamp()
     WHERE stage_lor_binding_id = (
         SELECT min(stage_lor_binding_id) FROM ref.stage_lor_binding
     );
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'Stage binding no-op guard allowed % update(s)', v_rows;
    END IF;

    UPDATE ref.lor_scene
       SET source_import_run_id = source_import_run_id,
           updated_at = clock_timestamp()
     WHERE lor_scene_id = (SELECT min(lor_scene_id) FROM ref.lor_scene);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'Scene no-op guard allowed % update(s)', v_rows;
    END IF;

    UPDATE ref.lor_scene_display
       SET source_import_run_id = source_import_run_id,
           updated_at = clock_timestamp()
     WHERE (lor_scene_id, display_id) = (
         SELECT lor_scene_id, display_id
         FROM ref.lor_scene_display
         ORDER BY lor_scene_id, display_id
         LIMIT 1
     );
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'Membership no-op guard allowed % update(s)', v_rows;
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_state,
    'P1/P3/P4 and Finish no longer use ingest IDs as change evidence; database guards cancel provenance-only updates.'::text
        AS validation_result;

ROLLBACK;
