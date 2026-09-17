/* ============================================================================
Object group: Bounded LOR snapshot retention
Repository:   LOR2DB/02_Reconciliation/reconciliation/migrations/
Filename:     0042_decouple_snapshot_provenance_and_add_retention.sql
Issue:        #186
Revision:     2026-09-16-lor-snapshot-retention-v1

Purpose:
  Restore lor_snap as bounded, disposable operational snapshot storage.

  This migration:
  - preserves source_import_run_id/import_run_id values as provenance;
  - removes only the hard foreign keys that make permanent/current-state or
    legacy audit rows retain the complete raw snapshot forever;
  - preserves all internal lor_snap ownership foreign keys;
  - adds a read-only retention-plan function;
  - adds a fail-closed administrative prune procedure.

Safety boundary:
  - Installation DOES NOT delete any lor_snap snapshot.
  - Installation DOES NOT rewrite ref.lor_scene or ref.lor_scene_display rows.
  - Installation DOES NOT rewrite reconciliation history.
  - A newer ingest ID alone remains non-material production change evidence.
  - Actual pruning requires a separate explicit CALL with the exact candidate
    ID set returned by the retention plan at execution time.

Retention default:
  - keep the newest 5 completed ingests;
  - keep any ingest captured by a non-terminal reconciliation;
  - prune recognized legacy snapshots created before completion tracking;
  - block any other incomplete ingest row from automatic pruning;
  - prune other eligible snapshots only through the governed procedure.
============================================================================ */

BEGIN;

/* --------------------------------------------------------------------------
   1. Fail closed unless the three known provenance-retention foreign keys
      still point exactly where current Production reconnaissance proved.
   -------------------------------------------------------------------------- */
DO $migration$
DECLARE
    v_target oid;
BEGIN
    SELECT c.confrelid
      INTO v_target
    FROM pg_constraint AS c
    WHERE c.conrelid = 'ref.lor_scene'::regclass
      AND c.conname = 'fk_lor_scene_import_run'
      AND c.contype = 'f';

    IF v_target IS DISTINCT FROM 'lor_snap.import_run'::regclass::oid THEN
        RAISE EXCEPTION
            '0042: expected ref.lor_scene.fk_lor_scene_import_run -> lor_snap.import_run was not found';
    END IF;

    SELECT c.confrelid
      INTO v_target
    FROM pg_constraint AS c
    WHERE c.conrelid = 'ref.lor_scene_display'::regclass
      AND c.conname = 'fk_lor_scene_display_import_run'
      AND c.contype = 'f';

    IF v_target IS DISTINCT FROM 'lor_snap.import_run'::regclass::oid THEN
        RAISE EXCEPTION
            '0042: expected ref.lor_scene_display.fk_lor_scene_display_import_run -> lor_snap.import_run was not found';
    END IF;

    IF to_regclass('ops.lor_reconciliation_action_legacy') IS NOT NULL THEN
        SELECT c.confrelid
          INTO v_target
        FROM pg_constraint AS c
        WHERE c.conrelid = 'ops.lor_reconciliation_action_legacy'::regclass
          AND c.conname = 'fk_lor_reconciliation_action_run'
          AND c.contype = 'f';

        IF v_target IS DISTINCT FROM 'lor_snap.import_run'::regclass::oid THEN
            RAISE EXCEPTION
                '0042: expected legacy reconciliation action FK -> lor_snap.import_run was not found';
        END IF;
    END IF;
END;
$migration$;

/* --------------------------------------------------------------------------
   2. Decouple durable provenance identifiers from disposable raw storage.
      The values remain intact. Only the retention-locking FKs are removed.
   -------------------------------------------------------------------------- */
ALTER TABLE ref.lor_scene
    DROP CONSTRAINT fk_lor_scene_import_run;

ALTER TABLE ref.lor_scene_display
    DROP CONSTRAINT fk_lor_scene_display_import_run;

DO $migration$
BEGIN
    IF to_regclass('ops.lor_reconciliation_action_legacy') IS NOT NULL THEN
        ALTER TABLE ops.lor_reconciliation_action_legacy
            DROP CONSTRAINT fk_lor_reconciliation_action_run;
    END IF;
