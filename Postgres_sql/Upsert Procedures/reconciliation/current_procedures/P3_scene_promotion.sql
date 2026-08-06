/* ============================================================================
Object group: Current installed reconciliation promotion procedures
Repository:   Postgres_sql/Upsert Procedures/reconciliation/current_procedures/
Filename:     P3_scene_promotion.sql
Revision:     2026-08-05-installed-after-0029-v4

Purpose:
  Canonical standalone definition of the P3 procedure currently installed in
  production after migrations 0018 and 0029 v4. This file is the inspection
  and repair source for P3; numbered migrations remain installation history.

Safety:
  Installing this file replaces the P3 procedure definition only. It does not
  call P3, start or finish reconciliation, or modify production rows.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ref.p3_promote_scene_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_bad_source integer;
    v_row record;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;
    IF v_status NOT IN ('READY_TO_FINISH', 'PROMOTING') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P3',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_scene_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT EXISTS (
          SELECT 1
          FROM lor_snap.scenes AS s
          WHERE s.import_run_id = v_import_run_id
            AND s.preview_id = c.preview_id
            AND s.scene_id = c.scene_id
            AND btrim(s.name) = c.scene_name
            AND (to_jsonb(s)->>'scene_section') IS NOT DISTINCT FROM c.scene_section
            AND (to_jsonb(s)->>'background_file') IS NOT DISTINCT FROM c.background_file
            AND nullif(to_jsonb(s)->>'h_scroll', '')::integer IS NOT DISTINCT FROM c.h_scroll
            AND nullif(to_jsonb(s)->>'v_scroll', '')::integer IS NOT DISTINCT FROM c.v_scroll
            AND nullif(to_jsonb(s)->>'zoom', '')::integer IS NOT DISTINCT FROM c.zoom
            AND (to_jsonb(s)->>'create_grid_view') IS NOT DISTINCT FROM c.create_grid_view
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P3 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_row IN
        SELECT c.*
        FROM ops.lor_reconciliation_scene_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.initial_resolution_state = 'AUTO_APPROVED'
          AND NOT c.is_blocking
        ORDER BY c.lor_reconciliation_scene_candidate_id
    LOOP
        INSERT INTO ref.lor_scene (
            preview_uuid, scene_uuid, stage_id, scene_name, scene_section,
            background_file, h_scroll, v_scroll, zoom, create_grid_view,
            source_import_run_id
        ) VALUES (
            v_row.preview_id, v_row.scene_id, v_row.resolved_stage_id,
            v_row.scene_name, v_row.scene_section, v_row.background_file,
            v_row.h_scroll, v_row.v_scroll, v_row.zoom,
            v_row.create_grid_view, v_import_run_id
        )
        ON CONFLICT (preview_uuid, scene_uuid) DO UPDATE
           SET stage_id = EXCLUDED.stage_id,
               scene_name = EXCLUDED.scene_name,
               scene_section = EXCLUDED.scene_section,
               background_file = EXCLUDED.background_file,
               h_scroll = EXCLUDED.h_scroll,
               v_scroll = EXCLUDED.v_scroll,
               zoom = EXCLUDED.zoom,
               create_grid_view = EXCLUDED.create_grid_view,
               source_import_run_id = EXCLUDED.source_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE ref.lor_scene.stage_id IS DISTINCT FROM EXCLUDED.stage_id
            OR ref.lor_scene.scene_name IS DISTINCT FROM EXCLUDED.scene_name
            OR ref.lor_scene.scene_section IS DISTINCT FROM EXCLUDED.scene_section
            OR ref.lor_scene.background_file IS DISTINCT FROM EXCLUDED.background_file
            OR ref.lor_scene.h_scroll IS DISTINCT FROM EXCLUDED.h_scroll
            OR ref.lor_scene.v_scroll IS DISTINCT FROM EXCLUDED.v_scroll
            OR ref.lor_scene.zoom IS DISTINCT FROM EXCLUDED.zoom
            OR ref.lor_scene.create_grid_view IS DISTINCT FROM EXCLUDED.create_grid_view

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'SCENE',
                v_row.candidate_key,
                CASE WHEN v_row.existing_lor_scene_id IS NULL THEN 'ADDED' ELSE 'UPDATED' END,
                'P3_' || v_row.classification_code,
                format('P3 synchronized scene %s/%s to permanent stage_id %s.',
                       v_row.preview_id, v_row.scene_id, v_row.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;

    /* Never delete from a preview containing a blocked frozen scene. */
    FOR v_row IN
        DELETE FROM ref.lor_scene AS ls
        WHERE (
            NOT EXISTS (
                SELECT 1 FROM lor_snap.previews AS p
                WHERE p.import_run_id = v_import_run_id
                  AND p.id = ls.preview_uuid
            )
            OR (
                NOT EXISTS (
                    SELECT 1
                    FROM ops.lor_reconciliation_scene_candidate AS blocked
                    WHERE blocked.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                      AND blocked.preview_id = ls.preview_uuid
                      AND blocked.is_blocking
                )
                AND NOT EXISTS (
                    SELECT 1
                    FROM ops.lor_reconciliation_scene_candidate AS current_scene
                    WHERE current_scene.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                      AND current_scene.preview_id = ls.preview_uuid
                      AND current_scene.scene_id = ls.scene_uuid
                )
            )
        )
        RETURNING ls.preview_uuid, ls.scene_uuid, ls.lor_scene_id
    LOOP
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'SCENE',
            'SCENE:' || v_row.preview_uuid || ':' || v_row.scene_uuid,
            'UPDATED', 'P3_REMOVE_OBSOLETE_SCENE',
            format('P3 removed obsolete current-state scene %s/%s (lor_scene_id %s).',
                   v_row.preview_uuid, v_row.scene_uuid, v_row.lor_scene_id), true
        );
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p3_promote_scene_from_reconciliation(bigint) IS
'Internal reconciliation-gated P3. Synchronizes approved frozen scene definitions and safely removes obsolete current-state scenes. Canonical revision 2026-08-05-installed-after-0029-v4.';

REVOKE EXECUTE ON PROCEDURE
    ref.p3_promote_scene_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
