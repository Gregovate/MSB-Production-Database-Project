/* ============================================================================
Migration: 0040_sync_existing_stage_folder_path.sql
Issue:     #101 Synchronize existing Stage folder_path from governed LOR root evidence

Purpose:
  Close the existing-Stage path synchronization gap left intentionally outside
  Issue #96.

  The parser/ingest already freezes Google Drive BackgroundFile path evidence
  in lor_snap. This migration therefore does not search or enumerate Google
  Drive. It uses ops.f_lor_governed_stage_roots(import_run_id, stage_key),
  installed by migration 0039, as the only path authority.

  For an existing permanent Stage/Sub-stage:
  - P1 may synchronize folder_path only when its frozen reconciliation import
    proves exactly one governed root;
  - the governed root's stage_name and folder_name must exactly match the
    permanent ref.stage identity;
  - the permanent stage_id is preserved;
  - held/special Stage keys 12,39,40,90-94 are excluded.

  Installation also repairs any currently stale/blank normal governed paths
  from the latest frozen import under the same exact-one-root rules. On the
  production baseline observed for import 59, that is exactly 05a, 07a, and 17.

Safety:
  - No Google Drive filesystem access or enumeration.
  - No parser change.
  - No FieldWiring/Procedures/resolver change.
  - No ingest or reconciliation lifecycle advancement.
  - No synthesized paths from Stage names.
============================================================================ */

BEGIN;

DO $prerequisite$
BEGIN
    IF to_regprocedure(
        'ops.f_lor_governed_stage_roots(bigint,text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040 requires migration 0039 governed-root resolver';
    END IF;
END
$prerequisite$;

ALTER PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint)
    RENAME TO p1_promote_stage_from_reconciliation_before_0040;

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation_before_0040(bigint) FROM PUBLIC;

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

WITH current_run AS (
    SELECT max(import_run_id) AS import_run_id
    FROM lor_snap.v_current_run
),
sync_target AS (
    SELECT
        s.stage_id,
        root.folder_path
    FROM current_run AS cr
    JOIN ref.stage AS s ON true
    CROSS JOIN LATERAL (
        SELECT
            min(r.folder_path) AS folder_path,
            min(r.stage_name) AS stage_name,
            min(r.folder_name) AS folder_name
        FROM ops.f_lor_governed_stage_roots(
            cr.import_run_id,
            s.stage_key
        ) AS r
        HAVING count(*) = 1
    ) AS root
    WHERE cr.import_run_id IS NOT NULL
      AND s.stage_key ~ '^[0-9]{2}[A-Za-z]?$'
      AND s.stage_key NOT IN (
            '12','39','40','90','91','92','93','94'
      )
      AND s.stage_name IS NOT DISTINCT FROM root.stage_name
      AND s.folder_name IS NOT DISTINCT FROM root.folder_name
      AND s.folder_path IS DISTINCT FROM root.folder_path
)
UPDATE ref.stage AS s
   SET folder_path = t.folder_path,
       updated_at = now(),
       updated_by = current_user
FROM sync_target AS t
WHERE s.stage_id = t.stage_id
  AND s.folder_path IS DISTINCT FROM t.folder_path;

COMMIT;

SELECT
    '2026-08-30-stage-folder-path-sync-v1'::text AS installed_revision,
    to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation_before_0040(bigint)'
    ) IS NOT NULL AS preserved_prior_p1,
    position(
        'P1_STAGE_FOLDER_PATH'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS has_existing_stage_path_sync;