END;
$migration$;

COMMENT ON COLUMN ref.lor_scene.source_import_run_id IS
'Logical provenance: ingest that last materially established this current Scene row. The referenced raw lor_snap snapshot may later be pruned under the governed retention policy.';

COMMENT ON COLUMN ref.lor_scene_display.source_import_run_id IS
'Logical provenance: ingest that last materially established this current Scene/Display membership. The referenced raw lor_snap snapshot may later be pruned under the governed retention policy.';

DO $migration$
BEGIN
    IF to_regclass('ops.lor_reconciliation_action_legacy') IS NOT NULL THEN
        COMMENT ON COLUMN ops.lor_reconciliation_action_legacy.import_run_id IS
        'Historical ingest identifier retained as legacy audit provenance. The raw lor_snap snapshot is not required to remain present.';
    END IF;
END;
$migration$;

/* --------------------------------------------------------------------------
   3. Read-only retention plan.

      Dispositions:
        KEEP  - protected by current retention policy.
        PRUNE - eligible for governed deletion.
        BLOCK - not automatically pruneable; operator review required.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.f_lor_snapshot_retention_plan(
    p_keep_completed integer DEFAULT 5
)
RETURNS TABLE (
    import_run_id bigint,
    run_ts timestamptz,
    ingest_completed_at timestamptz,
    completed_recency_rank bigint,
    lor_reconciliation_run_id bigint,
    reconciliation_status text,
    retention_disposition text,
    retention_reason text,
    preview_rows bigint,
    scene_rows bigint,
    prop_rows bigint,
    sub_prop_rows bigint,
    dmx_channel_rows bigint,
    scene_lor_prop_rows bigint,
    total_snapshot_rows bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap
AS $function$
BEGIN
    IF p_keep_completed IS NULL OR p_keep_completed < 1 OR p_keep_completed > 1000 THEN
        RAISE EXCEPTION
            'p_keep_completed must be between 1 and 1000; received %',
            p_keep_completed;
    END IF;

    RETURN QUERY
    WITH ranked_completed AS (
        SELECT
            ir.import_run_id,
            row_number() OVER (ORDER BY ir.import_run_id DESC)::bigint
                AS recency_rank
        FROM lor_snap.import_run AS ir
        WHERE ir.ingest_completed_at IS NOT NULL
    ),
    preview_counts AS (
        SELECT p.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.previews AS p
        GROUP BY p.import_run_id
    ),
    scene_counts AS (
        SELECT s.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.scenes AS s
        GROUP BY s.import_run_id
    ),
    prop_counts AS (
        SELECT p.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.props AS p
        GROUP BY p.import_run_id
    ),
    sub_prop_counts AS (
        SELECT sp.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.sub_props AS sp
        GROUP BY sp.import_run_id
    ),
    dmx_counts AS (
        SELECT d.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.dmx_channels AS d
        GROUP BY d.import_run_id
    ),
    scene_prop_counts AS (
        SELECT slp.import_run_id, count(*)::bigint AS row_count
        FROM lor_snap.scene_lor_props AS slp
        GROUP BY slp.import_run_id
    )
    SELECT
        ir.import_run_id,
        ir.run_ts,
        ir.ingest_completed_at,
        rc.recency_rank,
        rr.lor_reconciliation_run_id,
        rr.status,
        CASE
            WHEN rr.status IN (
                'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
                'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
            ) THEN 'KEEP'
            WHEN ir.ingest_completed_at IS NOT NULL
             AND rc.recency_rank <= p_keep_completed THEN 'KEEP'
            WHEN ir.ingest_completed_at IS NULL
             AND ir.parser_version IS NULL
             AND ir.ingest_script_version IS NULL
             AND ir.ingest_started_at IS NULL
             AND ir.preview_count IS NULL
             AND ir.scene_count IS NULL
             AND ir.prop_count IS NULL
             AND ir.sub_prop_count IS NULL
             AND ir.dmx_channel_count IS NULL
             AND ir.scene_lor_prop_count IS NULL THEN 'PRUNE'
            WHEN ir.ingest_completed_at IS NULL THEN 'BLOCK'
            ELSE 'PRUNE'
        END AS retention_disposition,
        CASE
            WHEN rr.status IN (
                'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
                'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
            ) THEN 'NON_TERMINAL_RECONCILIATION'
            WHEN ir.ingest_completed_at IS NOT NULL
             AND rc.recency_rank <= p_keep_completed
                THEN 'NEWEST_COMPLETED_WORKING_SET'
            WHEN ir.ingest_completed_at IS NULL
             AND ir.parser_version IS NULL
             AND ir.ingest_script_version IS NULL
             AND ir.ingest_started_at IS NULL
             AND ir.preview_count IS NULL
             AND ir.scene_count IS NULL
             AND ir.prop_count IS NULL
             AND ir.sub_prop_count IS NULL
             AND ir.dmx_channel_count IS NULL
             AND ir.scene_lor_prop_count IS NULL
                THEN 'LEGACY_PRE_COMPLETION_TRACKING_SNAPSHOT'
            WHEN ir.ingest_completed_at IS NULL
                THEN 'INCOMPLETE_INGEST_REQUIRES_REVIEW'
            ELSE 'OLDER_COMPLETED_SNAPSHOT'
        END AS retention_reason,
        coalesce(pc.row_count, 0)::bigint,
        coalesce(sc.row_count, 0)::bigint,
        coalesce(prc.row_count, 0)::bigint,
        coalesce(spc.row_count, 0)::bigint,
        coalesce(dc.row_count, 0)::bigint,
        coalesce(slpc.row_count, 0)::bigint,
        (
            coalesce(pc.row_count, 0)
          + coalesce(sc.row_count, 0)
          + coalesce(prc.row_count, 0)
          + coalesce(spc.row_count, 0)
          + coalesce(dc.row_count, 0)
          + coalesce(slpc.row_count, 0)
        )::bigint AS total_snapshot_rows
    FROM lor_snap.import_run AS ir
    LEFT JOIN ranked_completed AS rc
      ON rc.import_run_id = ir.import_run_id
    LEFT JOIN ops.lor_reconciliation_run AS rr
      ON rr.import_run_id = ir.import_run_id
    LEFT JOIN preview_counts AS pc
      ON pc.import_run_id = ir.import_run_id
    LEFT JOIN scene_counts AS sc
      ON sc.import_run_id = ir.import_run_id
    LEFT JOIN prop_counts AS prc
      ON prc.import_run_id = ir.import_run_id
    LEFT JOIN sub_prop_counts AS spc
      ON spc.import_run_id = ir.import_run_id
    LEFT JOIN dmx_counts AS dc
      ON dc.import_run_id = ir.import_run_id
    LEFT JOIN scene_prop_counts AS slpc
      ON slpc.import_run_id = ir.import_run_id
    ORDER BY ir.import_run_id DESC;
END;
$function$;

COMMENT ON FUNCTION ops.f_lor_snapshot_retention_plan(integer) IS
'Read-only bounded-retention plan for lor_snap. Default keeps newest 5 completed snapshots plus any snapshot captured by a non-terminal reconciliation; recognized pre-completion-tracking legacy snapshots are pruneable while other incomplete ingests are BLOCKed.';

/* --------------------------------------------------------------------------
   4. Governed pruning procedure.

      Fail-closed controls:
      - caller must supply the exact PRUNE ID set from a reviewed dry run;
      - plan is recomputed under an advisory transaction lock;
      - unexpected future FKs to lor_snap.import_run abort before deletion;
      - non-cascading snapshot children are deleted explicitly first;
      - latest completed import_run_id must not change;
      - no PRUNE candidate may remain after a successful call.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE ops.p_prune_lor_snapshots(
    p_expected_prune_ids bigint[],
    p_keep_completed integer DEFAULT 5
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap
AS $procedure$
DECLARE
    v_actual_prune_ids bigint[];
    v_expected_prune_ids bigint[];
    v_expected_count integer;
    v_expected_distinct_count integer;
    v_unexpected_fk text;
    v_latest_completed_before bigint;
    v_latest_completed_after bigint;
    v_scene_prop_deleted bigint := 0;
    v_scene_deleted bigint := 0;
    v_import_deleted bigint := 0;
BEGIN
    IF p_expected_prune_ids IS NULL THEN
        RAISE EXCEPTION
            'Expected prune IDs are required. Run ops.f_lor_snapshot_retention_plan(%) first.',
            p_keep_completed;
    END IF;

    IF EXISTS (
        SELECT 1 FROM unnest(p_expected_prune_ids) AS x(import_run_id)
        WHERE x.import_run_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Expected prune ID array may not contain NULL';
    END IF;

    SELECT count(*), count(DISTINCT x.import_run_id),
           coalesce(array_agg(x.import_run_id ORDER BY x.import_run_id), ARRAY[]::bigint[])
      INTO v_expected_count, v_expected_distinct_count, v_expected_prune_ids
    FROM unnest(p_expected_prune_ids) AS x(import_run_id);

    IF v_expected_count <> v_expected_distinct_count THEN
        RAISE EXCEPTION 'Expected prune ID array contains duplicates';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_snap.retention'));

    SELECT max(ir.import_run_id)
      INTO v_latest_completed_before
    FROM lor_snap.import_run AS ir
    WHERE ir.ingest_completed_at IS NOT NULL;

    DROP TABLE IF EXISTS pg_temp._lor_snapshot_prune_ids;
    CREATE TEMP TABLE pg_temp._lor_snapshot_prune_ids (
        import_run_id bigint PRIMARY KEY
    ) ON COMMIT DROP;

    INSERT INTO pg_temp._lor_snapshot_prune_ids (import_run_id)
    SELECT p.import_run_id
    FROM ops.f_lor_snapshot_retention_plan(p_keep_completed) AS p
    WHERE p.retention_disposition = 'PRUNE';

    SELECT coalesce(array_agg(p.import_run_id ORDER BY p.import_run_id), ARRAY[]::bigint[])
      INTO v_actual_prune_ids
    FROM pg_temp._lor_snapshot_prune_ids AS p;

    IF v_actual_prune_ids IS DISTINCT FROM v_expected_prune_ids THEN
        RAISE EXCEPTION
            'Retention plan changed since dry run. Expected prune IDs %, current prune IDs %. Re-run the dry run; nothing was deleted.',
            v_expected_prune_ids, v_actual_prune_ids;
    END IF;

    /* Internal snapshot ownership FKs are expected. Any other FK is a new
       retention dependency and must be reviewed before deletion proceeds. */
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
            'Unexpected foreign key(s) still reference lor_snap.import_run: %. Nothing was deleted.',
            v_unexpected_fk;
    END IF;

    IF cardinality(v_actual_prune_ids) = 0 THEN
        RAISE NOTICE 'No lor_snap snapshots are eligible for pruning.';
        RETURN;
    END IF;

    DELETE FROM lor_snap.scene_lor_props AS slp
    USING pg_temp._lor_snapshot_prune_ids AS p
    WHERE slp.import_run_id = p.import_run_id;
    GET DIAGNOSTICS v_scene_prop_deleted = ROW_COUNT;

    DELETE FROM lor_snap.scenes AS s
    USING pg_temp._lor_snapshot_prune_ids AS p
    WHERE s.import_run_id = p.import_run_id;
    GET DIAGNOSTICS v_scene_deleted = ROW_COUNT;

    /* previews, props, sub_props, and dmx_channels are owned by import_run with
       ON DELETE CASCADE in the live contract. */
    DELETE FROM lor_snap.import_run AS ir
    USING pg_temp._lor_snapshot_prune_ids AS p
    WHERE ir.import_run_id = p.import_run_id;
    GET DIAGNOSTICS v_import_deleted = ROW_COUNT;

    IF v_import_deleted <> cardinality(v_actual_prune_ids) THEN
        RAISE EXCEPTION
            'Prune deleted % import_run rows but expected %. Transaction will roll back.',
            v_import_deleted, cardinality(v_actual_prune_ids);
    END IF;

    SELECT max(ir.import_run_id)
      INTO v_latest_completed_after
    FROM lor_snap.import_run AS ir
    WHERE ir.ingest_completed_at IS NOT NULL;

    IF v_latest_completed_after IS DISTINCT FROM v_latest_completed_before THEN
        RAISE EXCEPTION
            'Latest completed import changed from % to %. Transaction will roll back.',
            v_latest_completed_before, v_latest_completed_after;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(p_keep_completed) AS p
        WHERE p.retention_disposition = 'PRUNE'
    ) THEN
        RAISE EXCEPTION
            'Eligible PRUNE snapshots remain after deletion. Transaction will roll back.';
    END IF;

    RAISE NOTICE
        'LOR snapshot prune complete: import_runs %, scene_lor_props %, scenes %, latest completed import % preserved.',
        v_import_deleted, v_scene_prop_deleted, v_scene_deleted,
        v_latest_completed_after;
