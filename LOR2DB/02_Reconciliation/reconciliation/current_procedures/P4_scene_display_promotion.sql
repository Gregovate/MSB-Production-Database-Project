/* ============================================================================
Object group: Current installed reconciliation promotion procedures
Repository:   LOR2DB/Reconciliation/reconciliation/current_procedures/
Filename:     P4_scene_display_promotion.sql
Revision:     2026-08-05-installed-after-0029-v4

Purpose:
  Canonical standalone definition of the P4 procedure currently installed in
  production after migrations 0018 and 0029 v4. This file is the inspection
  and repair source for P4; numbered migrations remain installation history.

Safety:
  Installing this file replaces the P4 procedure definition only. It does not
  call P4, start or finish reconciliation, or modify production rows.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ref.p4_promote_scene_display_from_reconciliation(
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
    v_display_id bigint;
    v_lor_scene_id bigint;
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
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P4',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_scene_display_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT EXISTS (
          SELECT 1 FROM lor_snap.scene_lor_props AS slp
          WHERE slp.import_run_id = v_import_run_id
            AND slp.preview_id = c.preview_id
            AND slp.scene_id = c.scene_id
            AND slp.prop_id = c.source_prop_id
            AND slp.raw_prop_id = c.source_lor_prop_id
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P4 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_row IN
        SELECT c.*
        FROM ops.lor_reconciliation_scene_display_candidate AS c
        JOIN ops.lor_reconciliation_display_candidate AS dc
          ON dc.lor_reconciliation_display_candidate_id =
             c.lor_reconciliation_display_candidate_id
        JOIN ops.v_lor_reconciliation_group_review AS display_group
          ON display_group.lor_reconciliation_group_id =
             dc.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.initial_resolution_state = 'AUTO_APPROVED'
          AND NOT c.is_blocking
          AND display_group.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
        ORDER BY c.lor_reconciliation_scene_display_candidate_id
    LOOP
        SELECT d.display_id INTO v_display_id
        FROM ref.display AS d
        WHERE d.lor_prop_id = v_row.source_lor_prop_id;

        IF v_display_id IS NULL THEN
            RAISE EXCEPTION 'P4 cannot resolve permanent display for frozen source UUID %',
                v_row.source_lor_prop_id;
        END IF;

        SELECT ls.lor_scene_id INTO v_lor_scene_id
        FROM ref.lor_scene AS ls
        WHERE ls.preview_uuid = v_row.preview_id
          AND ls.scene_uuid = v_row.scene_id;

        IF v_lor_scene_id IS NULL THEN
            RAISE EXCEPTION 'P4 cannot resolve promoted scene %/%',
                v_row.preview_id, v_row.scene_id;
        END IF;

        INSERT INTO ref.lor_scene_display (
            lor_scene_id, preview_uuid, display_id, scene_prop_ordinal,
            scene_role, source, source_import_run_id
        ) VALUES (
            v_lor_scene_id, v_row.preview_id, v_display_id,
            v_row.scene_prop_ordinal, v_row.scene_role,
            v_row.membership_source, v_import_run_id
        )
        ON CONFLICT (preview_uuid, display_id) DO UPDATE
           SET lor_scene_id = EXCLUDED.lor_scene_id,
               scene_prop_ordinal = EXCLUDED.scene_prop_ordinal,
               scene_role = EXCLUDED.scene_role,
               source = EXCLUDED.source,
               source_import_run_id = EXCLUDED.source_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE ref.lor_scene_display.lor_scene_id IS DISTINCT FROM EXCLUDED.lor_scene_id
            OR ref.lor_scene_display.scene_prop_ordinal IS DISTINCT FROM EXCLUDED.scene_prop_ordinal
            OR ref.lor_scene_display.scene_role IS DISTINCT FROM EXCLUDED.scene_role
            OR ref.lor_scene_display.source IS DISTINCT FROM EXCLUDED.source

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'SCENE_DISPLAY',
                v_row.candidate_key,
                CASE WHEN v_row.existing_display_id IS NULL THEN 'ADDED' ELSE 'REASSOCIATED' END,
                'P4_' || v_row.classification_code,
                format('P4 synchronized display_id %s to scene %s/%s.',
                       v_display_id, v_row.preview_id, v_row.scene_id), true
            );
        END IF;
    END LOOP;

    /* Conservative deletion: any blocked/deferred item preserves its preview. */
    FOR v_row IN
        DELETE FROM ref.lor_scene_display AS lsd
        WHERE NOT EXISTS (
                  SELECT 1 FROM lor_snap.previews AS p
                  WHERE p.import_run_id = v_import_run_id
                    AND p.id = lsd.preview_uuid
              )
           OR (
               NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS blocked
                   WHERE blocked.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                     AND blocked.preview_id = lsd.preview_uuid
                     AND blocked.is_blocking
               )
               AND NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS held
                   JOIN ops.lor_reconciliation_display_candidate AS dc
                     ON dc.lor_reconciliation_display_candidate_id =
                        held.lor_reconciliation_display_candidate_id
                   JOIN ops.v_lor_reconciliation_group_review AS dgr
                     ON dgr.lor_reconciliation_group_id =
                        dc.lor_reconciliation_group_id
                   WHERE held.lor_reconciliation_run_id =
                         p_lor_reconciliation_run_id
                     AND held.preview_id = lsd.preview_uuid
                     AND dgr.effective_resolution_state NOT IN (
                         'AUTO_APPROVED', 'APPROVED'
                     )
               )
               AND NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS current_member
                   JOIN ref.display AS d
                     ON d.lor_prop_id = current_member.source_lor_prop_id
                   WHERE current_member.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                     AND current_member.preview_id = lsd.preview_uuid
                     AND d.display_id = lsd.display_id
               )
           )
        RETURNING lsd.preview_uuid, lsd.display_id, lsd.lor_scene_id
    LOOP
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'SCENE_DISPLAY',
            'SCENE_DISPLAY:' || v_row.preview_uuid || ':' || v_row.display_id,
            'UPDATED', 'P4_REMOVE_OBSOLETE_MEMBERSHIP',
            format('P4 removed obsolete current-state membership for display_id %s in preview %s.',
                   v_row.display_id, v_row.preview_uuid), true
        );
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p4_promote_scene_display_from_reconciliation(bigint) IS
'Internal reconciliation-gated P4. Synchronizes approved frozen memberships by permanent display_id and conservatively removes obsolete current-state assignments. Canonical revision 2026-08-05-installed-after-0029-v4.';

REVOKE EXECUTE ON PROCEDURE
    ref.p4_promote_scene_display_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
