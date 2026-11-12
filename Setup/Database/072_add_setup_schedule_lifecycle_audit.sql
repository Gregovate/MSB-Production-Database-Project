-- #205 / #122: durable annual-task schedule lifecycle evidence.
-- Additive only. No backfill: earlier deleted assignments cannot be reconstructed.
-- Existing ASSIGNMENT_MOVED events remain authoritative for movement history.
BEGIN;

ALTER TABLE ops.setup_schedule_event
  DROP CONSTRAINT IF EXISTS ck_setup_schedule_event_type;
ALTER TABLE ops.setup_schedule_event
  ADD CONSTRAINT ck_setup_schedule_event_type CHECK (
    event_type IN (
      'ASSIGNMENT_MOVED',
      'ASSIGNMENT_CREATED',
      'ASSIGNMENT_REMOVED',
      'WORK_DAY_DELETED',
      'HISTORICAL_WORK_DAY_ADDED'
    )
  );

CREATE INDEX IF NOT EXISTS ix_setup_schedule_event_annual_task
  ON ops.setup_schedule_event(setup_session_task_id, occurred_at, setup_schedule_event_id)
  WHERE setup_session_task_id IS NOT NULL;

-- SECURITY DEFINER is necessary because fieldwiring_app has no direct INSERT
-- privilege on the append-only schedule audit. The existing actor trigger
-- resolves app.directus_user_uuid established by governed commands.
CREATE OR REPLACE FUNCTION ops.audit_setup_assignment_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
  v_work_day_id bigint;
  v_task_id bigint;
  v_shift text;
  v_crew text;
  v_session_id bigint;
  v_work_date date;
  v_day_number integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_work_day_id := NEW.setup_work_day_id;
    v_task_id := NEW.setup_session_task_id;
    v_shift := NEW.shift_code;
    v_crew := NEW.crew_lane;
  ELSE
    v_work_day_id := OLD.setup_work_day_id;
    v_task_id := OLD.setup_session_task_id;
    v_shift := OLD.shift_code;
    v_crew := OLD.crew_lane;
  END IF;

  SELECT wd.setup_session_id, wd.work_date, wd.setup_day_number
    INTO v_session_id, v_work_date, v_day_number
  FROM ops.setup_work_day wd
  WHERE wd.setup_work_day_id = v_work_day_id;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'Cannot audit assignment without retained Setup workday %', v_work_day_id;
  END IF;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO ops.setup_schedule_event(
      setup_session_id, event_type, setup_work_day_task_id, setup_session_task_id,
      to_work_day_id, to_work_date, to_setup_day_number, to_shift_code, to_crew_code
    ) VALUES (
      v_session_id, 'ASSIGNMENT_CREATED', NEW.setup_work_day_task_id, v_task_id,
      v_work_day_id, v_work_date, v_day_number, v_shift, v_crew
    );
    RETURN NEW;
  END IF;

  INSERT INTO ops.setup_schedule_event(
    setup_session_id, event_type, setup_work_day_task_id, setup_session_task_id,
    from_work_day_id, from_work_date, from_setup_day_number, from_shift_code, from_crew_code
  ) VALUES (
    v_session_id, 'ASSIGNMENT_REMOVED', OLD.setup_work_day_task_id, v_task_id,
    v_work_day_id, v_work_date, v_day_number, v_shift, v_crew
  );
  RETURN OLD;
END;
$function$;

REVOKE ALL ON FUNCTION ops.audit_setup_assignment_lifecycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.audit_setup_assignment_lifecycle() FROM fieldwiring_app;

DROP TRIGGER IF EXISTS trg_setup_assignment_lifecycle_insert ON ops.setup_work_day_task;
CREATE TRIGGER trg_setup_assignment_lifecycle_insert
AFTER INSERT ON ops.setup_work_day_task
FOR EACH ROW EXECUTE FUNCTION ops.audit_setup_assignment_lifecycle();

DROP TRIGGER IF EXISTS trg_setup_assignment_lifecycle_delete ON ops.setup_work_day_task;
CREATE TRIGGER trg_setup_assignment_lifecycle_delete
BEFORE DELETE ON ops.setup_work_day_task
FOR EACH ROW EXECUTE FUNCTION ops.audit_setup_assignment_lifecycle();

CREATE OR REPLACE VIEW ops.preview_setup_schedule_churn_v1 AS
WITH event_counts AS (
  SELECT
    setup_session_id,
    setup_session_task_id,
    count(*) FILTER (WHERE event_type = 'ASSIGNMENT_CREATED') AS times_scheduled_observed,
    count(*) FILTER (WHERE event_type = 'ASSIGNMENT_REMOVED') AS removals_observed,
    count(*) FILTER (
      WHERE event_type = 'ASSIGNMENT_MOVED'
        AND from_work_date IS DISTINCT FROM to_work_date
    ) AS date_moves_observed,
    count(*) FILTER (
      WHERE event_type = 'ASSIGNMENT_MOVED'
        AND from_work_date IS NOT DISTINCT FROM to_work_date
        AND (from_shift_code IS DISTINCT FROM to_shift_code
          OR from_crew_code IS DISTINCT FROM to_crew_code)
    ) AS same_day_reassignments_observed,
    min(occurred_at) AS earliest_audit_event,
    max(occurred_at) AS latest_audit_event
  FROM ops.setup_schedule_event
  WHERE setup_session_task_id IS NOT NULL
  GROUP BY setup_session_id, setup_session_task_id
)
SELECT
  setup_session_id,
  setup_session_task_id,
  times_scheduled_observed,
  removals_observed,
  date_moves_observed,
  same_day_reassignments_observed,
  (date_moves_observed + same_day_reassignments_observed + removals_observed
    + greatest(times_scheduled_observed - 1, 0)) AS lifecycle_change_events_observed,
  earliest_audit_event,
  latest_audit_event
FROM event_counts;

REVOKE ALL ON ops.preview_setup_schedule_churn_v1 FROM PUBLIC;
-- Read-only reporting privilege must be granted through the governed
-- deployment's least-privilege review; no broad grants in this migration.
COMMIT;
