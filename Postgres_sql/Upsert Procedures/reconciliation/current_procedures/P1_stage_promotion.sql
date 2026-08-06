/* ============================================================================
Object group: Current installed reconciliation promotion procedures
Repository:   Postgres_sql/Upsert Procedures/reconciliation/current_procedures/
Filename:     P1_stage_promotion.sql
Revision:     2026-08-05-installed-after-0029-v4

Purpose:
  Canonical standalone definition of the P1 procedure currently installed in
  production after migrations 0016 and 0029 v4. This file is the inspection
  and repair source for P1; numbered migrations remain installation history.

Safety:
  Installing this file replaces the P1 procedure definition only. It does not
  call P1, start or finish reconciliation, or modify production rows.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ref.p1_promote_stage_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_unresolved integer;
    v_bad_source integer;
    v_stage record;
    v_binding record;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('READY_TO_FINISH', 'PROMOTING') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P1',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_unresolved
    FROM ops.v_lor_reconciliation_group_review AS gr
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND gr.entity_type = 'STAGE'
      AND gr.effective_resolution_state = 'UNRESOLVED';

    IF v_unresolved > 0 THEN
        RAISE EXCEPTION 'Reconciliation run % has % unresolved stage groups',
            p_lor_reconciliation_run_id, v_unresolved;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_stage_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT (
          (c.binding_type = 'PREVIEW' AND EXISTS (
              SELECT 1 FROM lor_snap.previews AS p
              WHERE p.import_run_id = v_import_run_id
                AND p.id = c.preview_id
                AND lower(btrim(p.stage_id)) = c.source_stage_key
                AND btrim(p.name) IS NOT DISTINCT FROM c.source_name
          ))
          OR
          (c.binding_type = 'SCENE' AND EXISTS (
              SELECT 1
              FROM lor_snap.scenes AS s
              JOIN lor_snap.scene_lor_props AS slp
                ON slp.import_run_id = s.import_run_id
               AND slp.preview_id = s.preview_id
               AND slp.scene_id = s.scene_id
              WHERE s.import_run_id = v_import_run_id
                AND s.preview_id = c.preview_id
                AND s.scene_id = c.scene_id
                AND lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) =
                    c.source_stage_key
                AND btrim(s.name) IS NOT DISTINCT FROM c.source_name
          ))
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% frozen stage candidates no longer match captured import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_stage IN
        SELECT
            c.resolved_stage_id,
            min(c.proposed_stage_key) AS proposed_stage_key,
            min(c.proposed_stage_name) FILTER (WHERE c.metadata_authoritative)
                AS proposed_stage_name,
            min(c.proposed_folder_name) FILTER (WHERE c.metadata_authoritative)
                AS proposed_folder_name,
            min(c.proposed_park_order) AS proposed_park_order,
            min(c.proposed_sub_order) AS proposed_sub_order
        FROM ops.lor_reconciliation_stage_candidate AS c
        JOIN ops.v_lor_reconciliation_group_review AS gr
          ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.resolved_stage_id IS NOT NULL
          AND gr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
          AND gr.effective_action_type IS DISTINCT FROM
                'PRESERVE_EXISTING_STAGE_METADATA'
        GROUP BY c.resolved_stage_id
        HAVING count(DISTINCT c.proposed_stage_key) = 1
    LOOP
        UPDATE ref.stage AS s
           SET stage_key = v_stage.proposed_stage_key,
               stage_name = coalesce(v_stage.proposed_stage_name, s.stage_name),
               folder_name = coalesce(v_stage.proposed_folder_name, s.folder_name),
               park_order = v_stage.proposed_park_order,
               sub_order = v_stage.proposed_sub_order,
               updated_at = now(),
               updated_by = current_user
         WHERE s.stage_id = v_stage.resolved_stage_id
           AND (
               s.stage_key IS DISTINCT FROM v_stage.proposed_stage_key
               OR (v_stage.proposed_stage_name IS NOT NULL
                   AND s.stage_name IS DISTINCT FROM v_stage.proposed_stage_name)
               OR (v_stage.proposed_folder_name IS NOT NULL
                   AND s.folder_name IS DISTINCT FROM v_stage.proposed_folder_name)
               OR s.park_order IS DISTINCT FROM v_stage.proposed_park_order
               OR s.sub_order IS DISTINCT FROM v_stage.proposed_sub_order
           );

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_stage.resolved_stage_id::text, 'UPDATED',
                'P1_STAGE_METADATA',
                format('UPDATED: Stage %s metadata and preserved permanent stage_id %s.',
                    v_stage.proposed_stage_key, v_stage.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;

    FOR v_binding IN
        SELECT c.*
        FROM ops.lor_reconciliation_stage_candidate AS c
        JOIN ops.v_lor_reconciliation_group_review AS gr
          ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.resolved_stage_id IS NOT NULL
          AND gr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
    LOOP
        INSERT INTO ref.stage_lor_binding (
            stage_id, binding_type, preview_id, scene_id, source_name,
            first_seen_import_run_id, last_seen_import_run_id
        ) VALUES (
            v_binding.resolved_stage_id, v_binding.binding_type,
            v_binding.preview_id, v_binding.scene_id, v_binding.source_name,
            v_import_run_id, v_import_run_id
        )
        ON CONFLICT DO NOTHING;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_binding.candidate_key, 'ADDED', 'P1_STAGE_LOR_BINDING',
                format('ADDED: %s binding %s%s to permanent stage_id %s.',
                    v_binding.binding_type,
                    v_binding.preview_id,
                    CASE WHEN v_binding.scene_id IS NULL THEN ''
                         ELSE '/' || v_binding.scene_id END,
                    v_binding.resolved_stage_id),
                true
            );
        END IF;

        UPDATE ref.stage_lor_binding AS b
           SET source_name = v_binding.source_name,
               last_seen_import_run_id = v_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE b.binding_type = v_binding.binding_type
           AND b.preview_id = v_binding.preview_id
           AND b.scene_id IS NOT DISTINCT FROM v_binding.scene_id
           AND b.stage_id = v_binding.resolved_stage_id
           AND (
               b.source_name IS DISTINCT FROM v_binding.source_name
           );

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_binding.candidate_key, 'UPDATED', 'P1_STAGE_LOR_BINDING',
                format('UPDATED: %s binding %s%s for permanent stage_id %s.',
                    v_binding.binding_type,
                    v_binding.preview_id,
                    CASE WHEN v_binding.scene_id IS NULL THEN ''
                         ELSE '/' || v_binding.scene_id END,
                    v_binding.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint) IS
'Internal reconciliation-gated P1. Promotes approved frozen stage metadata except where explicitly preserved, binds all approved LOR identities, never selects an ingest, and never deletes stages. Canonical revision 2026-08-05-installed-after-0029-v4.';

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
