/* ============================================================================
Object:       Current P1 stage promotion entry procedure
Revision:     2026-08-30-stage-folder-path-sync-v1
Migration:    0040_sync_existing_stage_folder_path.sql
Issue:        #101

Purpose:
  Wrap the production-accepted Stage promotion procedure from migration 0039
  and synchronize an existing governed Stage/Sub-stage folder_path only when
  the reconciliation run's frozen lor_snap import proves exactly one governed
  Google Drive root for the same permanent Stage identity.

Safety:
  - Does not enumerate or search Google Drive.
  - Uses only ops.f_lor_governed_stage_roots() over the frozen import.
  - Requires exact governed stage_name/folder_name agreement before path sync.
  - Excludes held/special Stage keys 12,39,40,90-94.
  - Preserves permanent stage_id.
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
    v_path record;
BEGIN
    SELECT r.import_run_id
      INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    CALL ref.p1_promote_stage_from_reconciliation_before_0040(
        p_lor_reconciliation_run_id
    );

    FOR v_path IN
        WITH eligible_stage AS (
            SELECT DISTINCT c.resolved_stage_id AS stage_id
            FROM ops.lor_reconciliation_stage_candidate AS c
            JOIN ops.v_lor_reconciliation_group_review AS gr
              ON gr.lor_reconciliation_group_id =
                    c.lor_reconciliation_group_id
            WHERE c.lor_reconciliation_run_id =
                    p_lor_reconciliation_run_id
              AND c.resolved_stage_id IS NOT NULL
              AND gr.effective_resolution_state IN (
                    'AUTO_APPROVED', 'APPROVED'
              )
        )
        SELECT
            e.stage_id,
            s.stage_key,
            root.folder_path
        FROM eligible_stage AS e
        JOIN ref.stage AS s
          ON s.stage_id = e.stage_id
        CROSS JOIN LATERAL (
            SELECT
                min(r.folder_path) AS folder_path,
                min(r.stage_name) AS stage_name,
                min(r.folder_name) AS folder_name
            FROM ops.f_lor_governed_stage_roots(
                v_import_run_id,
                s.stage_key
            ) AS r
            HAVING count(*) = 1
        ) AS root
        WHERE s.stage_key ~ '^[0-9]{2}[A-Za-z]?$'
          AND s.stage_key NOT IN (
                '12','39','40','90','91','92','93','94'
          )
          AND s.stage_name IS NOT DISTINCT FROM root.stage_name
          AND s.folder_name IS NOT DISTINCT FROM root.folder_name
          AND s.folder_path IS DISTINCT FROM root.folder_path
        ORDER BY e.stage_id
    LOOP
        UPDATE ref.stage AS s
           SET folder_path = v_path.folder_path,
               updated_at = now(),
               updated_by = current_user
         WHERE s.stage_id = v_path.stage_id
           AND s.folder_path IS DISTINCT FROM v_path.folder_path;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id,
                import_run_id,
                entity_type,
                entity_key,
                result_class,
                reason_code,
                operator_message,
                committed
            ) VALUES (
                p_lor_reconciliation_run_id,
                v_import_run_id,
                'STAGE',
                v_path.stage_id::text,
                'UPDATED',
                'P1_STAGE_FOLDER_PATH',
                format(
                    'UPDATED: Stage %s folder_path from frozen governed root %s; permanent stage_id %s.',
                    v_path.stage_key,
                    v_path.folder_path,
                    v_path.stage_id
                ),
                true
            );
        END IF;
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint) IS
'Reconciliation-gated P1. Preserves migration-0039 Stage authority behavior and synchronizes an existing Stage/Sub-stage folder_path only from one exact frozen governed LOR root that matches permanent Stage identity.';

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
