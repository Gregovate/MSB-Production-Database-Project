/* ============================================================================
Object group: Snapshot reconciliation ownership
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
Filename:     0030_enforce_one_reconciliation_per_snapshot.sql
Revision:     2026-08-06-one-reconciliation-per-snapshot-v4

Purpose:
  Restore the permanent one-to-one relationship between a committed LOR
  snapshot and its reconciliation run. Every unfinished lifecycle state must
  continue the existing run; Start must never supersede it or create a second
  run for the same snapshot.

Safety boundary:
  - Does not call P1, P2, P3, or P4.
  - Does not change ref data or delete lor_snap data.
  - Removes only verified pre-production Runs 1 and 2 and their audit/working
    rows. Runs 3, 4, 5, and every later run are outside the cleanup boundary.
  - Stops unless Runs 1 and 2 exactly match the validated development facts.
  - Stops with a descriptive error if remaining data violates either rule.

Revision history:
  2026-08-06  GAL / OpenAI  V4 removes verified pre-production Runs 1 and 2,
                           keeps the cleanup separate from the permanent rule,
                           and makes Start return the existing run for every
                           unfinished lifecycle state.
  2026-08-06  GAL / OpenAI  V3 attempted guarded Run 2 cleanup and trigger
                           handling but did not cover Run 1's audit reference.
  2026-08-06  GAL / OpenAI  V2 added frozen-source trigger handling.
  2026-08-06  GAL / OpenAI  V1 snapshot-ownership enforcement.
============================================================================ */

BEGIN;

/* -------------------------------------------------------------------------
   One-time pre-production cleanup.

   These exact records were created during development before the permanent
   one-snapshot/one-run contract was restored. This section is not lifecycle
   policy and cannot select or remove any later run.
   ------------------------------------------------------------------------- */
DO $preproduction_cleanup$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id IN (1, 2)
    ) THEN
        IF (SELECT count(*) FROM ops.lor_reconciliation_run
            WHERE lor_reconciliation_run_id IN (1, 2)) <> 2
           OR NOT EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_run AS r1
               WHERE r1.lor_reconciliation_run_id = 1
                 AND r1.import_run_id = 43
                 AND r1.status = 'SUPERSEDED'
                 AND r1.validation_state = 'NOT_RUN'
                 AND r1.superseded_by_run_id = 2
                 AND r1.completed_at IS NULL
                 AND r1.cancelled_at IS NULL
                 AND r1.failed_at IS NULL
           )
           OR NOT EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_run AS r2
               WHERE r2.lor_reconciliation_run_id = 2
                 AND r2.import_run_id = 44
                 AND r2.status = 'SUPERSEDED'
                 AND r2.validation_state = 'NOT_RUN'
                 AND r2.superseded_by_run_id = 3
                 AND r2.completed_at IS NULL
                 AND r2.cancelled_at IS NULL
                 AND r2.failed_at IS NULL
           )
           OR NOT EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_run AS r3
               WHERE r3.lor_reconciliation_run_id = 3
                 AND r3.import_run_id = 44
                 AND r3.status = 'COMPLETED'
                 AND r3.validation_state = 'PASSED'
                 AND r3.report_published_at IS NOT NULL
           ) THEN
            RAISE EXCEPTION
                'Pre-production cleanup refused: Runs 1, 2, and 3 do not match the validated lifecycle facts';
        END IF;

        IF (SELECT count(*) FROM ops.lor_reconciliation_action
            WHERE lor_reconciliation_run_id = 1) <> 3
           OR EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_action
               WHERE lor_reconciliation_run_id = 1
                 AND action_type <> 'PRESERVE_EXISTING_STAGE_METADATA'
           )
           OR EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_action
               WHERE lor_reconciliation_run_id = 2
           ) THEN
            RAISE EXCEPTION
                'Pre-production cleanup refused: Run 1 or Run 2 action facts changed';
        END IF;

        IF (SELECT count(*) FROM ops.lor_reconciliation_result
            WHERE lor_reconciliation_run_id = 1) <> 2
           OR (SELECT count(*) FROM ops.lor_reconciliation_result
               WHERE lor_reconciliation_run_id = 2) <> 5
           OR EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_result
               WHERE lor_reconciliation_run_id IN (1, 2)
                 AND (
                     committed IS NOT FALSE
                     OR result_class NOT IN ('SUPERSEDED', 'UNRESOLVED')
                     OR reason_code NOT IN (
                         'SUPERSEDED_BY_LATER_ATTEMPT',
                         'SUPERSEDED_WITHOUT_REQUIRED_DECISION'
                     )
                 )
           ) THEN
            RAISE EXCEPTION
                'Pre-production cleanup refused: expected seven uncommitted supersession/unresolved results';
        END IF;

        ALTER TABLE ops.lor_reconciliation_action_assignment DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_action DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_result DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_scene_display_candidate DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_scene_candidate DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_stage_candidate DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_display_candidate DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_group DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_scene DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_preview DISABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_run DISABLE TRIGGER USER;

        DELETE FROM ops.lor_reconciliation_action_assignment
        WHERE lor_reconciliation_action_id IN (
            SELECT lor_reconciliation_action_id
            FROM ops.lor_reconciliation_action
            WHERE lor_reconciliation_run_id IN (1, 2)
        );
        DELETE FROM ops.lor_reconciliation_action
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_scene_display_candidate
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_scene_candidate
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_stage_candidate
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_display_candidate
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_result
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_source_scene
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_source_preview
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_source_run
        WHERE lor_reconciliation_run_id IN (1, 2);
        DELETE FROM ops.lor_reconciliation_group
        WHERE lor_reconciliation_run_id IN (1, 2);
        /* One statement satisfies the Run 1 -> Run 2 self-reference. */
        DELETE FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id IN (1, 2);

        ALTER TABLE ops.lor_reconciliation_action_assignment ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_action ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_result ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_scene_display_candidate ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_scene_candidate ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_stage_candidate ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_display_candidate ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_group ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_scene ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_preview ENABLE TRIGGER USER;
        ALTER TABLE ops.lor_reconciliation_source_run ENABLE TRIGGER USER;
    END IF;
