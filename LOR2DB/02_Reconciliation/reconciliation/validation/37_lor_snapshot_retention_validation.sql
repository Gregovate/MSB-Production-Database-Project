/* ============================================================================
Validation: 37 — bounded LOR snapshot retention
Issue:      #186
Migration:  LOR2DB/02_Reconciliation/reconciliation/migrations/
            0042_decouple_snapshot_provenance_and_add_retention.sql

Purpose:
  Read-only post-install validation for the snapshot-retention contract.

Safety:
  - Does not call the prune procedure.
  - Does not insert, update, or delete data.
  - Suitable for Production post-install validation before any separate prune
    authorization.
============================================================================ */

DO $validation$
DECLARE
    v_count integer;
    v_unexpected_fk text;
BEGIN
    /* The three durable/current-state provenance relationships must no longer
       retain raw snapshots by foreign key. */
    SELECT count(*)
      INTO v_count
    FROM pg_constraint AS c
    WHERE c.contype = 'f'
      AND c.confrelid = 'lor_snap.import_run'::regclass
      AND c.conrelid IN (
          'ref.lor_scene'::regclass,
          'ref.lor_scene_display'::regclass
      );

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            '37: ref.lor_scene/ref.lor_scene_display still retain lor_snap.import_run by FK';
    END IF;

    IF to_regclass('ops.lor_reconciliation_action_legacy') IS NOT NULL THEN
        SELECT count(*)
          INTO v_count
        FROM pg_constraint AS c
        WHERE c.contype = 'f'
          AND c.confrelid = 'lor_snap.import_run'::regclass
          AND c.conrelid = 'ops.lor_reconciliation_action_legacy'::regclass;

        IF v_count <> 0 THEN
            RAISE EXCEPTION
                '37: legacy reconciliation actions still retain lor_snap.import_run by FK';
        END IF;
    END IF;

    /* Internal snapshot ownership is still required. */
    SELECT count(*)
      INTO v_count
    FROM pg_constraint AS c
    WHERE c.contype = 'f'
      AND c.confrelid = 'lor_snap.import_run'::regclass
      AND c.conrelid = ANY (ARRAY[
          'lor_snap.dmx_channels'::regclass::oid,
          'lor_snap.previews'::regclass::oid,
          'lor_snap.props'::regclass::oid,
          'lor_snap.sub_props'::regclass::oid,
          'lor_snap.scene_lor_props'::regclass::oid,
          'lor_snap.scenes'::regclass::oid
      ]::oid[]);

    IF v_count <> 6 THEN
        RAISE EXCEPTION
            '37: expected six internal lor_snap import ownership FKs; found %',
            v_count;
    END IF;

    SELECT string_agg(
               format('%s.%I', c.conrelid::regclass::text, c.conname),
               ', ' ORDER BY c.conrelid::regclass::text, c.conname
           )
      INTO v_unexpected_fk
    FROM pg_constraint AS c
    WHERE c.contype = 'f'
      AND c.confrelid = 'lor_snap.import_run'::regclass
      AND NOT (
          c.conrelid = ANY (ARRAY[
              'lor_snap.dmx_channels'::regclass::oid,
              'lor_snap.previews'::regclass::oid,
              'lor_snap.props'::regclass::oid,
              'lor_snap.sub_props'::regclass::oid,
              'lor_snap.scene_lor_props'::regclass::oid,
              'lor_snap.scenes'::regclass::oid
          ]::oid[])
      );

    IF v_unexpected_fk IS NOT NULL THEN
        RAISE EXCEPTION
            '37: unexpected external FK(s) still retain lor_snap.import_run: %',
            v_unexpected_fk;
    END IF;
END;
$validation$;

DO $validation$
DECLARE
    v_function_oid oid;
    v_procedure_oid oid;
    v_automatic_procedure_oid oid;
BEGIN
    SELECT to_regprocedure('ops.f_lor_snapshot_retention_plan(integer)')::oid
      INTO v_function_oid;

    SELECT to_regprocedure('ops.p_prune_lor_snapshots(bigint[],integer)')::oid
      INTO v_procedure_oid;

    SELECT to_regprocedure('ops.p_run_lor_snapshot_retention()')::oid
      INTO v_automatic_procedure_oid;

    IF v_function_oid IS NULL THEN
        RAISE EXCEPTION '37: retention-plan function is missing';
    END IF;

    IF v_procedure_oid IS NULL THEN
        RAISE EXCEPTION '37: prune procedure is missing';
    END IF;

    IF v_automatic_procedure_oid IS NULL THEN
        RAISE EXCEPTION '37: automatic retention procedure is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_proc AS p
        CROSS JOIN LATERAL aclexplode(
            coalesce(p.proacl, acldefault('f', p.proowner))
        ) AS a
        WHERE p.oid IN (
            v_function_oid,
            v_procedure_oid,
            v_automatic_procedure_oid
        )
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            '37: PUBLIC still has EXECUTE on retention administration objects';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc AS p
        JOIN pg_roles AS r
          ON r.oid = p.proowner
        WHERE p.oid = v_automatic_procedure_oid
          AND r.rolname = 'msbadmin'
    ) THEN
        RAISE EXCEPTION
            '37: automatic retention procedure is not owned by msbadmin';
    END IF;
