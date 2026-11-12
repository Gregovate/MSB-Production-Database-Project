/* ============================================================================
MSB Setup Session — readiness condition default-state invariant
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-23 V0.1.0

Purpose:
  Enforce the operator rule that a nonblank readiness condition always begins
  NOT_READY for the applicable annual Setup occurrence.

Contract:
  - no readiness note -> READY baseline;
  - add/change a readiness note -> NOT_READY;
  - clear a readiness note -> READY;
  - only an explicit annual readiness action may change a task with a retained
    readiness note from NOT_READY to READY;
  - reusable Catalog readiness edits synchronize only into current PLANNING /
    ACTIVE annual occurrences with no actual work; Historical Verification is
    not rewritten.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL THEN
        RAISE EXCEPTION 'Current Setup Catalog / annual planning foundation is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_session_task'
          AND column_name='annual_readiness_note'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_session_task'
          AND column_name='annual_readiness_state'
    ) THEN
        RAISE EXCEPTION 'Scheduling readiness snapshot columns are required';
    END IF;
END
$preflight$;


/* --------------------------------------------------------------------------
   ANNUAL INVARIANT

   Trigger name sorts after trg_setup_session_task_snapshot so INSERT rows have
   already inherited reusable readiness_note before this invariant is applied.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.enforce_setup_readiness_note_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
DECLARE
    v_note text := nullif(btrim(NEW.annual_readiness_note), '');
BEGIN
    IF TG_OP = 'INSERT'
       OR OLD.annual_readiness_note IS DISTINCT FROM NEW.annual_readiness_note THEN
        NEW.annual_readiness_note := v_note;
        NEW.annual_readiness_state := CASE
            WHEN v_note IS NULL THEN 'READY'
            ELSE 'NOT_READY'
        END;
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION ops.enforce_setup_readiness_note_state() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_setup_session_task_z_readiness_invariant
    ON ops.setup_session_task;
CREATE TRIGGER trg_setup_session_task_z_readiness_invariant
BEFORE INSERT OR UPDATE ON ops.setup_session_task
FOR EACH ROW EXECUTE FUNCTION ops.enforce_setup_readiness_note_state();


/* --------------------------------------------------------------------------
   REUSABLE CATALOG -> CURRENT ANNUAL PLANNING SYNC

   Catalog edits remain durable reusable knowledge. When a readiness condition
   is added/changed/cleared after a PLANNING or ACTIVE annual Session already
   exists, synchronize only untouched annual planning rows. Historical
   Verification and rows with actual work remain historical.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.sync_reusable_readiness_to_current_sessions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_new_note text := nullif(btrim(NEW.readiness_note), '');
BEGIN
    IF OLD.readiness_note IS NOT DISTINCT FROM NEW.readiness_note THEN
        RETURN NEW;
    END IF;

    UPDATE ops.setup_session_task st
       SET annual_readiness_note = v_new_note,
           annual_readiness_state = CASE
               WHEN v_new_note IS NULL THEN 'READY'
               ELSE 'NOT_READY'
           END
      FROM ops.setup_session ss
     WHERE ss.setup_session_id = st.setup_session_id
       AND ss.session_status IN ('PLANNING','ACTIVE')
       AND st.task_origin = 'REUSABLE'
       AND st.setup_task_id = NEW.setup_task_id
       AND st.actual_started_at IS NULL
       AND st.actual_completed_at IS NULL
       AND NOT EXISTS (
           SELECT 1
           FROM ops.setup_task_progress p
           WHERE p.setup_session_task_id = st.setup_session_task_id
       );

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION ops.sync_reusable_readiness_to_current_sessions() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_setup_task_readiness_sync
    ON ref.setup_task;
CREATE TRIGGER trg_setup_task_readiness_sync
AFTER UPDATE OF readiness_note ON ref.setup_task
FOR EACH ROW EXECUTE FUNCTION ops.sync_reusable_readiness_to_current_sessions();

COMMIT;

SELECT
    '2026-09-23-setup-readiness-not-ready-v0.1.0' AS applied_revision,
    current_user AS applied_by;