END;
$procedure$;

COMMENT ON PROCEDURE ops.p_prune_lor_snapshots(bigint[], integer) IS
'Administrative fail-closed lor_snap pruning. Requires exact reviewed PRUNE ID set from ops.f_lor_snapshot_retention_plan; installation of migration 0042 never calls this procedure.';

/* --------------------------------------------------------------------------
   5. Automatic steady-state retention entry point.

      This entry point is intentionally parameterless:
      - normal application cleanup always keeps exactly 5 completed snapshots;
      - callers cannot supply IDs or lower the retention count;
      - the governed administrative procedure remains the manual recovery path;
      - any failure rolls back this cleanup transaction without affecting the
        already-completed reconciliation/report transaction.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE ops.p_run_lor_snapshot_retention()
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap
AS $procedure$
DECLARE
    v_expected_prune_ids bigint[];
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_snap.retention'));

    IF EXISTS (
        SELECT 1
        FROM ops.f_lor_snapshot_retention_plan(5) AS p
        WHERE p.retention_disposition = 'BLOCK'
    ) THEN
        RAISE EXCEPTION
            'Automatic LOR snapshot retention found BLOCKed snapshot(s). No automatic pruning was performed; review the retention plan.';
    END IF;

    SELECT coalesce(
               array_agg(p.import_run_id ORDER BY p.import_run_id),
               ARRAY[]::bigint[]
           )
      INTO v_expected_prune_ids
    FROM ops.f_lor_snapshot_retention_plan(5) AS p
    WHERE p.retention_disposition = 'PRUNE';

    CALL ops.p_prune_lor_snapshots(v_expected_prune_ids, 5);
END;
$procedure$;

COMMENT ON PROCEDURE ops.p_run_lor_snapshot_retention() IS
'Automatic fail-closed steady-state lor_snap retention. Uses the fixed newest-5 policy and the same guarded administrative prune procedure; intended only after successful reconciliation report publication.';

ALTER FUNCTION ops.f_lor_snapshot_retention_plan(integer) OWNER TO msbadmin;
ALTER PROCEDURE ops.p_prune_lor_snapshots(bigint[], integer) OWNER TO msbadmin;
ALTER PROCEDURE ops.p_run_lor_snapshot_retention() OWNER TO msbadmin;

REVOKE ALL ON FUNCTION ops.f_lor_snapshot_retention_plan(integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE ops.p_prune_lor_snapshots(bigint[], integer) FROM PUBLIC;
REVOKE ALL ON PROCEDURE ops.p_run_lor_snapshot_retention() FROM PUBLIC;

COMMIT;

SELECT
    to_regprocedure('ops.f_lor_snapshot_retention_plan(integer)') IS NOT NULL
        AS has_retention_plan,
    to_regprocedure('ops.p_prune_lor_snapshots(bigint[],integer)') IS NOT NULL
        AS has_prune_procedure,
    to_regprocedure('ops.p_run_lor_snapshot_retention()') IS NOT NULL
        AS has_automatic_retention_procedure;
