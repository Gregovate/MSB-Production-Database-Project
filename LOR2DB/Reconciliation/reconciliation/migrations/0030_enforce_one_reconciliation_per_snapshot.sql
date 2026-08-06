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
  - Stops with a descriptive error if existing data violates either rule.

Revision history:
  2026-08-06  GAL / OpenAI  Initial snapshot-ownership enforcement.
============================================================================ */

BEGIN;

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
