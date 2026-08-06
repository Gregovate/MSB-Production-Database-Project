/* ============================================================================
Object group: Snapshot reconciliation ownership
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
Filename:     0030_enforce_one_reconciliation_per_snapshot.sql
Revision:     2026-08-06-one-reconciliation-per-snapshot-v1

Purpose:
  Restore the permanent one-to-one relationship between a committed LOR
  snapshot and its reconciliation run. Also prevent a second unfinished run
  from starting while the operator must continue the existing run.

Safety boundary:
  - Does not call P1, P2, P3, or P4.
  - Does not change ref data or delete lor_snap data.
  - Removes only the verified, uncommitted Run 2 attempt for snapshot 44.
  - Stops unless Run 2 and Run 3 exactly match the validated cleanup facts.
  - Stops with a descriptive error if any other existing data violates either rule.

Revision history:
  2026-08-06  GAL / OpenAI  V1 snapshot-ownership enforcement, including
                           guarded cleanup of obsolete uncommitted Run 2.
============================================================================ */

BEGIN;

DO $cleanup$
DECLARE
    v_run_2_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id = 2
    ) INTO v_run_2_exists;

    /*
      Run 2 is the sole obsolete duplicate attempt. It froze snapshot 44 but
      recorded no action and no committed result. Run 3 is the completed,
      validated, reported reconciliation for the same snapshot. Refuse the
      cleanup if any of those independently validated facts has changed.
    */
    IF v_run_2_exists THEN
        IF NOT EXISTS (
            SELECT 1
            FROM ops.lor_reconciliation_run AS r2
            JOIN ops.lor_reconciliation_run AS r3
              ON r3.lor_reconciliation_run_id = 3
             AND r3.import_run_id = 44
             AND r3.status = 'COMPLETED'
             AND r3.validation_state = 'PASSED'
             AND r3.report_published_at IS NOT NULL
            WHERE r2.lor_reconciliation_run_id = 2
              AND r2.import_run_id = 44
              AND r2.status = 'SUPERSEDED'
              AND r2.validation_state = 'NOT_RUN'
              AND r2.superseded_by_run_id = 3
              AND r2.completed_at IS NULL
              AND r2.cancelled_at IS NULL
              AND r2.failed_at IS NULL
        ) THEN
            RAISE EXCEPTION
                'Run 2 cleanup refused: Run 2 -> Run 3 lifecycle facts do not match the validated snapshot-44 history';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM ops.lor_reconciliation_action
            WHERE lor_reconciliation_run_id = 2
        ) THEN
            RAISE EXCEPTION
                'Run 2 cleanup refused: operator action rows exist';
        END IF;

        IF (SELECT count(*) FROM ops.lor_reconciliation_result
            WHERE lor_reconciliation_run_id = 2) <> 5
           OR EXISTS (
               SELECT 1
               FROM ops.lor_reconciliation_result
               WHERE lor_reconciliation_run_id = 2
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
                'Run 2 cleanup refused: expected exactly five uncommitted supersession/unresolved results';
        END IF;

        /* Immutable audit triggers normally prohibit deletion. Disable only
           the named triggers, delete this one proven-uncommitted attempt in
           foreign-key order, and immediately restore the triggers. */
        ALTER TABLE ops.lor_reconciliation_result
            DISABLE TRIGGER trg_lor_reconciliation_result_immutable;
        ALTER TABLE ops.lor_reconciliation_scene_display_candidate
            DISABLE TRIGGER trg_lor_reconciliation_scene_display_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_scene_candidate
            DISABLE TRIGGER trg_lor_reconciliation_scene_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_stage_candidate
            DISABLE TRIGGER trg_lor_reconciliation_stage_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_display_candidate
            DISABLE TRIGGER trg_lor_reconciliation_display_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_group
            DISABLE TRIGGER trg_lor_reconciliation_group_immutable;

        DELETE FROM ops.lor_reconciliation_action_assignment
        WHERE lor_reconciliation_action_id IN (
            SELECT lor_reconciliation_action_id
            FROM ops.lor_reconciliation_action
            WHERE lor_reconciliation_run_id = 2
        );
        DELETE FROM ops.lor_reconciliation_action
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_scene_display_candidate
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_scene_candidate
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_stage_candidate
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_display_candidate
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_result
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_source_scene
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_source_preview
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_source_run
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_group
        WHERE lor_reconciliation_run_id = 2;
        DELETE FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id = 2;

        ALTER TABLE ops.lor_reconciliation_result
            ENABLE TRIGGER trg_lor_reconciliation_result_immutable;
        ALTER TABLE ops.lor_reconciliation_scene_display_candidate
            ENABLE TRIGGER trg_lor_reconciliation_scene_display_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_scene_candidate
            ENABLE TRIGGER trg_lor_reconciliation_scene_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_stage_candidate
            ENABLE TRIGGER trg_lor_reconciliation_stage_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_display_candidate
            ENABLE TRIGGER trg_lor_reconciliation_display_candidate_immutable;
        ALTER TABLE ops.lor_reconciliation_group
            ENABLE TRIGGER trg_lor_reconciliation_group_immutable;
    END IF;

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
$cleanup$;

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
'Only one unfinished reconciliation run may exist; it must be continued or cancelled before another snapshot can start.';

COMMENT ON SCHEMA ops IS
'Operational workflow and audit objects. Reconciliation engine revision 2026-08-06-one-reconciliation-per-snapshot-v1 installed.';

COMMIT;

SELECT
    to_regclass('ops.ux_lor_reconciliation_one_unfinished_run') IS NOT NULL
        AS has_one_unfinished_run_guard,
    EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        WHERE c.conrelid = 'ops.lor_reconciliation_run'::regclass
          AND c.conname = 'ux_lor_reconciliation_run_import'
    ) AS has_one_run_per_snapshot_guard;
