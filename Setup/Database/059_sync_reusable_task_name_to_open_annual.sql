/* ============================================================================
Setup #122 — keep reusable task names synchronized during an open annual season
Revision: 2026-09-25

Purpose:
  - ref.setup_task.task_name is the canonical current name for reusable work;
  - while an annual Setup Session is PLANNING or ACTIVE, the linked reusable
    annual occurrence must carry the same name;
  - completed/historical annual evidence must not be renamed retroactively;
  - repair any existing live open-session name drift before installing the
    durable synchronization trigger.

This migration does not alter task identity, scope, planning order, execution
history, material relationships, or season-only task names.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup #122 reusable-name synchronization prerequisites are incomplete';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_session_task'
          AND column_name = 'annual_task_name'
    ) THEN
        RAISE EXCEPTION 'ops.setup_session_task.annual_task_name is missing';
    END IF;
END
$preflight$;

/* Repair current drift only for live annual planning/execution Sessions.
   HISTORICAL_VERIFICATION and COMPLETE rows remain historical evidence. */
UPDATE ops.setup_session_task st
   SET annual_task_name = t.task_name
FROM ops.setup_session ss,
     ref.setup_task t
WHERE ss.setup_session_id = st.setup_session_id
  AND t.setup_task_id = st.setup_task_id
  AND st.task_origin = 'REUSABLE'
  AND ss.session_status IN ('PLANNING', 'ACTIVE')
  AND st.annual_task_name IS DISTINCT FROM t.task_name;

CREATE OR REPLACE FUNCTION ref.sync_setup_task_name_to_open_annual_sessions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref, ops
AS $function$
BEGIN
    UPDATE ops.setup_session_task st
       SET annual_task_name = NEW.task_name
    FROM ops.setup_session ss
    WHERE ss.setup_session_id = st.setup_session_id
      AND st.task_origin = 'REUSABLE'
      AND st.setup_task_id = NEW.setup_task_id
      AND ss.session_status IN ('PLANNING', 'ACTIVE')
      AND st.annual_task_name IS DISTINCT FROM NEW.task_name;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION ref.sync_setup_task_name_to_open_annual_sessions() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_setup_task_sync_open_annual_name
    ON ref.setup_task;

CREATE TRIGGER trg_setup_task_sync_open_annual_name
AFTER UPDATE OF task_name ON ref.setup_task
FOR EACH ROW
WHEN (OLD.task_name IS DISTINCT FROM NEW.task_name)
EXECUTE FUNCTION ref.sync_setup_task_name_to_open_annual_sessions();

DO $validation$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        JOIN ref.setup_task t
          ON t.setup_task_id = st.setup_task_id
        WHERE st.task_origin = 'REUSABLE'
          AND ss.session_status IN ('PLANNING', 'ACTIVE')
          AND st.annual_task_name IS DISTINCT FROM t.task_name
    ) THEN
        RAISE EXCEPTION 'Open annual Setup Session still contains reusable task-name drift';
    END IF;
END
$validation$;

COMMIT;

SELECT
    to_regprocedure('ref.sync_setup_task_name_to_open_annual_sessions()') IS NOT NULL
        AS reusable_name_sync_function_ready,
    EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'ref.setup_task'::regclass
          AND tgname = 'trg_setup_task_sync_open_annual_name'
          AND NOT tgisinternal
    ) AS reusable_name_sync_trigger_ready;
