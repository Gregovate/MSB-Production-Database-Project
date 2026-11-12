-- Setup #205: chronological Setup Day repair, historical correction, and passive schedule audit.
--
-- Durable rules:
--   * setup_day_number is a chronological display/order number, not durable identity.
--   * stable identity lives in setup_work_day_id / setup_work_day_task_id.
--   * ordinary work-day creation remains future/today only.
--   * Managers get an explicit historical-correction command for legitimate omitted past dates.
--   * empty-day deletion may carry an optional note retained outside the deleted row.
--   * assignment moves are passively audited with no operator prompt.
--
-- This migration deliberately normalizes the open annual Setup Session(s)
-- chronologically so the 2026 inflated Day-number anchor is corrected without
-- rewriting work-day, assignment, or progress identities.

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_work_day_crew') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ops.upsert_setup_work_day(text,integer,date,integer,text,text,text,text)') IS NULL
       OR to_regprocedure('ops.resequence_setup_future_work_days(bigint)') IS NULL
       OR to_regprocedure('ops.update_setup_work_day_assignment(text,bigint,bigint,text,bigint,integer)') IS NULL
       OR to_regprocedure('ops.remove_empty_setup_work_day(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Accepted #205 Scheduling Board + migration 068 are required before migration 069';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   PASSIVE SCHEDULING AUDIT — ZERO REQUIRED OPERATOR INPUT
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ops.setup_schedule_event (
    setup_schedule_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    event_type text NOT NULL,
    setup_work_day_task_id bigint,
    setup_session_task_id bigint,
    from_work_day_id bigint,
    from_work_date date,
    from_setup_day_number integer,
    from_shift_code text,
    from_crew_code text,
    to_work_day_id bigint,
    to_work_date date,
    to_setup_day_number integer,
    to_shift_code text,
    to_crew_code text,
    event_note text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_schedule_event_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_schedule_event_created_by_person
        FOREIGN KEY (created_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_schedule_event_updated_by_person
        FOREIGN KEY (updated_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_schedule_event_type CHECK (
        event_type IN (
            'ASSIGNMENT_MOVED',
            'WORK_DAY_DELETED',
            'HISTORICAL_WORK_DAY_ADDED'
        )
    )
);

DROP TRIGGER IF EXISTS trg_setup_schedule_event_actor_insert ON ops.setup_schedule_event;
CREATE TRIGGER trg_setup_schedule_event_actor_insert
BEFORE INSERT ON ops.setup_schedule_event
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_schedule_event_actor_update ON ops.setup_schedule_event;
CREATE TRIGGER trg_setup_schedule_event_actor_update
BEFORE UPDATE ON ops.setup_schedule_event
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE INDEX IF NOT EXISTS ix_setup_schedule_event_session_time
    ON ops.setup_schedule_event(setup_session_id, occurred_at, setup_schedule_event_id);

CREATE INDEX IF NOT EXISTS ix_setup_schedule_event_assignment
    ON ops.setup_schedule_event(setup_work_day_task_id, occurred_at)
    WHERE setup_work_day_task_id IS NOT NULL;

REVOKE ALL ON ops.setup_schedule_event FROM PUBLIC;
REVOKE ALL ON ops.setup_schedule_event FROM fieldwiring_app;

/* --------------------------------------------------------------------------
   SETUP DAY NUMBER = CHRONOLOGICAL POSITION OF RETAINED WORK DAYS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.resequence_setup_future_work_days(
    p_setup_session_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session ss
        WHERE ss.setup_session_id = p_setup_session_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup Session was not found';
    END IF;

    /* setup_day_number is presentation/sequence, not durable identity.
       Move every retained day out of the unique-key range first, then assign
       contiguous chronological numbers. Stable IDs and execution history are
       untouched. */
    WITH ranked AS (
        SELECT
            wd.setup_work_day_id,
            row_number() OVER (
                ORDER BY wd.work_date, wd.setup_work_day_id
            )::integer AS rn
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = p_setup_session_id
    )
    UPDATE ops.setup_work_day wd
       SET setup_day_number = 1000000 + ranked.rn
    FROM ranked
    WHERE wd.setup_work_day_id = ranked.setup_work_day_id;

    WITH ranked AS (
        SELECT
            wd.setup_work_day_id,
            row_number() OVER (
                ORDER BY wd.work_date, wd.setup_work_day_id
            )::integer AS rn
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = p_setup_session_id
    )
    UPDATE ops.setup_work_day wd
       SET setup_day_number = ranked.rn
    FROM ranked
    WHERE wd.setup_work_day_id = ranked.setup_work_day_id;
END;
$function$;

REVOKE ALL ON FUNCTION ops.resequence_setup_future_work_days(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.resequence_setup_future_work_days(bigint) FROM fieldwiring_app;

/* One-time correction of open annual sessions. Historical-verification years
   remain evidence and are not renumbered by this migration. */
DO $normalize_open_sessions$
DECLARE
    v_session_id bigint;
BEGIN
    FOR v_session_id IN
        SELECT ss.setup_session_id
        FROM ops.setup_session ss
        WHERE ss.session_status IN ('PLANNING','ACTIVE')
        ORDER BY ss.season_year, ss.setup_session_id
    LOOP
        PERFORM ops.resequence_setup_future_work_days(v_session_id);
    END LOOP;
END
$normalize_open_sessions$;

/* --------------------------------------------------------------------------
   NORMAL CALENDAR STAYS FUTURE-ONLY; MANAGER HISTORICAL CORRECTION IS EXPLICIT
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.reject_past_setup_work_day_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NEW.work_date < current_date
       AND coalesce(
           pg_catalog.current_setting('app.setup_allow_past_work_day', true),
           ''
       ) <> '1' THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup work days cannot be added in the past';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION ops.add_historical_setup_work_day(
    p_email text,
    p_season_year integer,
    p_work_date date,
    p_note text DEFAULT NULL
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_day_number integer,
    work_date date,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_session_id bigint;
    v_day_id bigint;
    v_day_number integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF p_work_date IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Historical work date is required';
    END IF;

    IF p_work_date >= current_date THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Historical correction is only for dates before today; use Add Work Days for current/future dates';
    END IF;

    IF extract(year FROM p_work_date)::integer <> p_season_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Historical work date must be in the selected Setup Session year';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup Session was not found for this season';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.work_date = p_work_date
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
            MESSAGE = 'A Setup work day already exists for this date';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    PERFORM pg_catalog.set_config('app.setup_allow_past_work_day', '1', true);

    /* Route the correction through the accepted governed work-day command so
       Crew A creation, normal validation, and future command semantics stay in
       one place. The private transaction-local setting only bypasses the
       ordinary past-date trigger for this Manager correction call. */
    SELECT u.setup_work_day_id,
           u.setup_day_number
      INTO v_day_id,
           v_day_number
    FROM ops.upsert_setup_work_day(
        p_email,
        p_season_year,
        p_work_date,
        NULL,
        'PLANNED',
        NULL,
        NULL,
        p_note
    ) u;

    INSERT INTO ops.setup_schedule_event(
        setup_session_id,
        event_type,
        to_work_day_id,
        to_work_date,
        to_setup_day_number,
        event_note
    ) VALUES (
        v_session_id,
        'HISTORICAL_WORK_DAY_ADDED',
        v_day_id,
        p_work_date,
        v_day_number,
        nullif(btrim(p_note), '')
    );

    RETURN QUERY
    SELECT v_day_id, v_day_number, p_work_date, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.add_historical_setup_work_day(text,integer,date,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.add_historical_setup_work_day(text,integer,date,text) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   EMPTY-DAY DELETION RETAINS OPTIONAL NOTE / DATE / ACTOR AS AUDIT EVIDENCE
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.remove_empty_setup_work_day(
    p_email text,
    p_setup_work_day_id bigint,
    p_note text
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_day_number integer,
    work_date date,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_session_id bigint;
    v_day_number integer;
    v_work_date date;
    v_day_status text;
    v_crew_count integer;
    v_crew_number integer;
    v_crew_code text;
    v_captain_person_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wd.setup_session_id,
           wd.setup_day_number,
           wd.work_date,
           wd.day_status
      INTO v_session_id,
           v_day_number,
           v_work_date,
           v_day_status
    FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work day was not found';
    END IF;

    IF v_day_status <> 'PLANNED' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Only an empty Planned Setup work day can be removed';
    END IF;

    SELECT count(*)::integer,
           min(c.crew_number),
           min(c.crew_code),
           min(c.captain_person_id)
      INTO v_crew_count,
           v_crew_number,
           v_crew_code,
           v_captain_person_id
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = p_setup_work_day_id;

    IF v_crew_count <> 1
       OR v_crew_number <> 1
       OR v_crew_code <> 'A' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Only a Setup work day with exactly the default Crew A can be removed';
    END IF;

    IF v_captain_person_id IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'A Setup work day with an assigned Captain cannot be removed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Move or remove scheduled tasks before deleting the Setup work day';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        WHERE p.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Reported work exists for this Setup work day; preserve it as history';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_schedule_event(
        setup_session_id,
        event_type,
        from_work_day_id,
        from_work_date,
        from_setup_day_number,
        event_note
    ) VALUES (
        v_session_id,
        'WORK_DAY_DELETED',
        p_setup_work_day_id,
        v_work_date,
        v_day_number,
        nullif(btrim(p_note), '')
    );

    DELETE FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id;

    PERFORM ops.resequence_setup_future_work_days(v_session_id);

    RETURN QUERY
    SELECT p_setup_work_day_id, v_day_number, v_work_date, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.remove_empty_setup_work_day(text,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_empty_setup_work_day(text,bigint,text) TO fieldwiring_app;

/* Preserve the migration-068 two-argument command for compatibility. */
CREATE OR REPLACE FUNCTION ops.remove_empty_setup_work_day(
    p_email text,
    p_setup_work_day_id bigint
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_day_number integer,
    work_date date,
    operator_display_name text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
    SELECT *
    FROM ops.remove_empty_setup_work_day(
        p_email,
        p_setup_work_day_id,
        NULL::text
    );
$function$;

REVOKE ALL ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   ASSIGNMENT MOVE AUDIT — PASSIVE; NO MOVE-REASON PROMPT
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.update_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_task_id bigint,
    p_setup_work_day_id bigint,
    p_shift_code text,
    p_setup_work_day_crew_id bigint,
    p_sort_order integer
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_shift text := upper(btrim(coalesce(p_shift_code, 'MORNING')));
    v_lane text;
    v_session_id bigint;
    v_session_task_id bigint;
    v_from_work_day_id bigint;
    v_from_work_date date;
    v_from_day_number integer;
    v_from_shift text;
    v_from_crew_id bigint;
    v_from_crew_code text;
    v_to_work_date date;
    v_to_day_number integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT
        wdt.setup_session_task_id,
        wdt.setup_work_day_id,
        wd.setup_session_id,
        wd.work_date,
        wd.setup_day_number,
        wdt.shift_code,
        wdt.setup_work_day_crew_id,
        coalesce(c.crew_code, wdt.crew_lane)
      INTO
        v_session_task_id,
        v_from_work_day_id,
        v_session_id,
        v_from_work_date,
        v_from_day_number,
        v_from_shift,
        v_from_crew_id,
        v_from_crew_code
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    LEFT JOIN ops.setup_work_day_crew c
      ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;

    IF v_session_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Scheduled Setup assignment was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id
          AND (
              wdt.actual_crew_count IS NOT NULL
              OR wdt.started_at IS NOT NULL
              OR wdt.completed_at IS NOT NULL
          )
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_work_day_task wdt
          ON wdt.setup_work_day_task_id = p_setup_work_day_task_id
        WHERE p.setup_work_day_task_id = p_setup_work_day_task_id
           OR (
               p.setup_work_day_task_id IS NULL
               AND p.setup_work_day_id = wdt.setup_work_day_id
               AND p.setup_session_task_id = wdt.setup_session_task_id
               AND p.shift_code = wdt.shift_code
           )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this assignment; preserve it as history and schedule a continuation instead';
    END IF;

    IF v_shift NOT IN ('MORNING','AFTERNOON') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'New Scheduling Board assignments must use Morning or Afternoon';
    END IF;

    SELECT
        c.crew_code,
        wd.work_date,
        wd.setup_day_number
      INTO
        v_lane,
        v_to_work_date,
        v_to_day_number
    FROM ops.setup_work_day_crew c
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = c.setup_work_day_id
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id
      AND c.setup_work_day_id = p_setup_work_day_id
      AND wd.setup_session_id = v_session_id;

    IF v_lane IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected crew does not belong to the selected Setup work day';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task other
        WHERE other.setup_work_day_id = p_setup_work_day_id
          AND other.setup_session_task_id = v_session_task_id
          AND other.setup_work_day_task_id <> p_setup_work_day_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
            MESSAGE = 'This task is already scheduled on this Setup work day';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_work_day_task wdt
       SET setup_work_day_id = p_setup_work_day_id,
           shift_code = v_shift,
           crew_lane = v_lane,
           setup_work_day_crew_id = p_setup_work_day_crew_id,
           sort_order = coalesce(p_sort_order, wdt.sort_order),
           planned_crew_count = NULL
     WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;

    IF v_from_work_day_id IS DISTINCT FROM p_setup_work_day_id
       OR v_from_shift IS DISTINCT FROM v_shift
       OR v_from_crew_id IS DISTINCT FROM p_setup_work_day_crew_id THEN
        INSERT INTO ops.setup_schedule_event(
            setup_session_id,
            event_type,
            setup_work_day_task_id,
            setup_session_task_id,
            from_work_day_id,
            from_work_date,
            from_setup_day_number,
            from_shift_code,
            from_crew_code,
            to_work_day_id,
            to_work_date,
            to_setup_day_number,
            to_shift_code,
            to_crew_code
        ) VALUES (
            v_session_id,
            'ASSIGNMENT_MOVED',
            p_setup_work_day_task_id,
            v_session_task_id,
            v_from_work_day_id,
            v_from_work_date,
            v_from_day_number,
            v_from_shift,
            v_from_crew_code,
            p_setup_work_day_id,
            v_to_work_date,
            v_to_day_number,
            v_shift,
            v_lane
        );
    END IF;

    PERFORM ops.refresh_setup_session_task_schedule_state(v_session_task_id);
    RETURN QUERY SELECT p_setup_work_day_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) TO fieldwiring_app;

COMMIT;

SELECT
    to_regclass('ops.setup_schedule_event') IS NOT NULL
        AS schedule_event_ready,
    to_regprocedure('ops.add_historical_setup_work_day(text,integer,date,text)') IS NOT NULL
        AS historical_work_day_command_ready,
    to_regprocedure('ops.remove_empty_setup_work_day(text,bigint,text)') IS NOT NULL
        AS noted_empty_day_remove_ready;
