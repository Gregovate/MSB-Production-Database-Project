/* ============================================================================
MSB Setup Session — season-year operational date guard + Admin baseline promotion
Issue: #122
Status: PRODUCTION CANDIDATE — REVIEW BEFORE APPLY
Revision: 2026-09-07 V0.3.4

Purpose:
  Make the active Setup Session year the authoritative boundary for every
  operator-entered operational date currently exposed by Setup:

  - ops.setup_work_day.work_date
  - ops.setup_session_task.planned_date
  - ops.setup_session_task.actual_started_at
  - ops.setup_session_task.actual_completed_at
  - ops.setup_movement_event.occurred_at

  The same rule applies automatically to future seasons. A 2025 historical
  review accepts only 2025 operational dates; a 2026 Setup Session accepts only
  2026 operational dates.

  Audit timestamps are intentionally NOT season-limited. created_at, updated_at,
  and ops.setup_task_progress.recorded_at remain real recording timestamps, so a
  historical 2025 correction entered during 2026 preserves both facts correctly.

  Also restrict promotion of an annual planned order into the reusable future
  baseline to Setup Administrators. Managers/reviewers may reorder the active
  annual session but cannot carry that order forward to a future season.

Timezone:
  Operational timestamptz year checks use America/Chicago, matching the existing
  MSB FieldWiring runtime timezone contract.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_movement_event') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.update_setup_session_task_review(text,bigint,text,timestamptz,timestamptz,integer,integer,text)') IS NULL
       OR to_regprocedure('ops.upsert_setup_work_day(text,integer,date,text,text)') IS NULL
       OR to_regprocedure('ops.promote_setup_session_order_to_baseline(text,integer)') IS NULL THEN
        RAISE EXCEPTION 'Setup migrations through 011 and management commands are required before migration 017';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   UNIVERSAL TABLE-LEVEL SESSION-YEAR GUARDS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.enforce_setup_work_day_session_year()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
DECLARE
    v_year integer;
BEGIN
    SELECT ss.season_year
      INTO v_year
    FROM ops.setup_session ss
    WHERE ss.setup_session_id = NEW.setup_session_id;

    IF v_year IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23503',
            MESSAGE = 'Setup work day references an unknown Setup Session';
    END IF;

    IF NEW.work_date IS NOT NULL
       AND extract(year FROM NEW.work_date)::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Setup work date %s must be in active Setup Session year %s',
                NEW.work_date,
                v_year
            );
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_work_day_session_year ON ops.setup_work_day;
CREATE TRIGGER trg_setup_work_day_session_year
BEFORE INSERT OR UPDATE OF setup_session_id, work_date
ON ops.setup_work_day
FOR EACH ROW EXECUTE FUNCTION ops.enforce_setup_work_day_session_year();

REVOKE ALL ON FUNCTION ops.enforce_setup_work_day_session_year() FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.enforce_setup_work_day_session_year() FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.enforce_setup_session_task_operational_year()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
DECLARE
    v_year integer;
BEGIN
    SELECT ss.season_year
      INTO v_year
    FROM ops.setup_session ss
    WHERE ss.setup_session_id = NEW.setup_session_id;

    IF v_year IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23503',
            MESSAGE = 'Setup annual task references an unknown Setup Session';
    END IF;

    IF NEW.planned_date IS NOT NULL
       AND extract(year FROM NEW.planned_date)::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Setup planned date %s must be in active Setup Session year %s',
                NEW.planned_date,
                v_year
            );
    END IF;

    IF NEW.actual_started_at IS NOT NULL
       AND extract(year FROM (NEW.actual_started_at AT TIME ZONE 'America/Chicago'))::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Setup actual start must be in active Setup Session year %s',
                v_year
            );
    END IF;

    IF NEW.actual_completed_at IS NOT NULL
       AND extract(year FROM (NEW.actual_completed_at AT TIME ZONE 'America/Chicago'))::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Setup actual completion must be in active Setup Session year %s',
                v_year
            );
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_session_task_operational_year ON ops.setup_session_task;
CREATE TRIGGER trg_setup_session_task_operational_year
BEFORE INSERT OR UPDATE OF setup_session_id, planned_date, actual_started_at, actual_completed_at
ON ops.setup_session_task
FOR EACH ROW EXECUTE FUNCTION ops.enforce_setup_session_task_operational_year();

REVOKE ALL ON FUNCTION ops.enforce_setup_session_task_operational_year() FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.enforce_setup_session_task_operational_year() FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.enforce_setup_movement_event_session_year()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
DECLARE
    v_year integer;
BEGIN
    SELECT ss.season_year
      INTO v_year
    FROM ops.setup_session ss
    WHERE ss.setup_session_id = NEW.setup_session_id;

    IF v_year IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23503',
            MESSAGE = 'Setup movement event references an unknown Setup Session';
    END IF;

    IF NEW.occurred_at IS NOT NULL
       AND extract(year FROM (NEW.occurred_at AT TIME ZONE 'America/Chicago'))::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Setup movement occurrence must be in active Setup Session year %s',
                v_year
            );
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_movement_event_session_year ON ops.setup_movement_event;
CREATE TRIGGER trg_setup_movement_event_session_year
BEFORE INSERT OR UPDATE OF setup_session_id, occurred_at
ON ops.setup_movement_event
FOR EACH ROW EXECUTE FUNCTION ops.enforce_setup_movement_event_session_year();

REVOKE ALL ON FUNCTION ops.enforce_setup_movement_event_session_year() FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.enforce_setup_movement_event_session_year() FROM fieldwiring_app;

/* --------------------------------------------------------------------------
   COMMAND-LAYER VALIDATION FOR CLEAR OPERATOR ERRORS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.upsert_setup_work_day(
    p_email text,
    p_season_year integer,
    p_work_date date,
    p_day_status text DEFAULT 'PLANNED',
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    setup_work_day_id bigint,
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
    v_status text := upper(btrim(coalesce(p_day_status, 'PLANNED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_work_date IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Work date is required';
    END IF;
    IF extract(year FROM p_work_date)::integer <> p_season_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Work date %s must be in active Setup Session year %s',
                p_work_date,
                p_season_year
            );
    END IF;
    IF v_status NOT IN ('PLANNED','ACTIVE','COMPLETE','CANCELLED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup work-day status';
    END IF;

    SELECT s.setup_session_id INTO v_session_id
    FROM ops.setup_session s
    WHERE s.season_year = p_season_year;
    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup Session was not found for this season';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_work_day(setup_session_id, work_date, day_status, notes)
    VALUES (v_session_id, p_work_date, v_status, nullif(btrim(p_notes), ''))
    ON CONFLICT ON CONSTRAINT uq_setup_work_day
    DO UPDATE SET day_status = EXCLUDED.day_status,
                  notes = EXCLUDED.notes
    RETURNING ops.setup_work_day.setup_work_day_id INTO v_day_id;

    RETURN QUERY SELECT v_day_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.update_setup_session_task_review(
    p_email text,
    p_setup_session_task_id bigint,
    p_verification_state text,
    p_actual_started_at timestamptz,
    p_actual_completed_at timestamptz,
    p_actual_crew_count integer,
    p_actual_duration_minutes integer,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
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
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
    v_year integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    SELECT ss.season_year
      INTO v_year
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_year IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup annual task was not found';
    END IF;

    IF v_verification NOT IN ('UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup verification state';
    END IF;

    IF p_actual_started_at IS NOT NULL
       AND extract(year FROM (p_actual_started_at AT TIME ZONE 'America/Chicago'))::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Actual start must be in active Setup Session year %s', v_year);
    END IF;

    IF p_actual_completed_at IS NOT NULL
       AND extract(year FROM (p_actual_completed_at AT TIME ZONE 'America/Chicago'))::integer <> v_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Actual completion must be in active Setup Session year %s', v_year);
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_session_task st
       SET verification_state = v_verification,
           actual_started_at = p_actual_started_at,
           actual_completed_at = p_actual_completed_at,
           actual_crew_count = p_actual_crew_count,
           actual_duration_minutes = p_actual_duration_minutes,
           annual_notes = nullif(btrim(p_annual_notes), '')
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup annual task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(
    text,bigint,text,timestamptz,timestamptz,integer,integer,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(
    text,bigint,text,timestamptz,timestamptz,integer,integer,text
) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   ONLY ADMINISTRATORS MAY CARRY AN ANNUAL ORDER INTO THE FUTURE BASELINE
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.promote_setup_session_order_to_baseline(
    p_email text,
    p_season_year integer
)
RETURNS TABLE (
    updated_task_count integer,
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
    v_count integer := 0;
BEGIN
    /* p_require_admin = true */
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, true) AS a;

    IF NOT EXISTS (
        SELECT 1 FROM ops.setup_session ss WHERE ss.season_year = p_season_year
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup Session was not found for baseline promotion';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.setup_task t
       SET baseline_plan_order = st.planned_order
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE ss.season_year = p_season_year
      AND st.setup_task_id = t.setup_task_id
      AND st.included_flag
      AND st.planned_order IS NOT NULL
      AND t.active_flag;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN QUERY SELECT v_count, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) TO fieldwiring_app;

COMMIT;

SELECT
    to_regprocedure('ops.enforce_setup_work_day_session_year()') IS NOT NULL
        AS work_day_year_guard_exists,
    to_regprocedure('ops.enforce_setup_session_task_operational_year()') IS NOT NULL
        AS annual_task_year_guard_exists,
    to_regprocedure('ops.enforce_setup_movement_event_session_year()') IS NOT NULL
        AS movement_year_guard_exists,
    pg_get_functiondef('ops.promote_setup_session_order_to_baseline(text,integer)'::regprocedure)
        LIKE '%setup_management_actor(p_email, true)%'
        AS baseline_promotion_requires_admin,
    pg_get_functiondef('ops.upsert_setup_work_day(text,integer,date,text,text)'::regprocedure)
        LIKE '%must be in active Setup Session year%'
        AS work_day_command_checks_year;