END;
$validation$;

DO $validation$
DECLARE
    v_latest_completed bigint;
BEGIN
    SELECT max(ir.import_run_id)
      INTO v_latest_completed
    FROM lor_snap.import_run AS ir
    WHERE ir.ingest_completed_at IS NOT NULL;

    IF v_latest_completed IS NULL THEN
        RAISE EXCEPTION '37: no completed lor_snap import exists';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        WHERE p.import_run_id = v_latest_completed
          AND p.retention_disposition = 'KEEP'
    ) THEN
        RAISE EXCEPTION
            '37: latest completed import % is not protected by the retention plan',
            v_latest_completed;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        WHERE p.completed_recency_rank <= 5
          AND p.retention_disposition <> 'KEEP'
    ) THEN
        RAISE EXCEPTION
            '37: newest-five completed working set contains a non-KEEP row';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        WHERE p.reconciliation_status IN (
            'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
            'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
        )
          AND p.retention_disposition <> 'KEEP'
    ) THEN
        RAISE EXCEPTION
            '37: non-terminal reconciliation snapshot is not protected';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        JOIN lor_snap.import_run AS ir
          ON ir.import_run_id = p.import_run_id
        WHERE ir.ingest_completed_at IS NULL
          AND ir.parser_version IS NULL
          AND ir.ingest_script_version IS NULL
          AND ir.ingest_started_at IS NULL
          AND ir.preview_count IS NULL
          AND ir.scene_count IS NULL
          AND ir.prop_count IS NULL
          AND ir.sub_prop_count IS NULL
          AND ir.dmx_channel_count IS NULL
          AND ir.scene_lor_prop_count IS NULL
          AND (
              p.reconciliation_status IS NULL
              OR p.reconciliation_status NOT IN (
                  'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
                  'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
              )
          )
          AND (
              p.retention_disposition <> 'PRUNE'
              OR p.retention_reason <> 'LEGACY_PRE_COMPLETION_TRACKING_SNAPSHOT'
          )
    ) THEN
        RAISE EXCEPTION
            '37: recognized pre-completion-tracking legacy snapshot is not PRUNE';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        JOIN lor_snap.import_run AS ir
          ON ir.import_run_id = p.import_run_id
        WHERE ir.ingest_completed_at IS NULL
          AND NOT (
              ir.parser_version IS NULL
              AND ir.ingest_script_version IS NULL
              AND ir.ingest_started_at IS NULL
              AND ir.preview_count IS NULL
              AND ir.scene_count IS NULL
              AND ir.prop_count IS NULL
              AND ir.sub_prop_count IS NULL
              AND ir.dmx_channel_count IS NULL
              AND ir.scene_lor_prop_count IS NULL
          )
          AND (
              p.reconciliation_status IS NULL
              OR p.reconciliation_status NOT IN (
                  'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
                  'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
              )
          )
          AND (
              p.retention_disposition <> 'BLOCK'
              OR p.retention_reason <> 'INCOMPLETE_INGEST_REQUIRES_REVIEW'
          )
    ) THEN
        RAISE EXCEPTION
            '37: modern incomplete ingest is not BLOCKed from automatic pruning';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        WHERE p.retention_disposition NOT IN ('KEEP', 'PRUNE', 'BLOCK')
           OR p.retention_reason IS NULL
           OR p.total_snapshot_rows < 0
    ) THEN
        RAISE EXCEPTION '37: retention plan contains invalid output';
    END IF;
END;
$validation$;

SELECT
    p.import_run_id,
    p.run_ts,
    p.completed_recency_rank,
    p.lor_reconciliation_run_id,
    p.reconciliation_status,
    p.retention_disposition,
    p.retention_reason,
    p.total_snapshot_rows
FROM ops.f_lor_snapshot_retention_plan(5) AS p
ORDER BY p.import_run_id DESC;

SELECT 'LOR_SNAPSHOT_RETENTION_VALIDATION_PASS'::text AS result;