END;
$preproduction_cleanup$;

DO $validation$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run AS r
        GROUP BY r.import_run_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Cannot enforce one reconciliation per snapshot: duplicate import_run_id values exist';
    END IF;

    IF (
        SELECT count(*)
        FROM ops.lor_reconciliation_run AS r
        WHERE r.status IN (
            'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
            'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
        )
    ) > 1 THEN
        RAISE EXCEPTION
            'Cannot enforce continuation: more than one unfinished reconciliation run exists';
    END IF;
END;
$validation$;

DROP INDEX IF EXISTS ops.ix_lor_reconciliation_run_import;

ALTER TABLE ops.lor_reconciliation_run
    ADD CONSTRAINT ux_lor_reconciliation_run_import UNIQUE (import_run_id);

CREATE UNIQUE INDEX ux_lor_reconciliation_one_unfinished_run
    ON ops.lor_reconciliation_run ((1))
    WHERE status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING'
    );

COMMENT ON CONSTRAINT ux_lor_reconciliation_run_import
    ON ops.lor_reconciliation_run IS
'A committed LOR snapshot is permanently owned by exactly one reconciliation run, including terminal CANCELLED and FAILED runs.';

COMMENT ON INDEX ops.ux_lor_reconciliation_one_unfinished_run IS
'Only one unfinished reconciliation run may exist; every unfinished lifecycle state must continue that run before another snapshot can start.';

/*
  Replace the independent-attempt wrapper installed by 0022. The underlying
  builders remain unchanged; this wrapper returns the existing run before any
  builder can create or supersede an attempt.
*/
CREATE OR REPLACE FUNCTION ops.f_start_lor_reconciliation(
    p_started_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_run_id bigint;
    v_import_run_id bigint;
    v_existing_status text;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

    SELECT r.lor_reconciliation_run_id
      INTO v_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING'
    )
    ORDER BY r.lor_reconciliation_run_id
    LIMIT 1
    FOR UPDATE;

    IF v_run_id IS NOT NULL THEN
        UPDATE ops.lor_reconciliation_run
           SET resumed_at = now()
         WHERE lor_reconciliation_run_id = v_run_id;
        RETURN v_run_id;
    END IF;

    SELECT cr.import_run_id
      INTO v_import_run_id
    FROM lor_snap.v_current_run AS cr;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'No completed LOR snapshot is available';
    END IF;

    SELECT r.lor_reconciliation_run_id, r.status
      INTO v_run_id, v_existing_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.import_run_id = v_import_run_id
    FOR UPDATE;

    IF v_run_id IS NOT NULL THEN
        RAISE EXCEPTION
            'Snapshot % already belongs to reconciliation run % with status %; a second run is prohibited',
            v_import_run_id, v_run_id, v_existing_status;
    END IF;

    v_run_id := ops.f_start_lor_display_reconciliation(
        p_started_by_application
    );
    PERFORM ops.f_freeze_lor_reconciliation_source_evidence(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_display_candidates(v_run_id);
    RETURN v_run_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_start_lor_reconciliation(text) IS
'Returns the one existing unfinished run in any unfinished lifecycle state; otherwise creates exactly one run for the current completed snapshot and freezes/builds its evidence.';

COMMENT ON SCHEMA ops IS
'Operational workflow and audit objects. Reconciliation engine revision 2026-08-06-one-reconciliation-per-snapshot-v4 installed.';

COMMIT;

SELECT
    to_regclass('ops.ux_lor_reconciliation_one_unfinished_run') IS NOT NULL
        AS has_one_unfinished_run_guard,
    EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        WHERE c.conrelid = 'ops.lor_reconciliation_run'::regclass
          AND c.conname = 'ux_lor_reconciliation_run_import'
    ) AS has_one_run_per_snapshot_guard,
    to_regprocedure('ops.f_start_lor_reconciliation(text)') IS NOT NULL
        AS has_resume_aware_start;
