--
-- PostgreSQL database dump
--

\restrict uaNgop6UwyfdJZRis2g9cNEF2lwlH1lO9Mb4Ajx9bxYVSQnJtfcaA3Sv9Z8HYQh

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg110+1)
-- Dumped by pg_dump version 18.4

-- Started on 2026-07-31 08:06:24

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 16 (class 2615 OID 16389)
-- Name: lor_snap; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA lor_snap;


--
-- TOC entry 17 (class 2615 OID 17193)
-- Name: ops; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ops;


--
-- TOC entry 18 (class 2615 OID 16687)
-- Name: ref; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ref;


--
-- TOC entry 5476 (class 0 OID 0)
-- Dependencies: 18
-- Name: SCHEMA ref; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA ref IS 'Schema for all reference tables (masters) ';


--
-- TOC entry 20 (class 2615 OID 16857)
-- Name: stage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA stage;


--
-- TOC entry 2057 (class 1247 OID 18888)
-- Name: display_test_status_enum; Type: TYPE; Schema: ops; Owner: -
--

CREATE TYPE ops.display_test_status_enum AS ENUM (
    'OK',
    'REPAIR',
    'DEFER'
);


--
-- TOC entry 2048 (class 1247 OID 18853)
-- Name: test_result_code; Type: TYPE; Schema: ops; Owner: -
--

CREATE TYPE ops.test_result_code AS ENUM (
    'OK',
    'REPAIR',
    'DEFER'
);


--
-- TOC entry 1106 (class 1255 OID 18081)
-- Name: _yn_to_bool(text); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops._yn_to_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select case
    when p_text is null then null
    when upper(btrim(p_text)) in ('Y','YES','TRUE','T','1') then true
    when upper(btrim(p_text)) in ('N','NO','FALSE','F','0') then false
    else null
  end;
$$;


--
-- TOC entry 928 (class 1255 OID 19138)
-- Name: display_test_session_set_checked_fields(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.display_test_session_set_checked_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    -- Only stamp the first time test_status moves from NULL to a value
    IF OLD.test_status IS NULL
       AND NEW.test_status IS NOT NULL THEN

        SELECT person_id, actor_name
        INTO v_person_id, v_actor_name
        FROM ref.resolve_actor();

        NEW.checked_at := now();

        -- Respect values already stamped by Directus; otherwise fallback to DB actor resolution
        NEW.checked_by := COALESCE(NEW.checked_by, v_actor_name);
        NEW.checked_by_person_id := COALESCE(NEW.checked_by_person_id, v_person_id);
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 1074 (class 1255 OID 18866)
-- Name: p_pull_container(integer, text, text); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_test_session_id bigint;
BEGIN
  SELECT ts.test_session_id
    INTO v_test_session_id
  FROM ops.test_session ts
  WHERE ts.container_id = p_container_id
    AND ts.done_at IS NULL
  ORDER BY ts.pulled_at DESC
  LIMIT 1;

  IF v_test_session_id IS NULL THEN
    RAISE EXCEPTION 'No open test_session found for container_id=%', p_container_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ref.display d
    WHERE d.container_id = p_container_id
  ) THEN
    RETURN v_test_session_id;
  END IF;

  UPDATE ops.test_session
     SET container_test_status_id = 2,
         work_location_code = COALESCE(work_location_code, p_work_location_code),
         pulled_by = COALESCE(pulled_by, p_pulled_by),
         pulled_at = COALESCE(pulled_at, NOW())
   WHERE test_session_id = v_test_session_id;

  INSERT INTO ops.display_test_session
  (
    test_session_id,
    lor_prop_id,
    display_id,
    stage_id,
    is_spare,
    is_display_present,
    checked_at,
    checked_by,
    notes,
    checked_date_text,
    test_status,
    amps_measured,
    light_count,
    display_state
  )
  SELECT
    v_test_session_id,
    d.lor_prop_id,
    d.display_id,
    d.stage_id,
    false,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  FROM ref.display d
  WHERE d.container_id = p_container_id
  ON CONFLICT (test_session_id, display_id) DO NOTHING;

  RETURN v_test_session_id;
END;
$$;


--
-- TOC entry 821 (class 1255 OID 19496)
-- Name: p_pull_container(integer, text, text, integer); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER, p_pulled_by_person_id integer DEFAULT NULL::integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_test_session_id bigint;
BEGIN
    SELECT ts.test_session_id
      INTO v_test_session_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.container_id = p_container_id
      AND ts.done_at IS NULL
      AND s.active_flag = true
    ORDER BY ts.pulled_at DESC NULLS LAST, ts.test_session_id DESC
    LIMIT 1;

    IF v_test_session_id IS NULL THEN
        RAISE EXCEPTION 'No open active-season test_session found for container_id=%', p_container_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display d
        WHERE d.container_id = p_container_id
    ) THEN
        UPDATE ops.test_session
           SET container_test_status_id = 2,
               work_location_code = COALESCE(work_location_code, p_work_location_code),
               pulled_by = p_pulled_by,
               pulled_by_person_id = p_pulled_by_person_id,
               pulled_at = NOW()
         WHERE test_session_id = v_test_session_id;

        RETURN v_test_session_id;
    END IF;

    UPDATE ops.test_session
       SET container_test_status_id = 2,
           work_location_code = COALESCE(work_location_code, p_work_location_code),
           pulled_by = p_pulled_by,
           pulled_by_person_id = p_pulled_by_person_id,
           pulled_at = NOW()
     WHERE test_session_id = v_test_session_id;

    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        v_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id
    FROM ref.display d
    WHERE d.container_id = p_container_id
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    RETURN v_test_session_id;
END;
$$;


--
-- TOC entry 608 (class 1255 OID 19544)
-- Name: p_pull_container(integer, text, text, bigint); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER, p_pulled_by_person_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_test_session_id bigint;
BEGIN
    SELECT ts.test_session_id
      INTO v_test_session_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.container_id = p_container_id
      AND ts.done_at IS NULL
      AND s.active_flag = true
    ORDER BY ts.pulled_at DESC NULLS LAST, ts.test_session_id DESC
    LIMIT 1;

    IF v_test_session_id IS NULL THEN
        RAISE EXCEPTION 'No open active-season test_session found for container_id=%', p_container_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display d
        WHERE d.container_id = p_container_id
    ) THEN
        UPDATE ops.test_session
           SET container_test_status_id = 2,
               work_location_code = COALESCE(work_location_code, p_work_location_code),
               pulled_by = p_pulled_by,
               pulled_by_person_id = p_pulled_by_person_id,
               pulled_at = NOW()
         WHERE test_session_id = v_test_session_id;

        RETURN v_test_session_id;
    END IF;

    UPDATE ops.test_session
       SET container_test_status_id = 2,
           work_location_code = COALESCE(work_location_code, p_work_location_code),
           pulled_by = p_pulled_by,
           pulled_by_person_id = p_pulled_by_person_id,
           pulled_at = NOW()
     WHERE test_session_id = v_test_session_id;

    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        v_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id
    FROM ref.display d
    WHERE d.container_id = p_container_id
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    RETURN v_test_session_id;
END;
$$;


--
-- TOC entry 597 (class 1255 OID 19554)
-- Name: p_refresh_test_session(bigint, text, integer); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    v_container_id integer;
    v_add_count integer := 0;
    v_delete_count integer := 0;
BEGIN
    SELECT ts.container_id
      INTO v_container_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.test_session_id = p_test_session_id
      AND s.active_flag = true;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION 'No active-season test_session found for test_session_id=%', p_test_session_id;
    END IF;

    -- Add missing rows
    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        p_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_refreshed_by,
        p_refreshed_by_person_id,
        NOW(),
        p_refreshed_by,
        p_refreshed_by_person_id
    FROM ref.display d
    WHERE d.container_id = v_container_id
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    GET DIAGNOSTICS v_add_count = ROW_COUNT;

    -- Delete safe wrong rows
    DELETE FROM ops.display_test_session dts
    WHERE dts.test_session_id = p_test_session_id
      AND NOT EXISTS (
            SELECT 1
            FROM ref.display d
            WHERE d.display_id = dts.display_id
              AND d.container_id = v_container_id
      )
      AND dts.is_display_present IS DISTINCT FROM TRUE
      AND dts.test_status = 'WRONG_CONTAINER'
      AND NOT EXISTS (
            SELECT 1
            FROM ops.work_order wo
            WHERE wo.display_test_session_id = dts.display_test_session_id
      );

    GET DIAGNOSTICS v_delete_count = ROW_COUNT;

    -- Stamp latest refresh audit and reset flag
    UPDATE ops.test_session
       SET refresh_requested = FALSE,
           last_refreshed_at = NOW(),
           last_refreshed_by = p_refreshed_by,
           last_refreshed_by_person_id = p_refreshed_by_person_id,
           last_refresh_add_count = v_add_count,
           last_refresh_delete_count = v_delete_count
     WHERE test_session_id = p_test_session_id;
END;
$$;


--
-- TOC entry 5477 (class 0 OID 0)
-- Dependencies: 597
-- Name: FUNCTION p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer); Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) IS 'Updated 3/25/26 to delete safe rows that do not have work orders assigned to them.';


--
-- TOC entry 961 (class 1255 OID 19110)
-- Name: set_audit_fields(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.set_audit_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := current_user;
    RETURN NEW;
END;
$$;


--
-- TOC entry 567 (class 1255 OID 19175)
-- Name: set_checked_actor(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.set_checked_actor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    -- Stamp checked fields whenever test_status changes
    -- to a nonblank value. This makes checked_* represent
    -- the latest person who set the current test status.
    IF NEW.test_status IS DISTINCT FROM OLD.test_status
       AND NEW.test_status IS NOT NULL
       AND btrim(NEW.test_status) <> '' THEN

        SELECT person_id, actor_name
        INTO v_person_id, v_actor_name
        FROM ref.resolve_actor();

        -- Database owns checked_at
        NEW.checked_at := now();

        -- Respect Directus-stamped values if present;
        -- otherwise fall back to DB actor resolution.
        NEW.checked_by := COALESCE(NEW.checked_by, v_actor_name);

        IF to_jsonb(NEW) ? 'checked_by_person_id' THEN
            NEW.checked_by_person_id := COALESCE(NEW.checked_by_person_id, v_person_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 613 (class 1255 OID 19297)
-- Name: set_container_search_helper(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.set_container_search_helper() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  SELECT LEFT(c.description, 20)
    INTO NEW.container_search_helper
  FROM ref.container c
  WHERE c.container_id = NEW.container_id;

  RETURN NEW;
END;
$$;


--
-- TOC entry 942 (class 1255 OID 19555)
-- Name: tf_after_refresh_test_session(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.tf_after_refresh_test_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NULL;
    END IF;

    IF OLD.refresh_requested = FALSE
       AND NEW.refresh_requested = TRUE THEN

        PERFORM ops.p_refresh_test_session(
            NEW.test_session_id,
            NEW.updated_by,
            NEW.updated_by_person_id
        );
    END IF;

    RETURN NULL;
END;
$$;


--
-- TOC entry 1136 (class 1255 OID 19301)
-- Name: tf_after_start_container_pull(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.tf_after_start_container_pull() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  IF OLD.container_test_status_id = 1
     AND NEW.container_test_status_id = 2
     AND NEW.work_location_code IS NOT NULL THEN

    PERFORM ops.p_pull_container(
      NEW.container_id,
      NEW.work_location_code,
      NEW.updated_by,
      NEW.updated_by_person_id
    );
  END IF;

  RETURN NULL;
END;
$$;


--
-- TOC entry 944 (class 1255 OID 19292)
-- Name: tf_start_container_pull(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.tf_start_container_pull() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Require work location only on Not Started -> In Progress
  IF OLD.container_test_status_id = 1
     AND NEW.container_test_status_id = 2 THEN

    IF NEW.work_location_code IS NULL OR btrim(NEW.work_location_code) = '' THEN
      RAISE EXCEPTION 'Work Location Required to Pull Container';
    END IF;
  END IF;

  -- Keep work location only for In Progress (2) and Deferred (8)
  IF NEW.container_test_status_id NOT IN (2, 8) THEN
    NEW.work_location_code := NULL;
  END IF;

  RETURN NEW;
END;
$$;


--
-- TOC entry 442 (class 1255 OID 19560)
-- Name: tf_validate_display_test_session_notes(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.tf_validate_display_test_session_notes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.test_status = 'REPAIR'
       AND NULLIF(BTRIM(COALESCE(NEW.notes, '')), '') IS NULL THEN
        RAISE EXCEPTION 'REPAIR requires a note describing the problem.';
    END IF;

    IF NEW.test_status = 'OK_REPAIRED'
       AND NULLIF(BTRIM(COALESCE(NEW.notes, '')), '') IS NULL THEN
        RAISE EXCEPTION 'OK_REPAIRED requires a note describing the repair.';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 697 (class 1255 OID 19574)
-- Name: tf_work_order_autofill_completion_on_repair_complete(); Type: FUNCTION; Schema: ops; Owner: -
--

CREATE FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    IF NEW.repair_complete IS TRUE
       OR NEW.date_completed IS NOT NULL THEN

        IF NEW.completed_by_person_id IS NULL THEN
            SELECT person_id, actor_name
            INTO v_person_id, v_actor_name
            FROM ref.resolve_actor();

            NEW.completed_by_person_id := COALESCE(v_person_id, NEW.updated_by_person_id);
        END IF;

        IF NEW.repair_complete IS TRUE AND NEW.date_completed IS NULL THEN
            NEW.date_completed := now();
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 1056 (class 1255 OID 17175)
-- Name: apply_display_metadata_from_sheet(); Type: PROCEDURE; Schema: ref; Owner: -
--

CREATE PROCEDURE ref.apply_display_metadata_from_sheet()
    LANGUAGE plpgsql
    AS $$/*
apply_display_metadata_from_sheet
*/

begin
  -- Direct fields + pallet_id normalization + cast to int
  update ref.display d
  set
    year_built      = m.year_built,
    amps_measured   = m.amps_measured,
    est_light_count = m.est_light_count,
    dumb_controller = m.dumb_controller,
    notes           = m.notes,

    pallet_id = nullif(
                  regexp_replace(coalesce(m.pallet_id_raw,''), '[^0-9]', '', 'g'),
                  ''
                )::integer,

    updated_at      = now(),
    updated_by      = current_user
  from stage.v_sheet_match m
  where m.lor_prop_id = d.lor_prop_id;

  -- Status text -> id
  update ref.display d
  set
    display_status_id = ds.display_status_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.display_status ds
    on upper(ds.display_status_name) = upper(m.display_status)
  where m.lor_prop_id = d.lor_prop_id
    and m.display_status is not null
    and btrim(m.display_status) <> '';

  -- Theme name -> theme_id
  update ref.display d
  set
    theme_id = t.theme_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.theme t
    on upper(t.theme_name) = upper(m.theme_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.theme_name is not null
    and btrim(m.theme_name) <> '';

  -- Designer "First Last" -> person_id
  update ref.display d
  set
    designer_id = p.person_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.person p
    on upper(p.first_name || ' ' || p.last_name) = upper(m.designer_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.designer_name is not null
    and btrim(m.designer_name) <> '';

  -- Frame name -> frame_id (ref.frame.frame_name)
  update ref.display d
  set
    frame_id = f.frame_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.frame f
    on upper(f.frame_name) = upper(m.frame_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.frame_name is not null
    and btrim(m.frame_name) <> '';

end;
$$;


--
-- TOC entry 503 (class 1255 OID 18341)
-- Name: p1_upsert_stage_from_latest_lor(); Type: PROCEDURE; Schema: ref; Owner: -
--

CREATE PROCEDURE ref.p1_upsert_stage_from_latest_lor()
    LANGUAGE plpgsql
    AS $_$/*
Procedure: ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest LOR snapshot (lor_snap.previews).
  Fully derived from preview names; non-destructive; preserves stage_id stability.

Reads:
  lor_snap.import_run
  lor_snap.previews

Writes:
  ref.stage (UPSERT)
    - inserts missing stage_key
    - updates stage_name/folder_name/order fields for existing stage_key
    - never deletes/truncates

Notes:
  - Uses DISTINCT ON(stage_key) to guarantee one row per stage_key (prevents ON CONFLICT double-hit).
  - stage_key is lower(previews.stage_id) and supports substages like '07a'.

Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.

ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest lor_snap.previews import.
  LOR is authoritative for stage naming.

Rules:
  - Only accept canonical stage IDs: 0-99 with optional letter suffix (e.g. 07, 07a)
  - stage_key is normalized: lower(btrim(stage_id))
  - stage_name + folder_name derived from preview name

Notes:
  - This does NOT delete stages that are no longer present in LOR.
*/
declare
  v_run_id bigint;
begin
  select max(import_run_id)
    into v_run_id
  from lor_snap.import_run;

  if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
  end if;

  /*
    Choose ONE preview row per stage_key.
    Ordering rule (deterministic):
      - prefer names that start with "Stage"
      - then prefer longer names (more descriptive)
      - then stable tie-breaker by name
  */
  with one_per_stage as (
    select distinct on (lower(p.stage_id))
      lower(p.stage_id) as stage_key,
      p.stage_id        as stage_id_raw,
      p.name            as preview_name
    from lor_snap.previews p
    where p.import_run_id = v_run_id
      and p.stage_id is not null
      and btrim(p.stage_id) <> ''
    order by
      lower(p.stage_id),
      (p.name ~* '^\s*stage\b') desc,
      length(p.name) desc,
      p.name desc
  )
  insert into ref.stage (
      stage_key,
      stage_name,
      short_code,
      folder_name,
      folder_path,
      park_order,
      sub_order,
      created_at,
      created_by,
      updated_at,
      updated_by
  )
  select
      s.stage_key,

      /* stage_name: strip leading "Stage <key>" and trailing "with|w/" */
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage ' || s.stage_id_raw
      ) as stage_name,

      null as short_code,

      /* folder_name: "<stage_key>-<stage_name>" */
      s.stage_key || '-' ||
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage'
      ) as folder_name,

      null as folder_path,

      /* park_order: numeric part */
      ((regexp_match(lower(s.stage_id_raw), '^0*(\d{1,2})'))[1])::int as park_order,

      /* sub_order: a=1, b=2, ... else 0 */
      case
        when lower(s.stage_id_raw) ~ '^\d{1,2}[a-z]$'
          then ascii(substring(lower(s.stage_id_raw) from '[a-z]')) - ascii('a') + 1
        else 0
      end as sub_order,

      now(),
      current_user,
      now(),
      current_user

  from one_per_stage s

  on conflict (stage_key)
  do update set
      stage_name  = excluded.stage_name,
      folder_name = excluded.folder_name,
      park_order  = excluded.park_order,
      sub_order   = excluded.sub_order,
      updated_at  = now(),
      updated_by  = current_user;

end;
$_$;


--
-- TOC entry 5478 (class 0 OID 0)
-- Dependencies: 503
-- Name: PROCEDURE p1_upsert_stage_from_latest_lor(); Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON PROCEDURE ref.p1_upsert_stage_from_latest_lor() IS '/*
Procedure: ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest LOR snapshot (lor_snap.previews).
  Fully derived from preview names; non-destructive; preserves stage_id stability.

Reads:
  lor_snap.import_run
  lor_snap.previews

Writes:
  ref.stage (UPSERT)
    - inserts missing stage_key
    - updates stage_name/folder_name/order fields for existing stage_key
    - never deletes/truncates

Notes:
  - Uses DISTINCT ON(stage_key) to guarantee one row per stage_key (prevents ON CONFLICT double-hit).
  - stage_key is lower(previews.stage_id) and supports substages like ''07a''.

Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.
Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.

ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest lor_snap.previews import.
  LOR is authoritative for stage naming.

Rules:
  - Only accept canonical stage IDs: 0-99 with optional letter suffix (e.g. 07, 07a)
  - stage_key is normalized: lower(btrim(stage_id))
  - stage_name + folder_name derived from preview name

Notes:
  - This does NOT delete stages that are no longer present in LOR.
*/';


--
-- TOC entry 1005 (class 1255 OID 18571)
-- Name: p2_upsert_display_from_latest_lor(); Type: PROCEDURE; Schema: ref; Owner: -
--

CREATE PROCEDURE ref.p2_upsert_display_from_latest_lor()
    LANGUAGE plpgsql
    AS $_$
/* ============================================================
Procedure: ref.p2_upsert_display_from_latest_lor()

Purpose:
  Upsert NON-SPARE displays into ref.display from latest LOR snapshot.
  Route SPARE items into ref.spare_channel.
  Ensure NO SPARE rows remain in ref.display for latest run set.

Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
  2026-03-01 GAL  Add string_type + color (LOR-owned) to ref.display + ref.spare_channel.
============================================================ */
declare
  v_run_id bigint;

v_active_status_id integer;

v_missing_stage_keys integer;

begin
  /* 1) Latest import */
select
	max(import_run_id)
into
	v_run_id
from
	lor_snap.import_run;

if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
end if;

/* 2) ACTIVE display status */
select
	display_status_id
into
	v_active_status_id
from
	ref.display_status
where
	upper(display_status_name) = 'ACTIVE'
limit 1;

if v_active_status_id is null then
    raise exception 'ACTIVE status not found in ref.display_status';
end if;

/* 3) Guardrail: stage keys must exist */
select
	count(*)
into
	v_missing_stage_keys
from
	(
	select
		distinct lower(btrim(pr.stage_id)) as stage_key
	from
		lor_snap.props p
	join lor_snap.previews pr on
		pr.id = p.preview_id
	where
		p.import_run_id = v_run_id
		and pr.stage_id is not null
		and btrim(pr.stage_id) <> ''
			and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
  ) k
left join ref.stage s on
	s.stage_key = k.stage_key
where
	s.stage_key is null;

if v_missing_stage_keys > 0 then
    raise exception
      'Missing % stage_key rows in ref.stage for latest import_run_id=% (run p1_upsert_stage first)',
v_missing_stage_keys,
v_run_id;
end if;

/* 4) Materialize a deterministic, deduped classified set for this run */
create temporary table tmp_classified (
    lor_prop_id text,
display_name text,
prop_name text,
prop_comment text,
preview_stage_key text,
string_type text,
color text,
is_spare boolean
  ) on
commit drop;

insert
	into
	tmp_classified (
    lor_prop_id,
	display_name,
	prop_name,
	prop_comment,
	preview_stage_key,
	string_type,
	color,
	is_spare
  )
select
	lr.lor_prop_id,
	lr.display_name,
	lr.prop_name,
	lr.prop_comment,
	lr.preview_stage_key,
	lr.string_type,
	lr.color,
	case
		when lr.display_name ilike '%spare%'
		or coalesce(lr.prop_name, '') ilike '%spare%'
		or coalesce(lr.prop_comment, '') ilike '%spare%'
      then true
		else false
	end as is_spare
from
	(
	select
		distinct on
		(p.prop_id)
      p.prop_id as lor_prop_id,
		coalesce(nullif(btrim(p.lor_comment), ''), p.name) as display_name,
		p.name as prop_name,
		p.lor_comment as prop_comment,
		lower(btrim(pr.stage_id)) as preview_stage_key,
		p.string_type,
		p.color
	from
		lor_snap.props p
	join lor_snap.previews pr
      on
		pr.id = p.preview_id
	where
		p.import_run_id = v_run_id
		and upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) not like '%PHANTOM%'
			and pr.stage_id is not null
			and btrim(pr.stage_id) <> ''
				and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
			order by
				p.prop_id,
				(nullif(btrim(p.lor_comment), '') is not null) desc,
				length(coalesce(p.lor_comment, '')) desc,
				p.name desc
  ) lr;

/* 5) Upsert SPARE into ref.spare_channel */
insert
	into
	ref.spare_channel (
      lor_prop_id,
	display_name,
	inventory_type,
	display_status_id,
	stage_id,
	string_type,
	color
  )
select
	c.lor_prop_id,
	c.display_name,
	'LOR',
	v_active_status_id,
	s.stage_id,
	c.string_type,
	c.color
from
	tmp_classified c
join ref.stage s
    on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = true
  on
	conflict (lor_prop_id)
  do
update
set
	display_name = excluded.display_name,
	inventory_type = excluded.inventory_type,
	display_status_id = excluded.display_status_id,
	stage_id = excluded.stage_id,
	string_type = excluded.string_type,
	color = excluded.color;

/* 6) Ensure SPARE rows are NOT in ref.display (latest run set only) */
-- delete
-- from
-- 	ref.display d
-- 		using tmp_classified c
-- where
-- 	c.is_spare = true
-- 	and d.lor_prop_id = c.lor_prop_id;
/* 6) Do NOT delete production display rows when latest LOR classifies a prop as SPARE.
      SPARE belongs in ref.spare_channel only.
      Conflicts must be reviewed manually. */
perform 1;

/* 7) Promote NON-SPARE into ref.display using 3-step logic
      A. Match existing rows by lor_prop_id
      B. Match remaining rows by display_name
      C. Insert anything still unmatched
*/
/* 7A) Update existing rows matched by lor_prop_id */
update
	ref.display d
set
	display_name = c.display_name,
	inventory_type = 'LOR',
	display_status_id = v_active_status_id,
	stage_id = s.stage_id,
	string_type = c.string_type,
	color = c.color,
	updated_at = now(),
	updated_by = current_user
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and d.lor_prop_id = c.lor_prop_id;

/* 7B assumes latest tmp_classified has at most one NON-SPARE row per display_name.
   Run duplicate-name preflight before calling p2. */
update
	ref.display d
set
	lor_prop_id = c.lor_prop_id,
	inventory_type = 'LOR',
	display_status_id = v_active_status_id,
	stage_id = s.stage_id,
	string_type = c.string_type,
	color = c.color,
	updated_at = now(),
	updated_by = current_user
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and upper(btrim(d.display_name)) = upper(btrim(c.display_name))
	and not exists (
	select
		1
	from
		ref.display d2
	where
		d2.lor_prop_id = c.lor_prop_id
  );

/* 7C) Insert brand new rows
      only when neither lor_prop_id nor display_name already exists */
insert
	into
	ref.display (
    lor_prop_id,
	display_name,
	inventory_type,
	display_status_id,
	stage_id,
	string_type,
	color
)
select
	c.lor_prop_id,
	c.display_name,
	'LOR',
	v_active_status_id,
	s.stage_id,
	c.string_type,
	c.color
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and not exists (
	select
		1
	from
		ref.display d
	where
		d.lor_prop_id = c.lor_prop_id
  )
	and not exists (
	select
		1
	from
		ref.display d
	where
		upper(btrim(d.display_name)) = upper(btrim(c.display_name))
  );
end;

$_$;


--
-- TOC entry 5479 (class 0 OID 0)
-- Dependencies: 1005
-- Name: PROCEDURE p2_upsert_display_from_latest_lor(); Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON PROCEDURE ref.p2_upsert_display_from_latest_lor() IS '/* ============================================================
Procedure: ref.p2_upsert_display_from_latest_lor()

Purpose:
  Upsert NON-SPARE displays into ref.display from latest LOR snapshot.
  Route SPARE items into ref.spare_channel.
  Ensure NO SPARE rows remain in ref.display for latest run set.

Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
  2026-03-01 GAL  Add string_type + color (LOR-owned) to ref.display + ref.spare_channel.
  2026-03-17  GAL  Revise non-SPARE promotion logic to match by lor_prop_id first, then by display_name, then insert new rows.
============================================================ */';


--
-- TOC entry 554 (class 1255 OID 19143)
-- Name: resolve_actor(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.resolve_actor() RETURNS TABLE(person_id integer, actor_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_directus_uuid text;
BEGIN
    v_directus_uuid := current_setting('app.directus_user_uuid', true);

    -- 1) Directus user
    IF v_directus_uuid IS NOT NULL AND btrim(v_directus_uuid) <> '' THEN
        SELECT p.person_id, p.preferred_name
        INTO person_id, actor_name
        FROM ref.person p
        WHERE p.directus_user_id::text = v_directus_uuid
        LIMIT 1;

        IF person_id IS NOT NULL THEN
            RETURN NEXT;
            RETURN;
        END IF;
    END IF;

    -- 2) PostgreSQL mapped login
    SELECT p.person_id, p.preferred_name
    INTO person_id, actor_name
    FROM ref.person p
    WHERE p.pg_login_name = current_user
    LIMIT 1;

    IF person_id IS NOT NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    -- 3) fallback
    person_id := NULL;
    actor_name := current_user;

    RETURN NEXT;
    RETURN;
END;
$$;


--
-- TOC entry 1141 (class 1255 OID 19141)
-- Name: set_actor_on_insert(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.set_actor_on_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN

    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.created_at := COALESCE(NEW.created_at, now());
    NEW.updated_at := COALESCE(NEW.updated_at, NEW.created_at);

    NEW.created_by := COALESCE(NEW.created_by, v_actor_name);
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);

    IF to_jsonb(NEW) ? 'created_by_person_id' THEN
        NEW.created_by_person_id := COALESCE(NEW.created_by_person_id, v_person_id);
    END IF;

    IF to_jsonb(NEW) ? 'updated_by_person_id' THEN
        NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);
    END IF;

    RETURN NEW;

END;
$$;


--
-- TOC entry 1068 (class 1255 OID 19173)
-- Name: set_actor_on_update(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.set_actor_on_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();

    /*
      Preserve values already stamped by Directus.
      Only fall back to DB actor resolution if those fields are still null.
    */
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);

    IF to_jsonb(NEW) ? 'updated_by_person_id' THEN
        NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);
    END IF;

    /*
      Hard fail only if this table has updated_by_person_id and it is still null
      after both Directus stamping and DB fallback resolution.
    */
    IF to_jsonb(NEW) ? 'updated_by_person_id'
       AND NEW.updated_by_person_id IS NULL THEN
        RAISE EXCEPTION
            'Audit actor resolution failed for %.% during update',
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 1181 (class 1255 OID 19111)
-- Name: set_audit_fields(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.set_audit_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := current_user;
    RETURN NEW;
END;
$$;


--
-- TOC entry 408 (class 1255 OID 16703)
-- Name: set_frame_updated_fields(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.set_frame_updated_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.updated_at := now();
    new.updated_by := current_user;
    return new;
end;
$$;


--
-- TOC entry 879 (class 1255 OID 16722)
-- Name: set_updated_fields(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.set_updated_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();

    -- Respect values already stamped by Directus; otherwise fallback to DB actor resolution
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);
    NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);

    RETURN NEW;
END;
$$;


--
-- TOC entry 556 (class 1255 OID 19847)
-- Name: sync_audit_collection_policy(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.sync_audit_collection_policy() RETURNS TABLE(action_taken text, schema_name text, collection_name text, checked_actor_enabled boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH base_tables AS (
        SELECT
            t.table_schema,
            t.table_name
        FROM information_schema.tables t
        WHERE t.table_type = 'BASE TABLE'
          AND t.table_schema IN ('ref', 'ops', 'stage')
          AND t.table_schema <> 'lor_snap'
    ),
    audit_columns AS (
        SELECT
            c.table_schema,
            c.table_name,
            bool_or(c.column_name = 'created_by')           AS has_created_by,
            bool_or(c.column_name = 'created_by_person_id') AS has_created_by_person_id,
            bool_or(c.column_name = 'updated_by')           AS has_updated_by,
            bool_or(c.column_name = 'updated_by_person_id') AS has_updated_by_person_id,
            bool_or(c.column_name = 'checked_by')           AS has_checked_by,
            bool_or(c.column_name = 'checked_by_person_id') AS has_checked_by_person_id
        FROM information_schema.columns c
        WHERE c.table_schema IN ('ref', 'ops', 'stage')
        GROUP BY
            c.table_schema,
            c.table_name
    ),
    eligible_tables AS (
        SELECT
            bt.table_schema,
            bt.table_name,
            ac.has_checked_by,
            ac.has_checked_by_person_id
        FROM base_tables bt
        JOIN audit_columns ac
          ON ac.table_schema = bt.table_schema
         AND ac.table_name   = bt.table_name
        WHERE ac.has_created_by
          AND ac.has_created_by_person_id
          AND ac.has_updated_by
          AND ac.has_updated_by_person_id
    ),
    inserted_rows AS (
        INSERT INTO ref.audit_collection_policy (
            schema_name,
            collection_name,
            insert_actor_enabled,
            update_actor_enabled,
            checked_actor_enabled,
            active_flag,
            notes
        )
        SELECT
            e.table_schema,
            e.table_name,
            true,
            true,
            (e.has_checked_by AND e.has_checked_by_person_id),
            true,
            'Auto-added by ref.sync_audit_collection_policy()'
        FROM eligible_tables e
        WHERE NOT EXISTS (
            SELECT 1
            FROM ref.audit_collection_policy p
            WHERE p.schema_name = e.table_schema
              AND p.collection_name = e.table_name
        )
        RETURNING
            'INSERTED'::text,
            ref.audit_collection_policy.schema_name,
            ref.audit_collection_policy.collection_name,
            ref.audit_collection_policy.checked_actor_enabled
    )
    SELECT *
    FROM inserted_rows
    ORDER BY 2, 3;
END;
$$;


--
-- TOC entry 5480 (class 0 OID 0)
-- Dependencies: 556
-- Name: FUNCTION sync_audit_collection_policy(); Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON FUNCTION ref.sync_audit_collection_policy() IS '/*
===============================================================================
ref.sync_audit_collection_policy()
-------------------------------------------------------------------------------
Purpose
-------------------------------------------------------------------------------
Synchronize the governance table ref.audit_collection_policy with actual
application tables that support actor-based audit stamping.

This function detects tables that are structurally capable of audit stamping
(because they contain the required audit columns) and inserts missing policy
rows using the system’s standard defaults.

It is intended to eliminate manual errors when onboarding new tables and to
prevent Directus audit hooks from silently skipping collections.

-------------------------------------------------------------------------------
Why this exists
-------------------------------------------------------------------------------
If a table is not present in ref.audit_collection_policy:

• Directus actor-stamping hooks will skip it
• Database triggers may fail or behave inconsistently
• NOT NULL violations can occur for audit columns
• Audit history becomes incomplete or incorrect

This function closes that governance gap.

-------------------------------------------------------------------------------
Scope of tables considered
-------------------------------------------------------------------------------
Only BASE TABLES in the following schemas are evaluated:

  ref
  ops
  stage

The ingestion schema lor_snap is intentionally excluded because those tables:

• Are system-generated snapshots
• Do not contain actor audit columns
• Are not edited by users
• Should never participate in actor stamping

Views, foreign tables, and system schemas are ignored.

-------------------------------------------------------------------------------
Eligibility requirements for inclusion
-------------------------------------------------------------------------------
A table is added ONLY if it physically contains ALL of the following columns:

  created_by
  created_by_person_id
  updated_by
  updated_by_person_id

This ensures that only audit-capable tables are enrolled.

Tables lacking these columns are skipped automatically.

-------------------------------------------------------------------------------
Checked actor behavior
-------------------------------------------------------------------------------
checked_actor_enabled is set to TRUE only if the table ALSO contains:

  checked_by
  checked_by_person_id

This supports specialized workflows (e.g., testing validation) while keeping
the default simple for all other tables.

-------------------------------------------------------------------------------
Defaults applied to newly inserted policy rows
-------------------------------------------------------------------------------
insert_actor_enabled  = TRUE
update_actor_enabled  = TRUE
checked_actor_enabled = TRUE only when checked columns exist
active_flag           = TRUE
notes                 = Auto-added by sync procedure

These defaults reflect the system’s standard audit policy.

-------------------------------------------------------------------------------
Safety guarantees
-------------------------------------------------------------------------------
• Existing rows are NEVER modified
• Only missing rows are inserted
• No audit behavior is changed for existing tables
• Safe to run repeatedly (idempotent)
• Safe to include in deployment scripts

-------------------------------------------------------------------------------
When to run
-------------------------------------------------------------------------------
Run after any schema change that introduces new application tables:

  • Creating new tables
  • Restoring a database
  • Applying migrations
  • Importing structures from development
  • Suspected policy drift

If the function returns zero rows, the system is already in sync.

-------------------------------------------------------------------------------
Usage
-------------------------------------------------------------------------------
SELECT * FROM ref.sync_audit_collection_policy();

The result shows newly inserted policy rows.

-------------------------------------------------------------------------------
Author
-------------------------------------------------------------------------------
MSB Production Database — Governance Utility
Created: 2026-03-11

===============================================================================
*/';


--
-- TOC entry 565 (class 1255 OID 19299)
-- Name: sync_container_search_helper_to_test_session(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.sync_container_search_helper_to_test_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE ops.test_session ts
     SET container_search_helper = LEFT(NEW.description, 20)
   WHERE ts.container_id = NEW.container_id;

  RETURN NEW;
END;
$$;


--
-- TOC entry 650 (class 1255 OID 16804)
-- Name: tg_touch_row(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.tg_touch_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  new.updated_by := current_user;
  return new;
end;
$$;


--
-- TOC entry 940 (class 1255 OID 18154)
-- Name: trg_set_updated(); Type: FUNCTION; Schema: ref; Owner: -
--

CREATE FUNCTION ref.trg_set_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  new.updated_by := current_user;
  return new;
end;
$$;


--
-- TOC entry 993 (class 1255 OID 20043)
-- Name: p_process_work_order_intake(bigint); Type: FUNCTION; Schema: stage; Owner: -
--

CREATE FUNCTION stage.p_process_work_order_intake(p_intake_id bigint) RETURNS TABLE(action_taken text, new_work_order_id bigint, assignee_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_woi               stage.work_order_intake%ROWTYPE;
    v_new_work_order_id bigint;
    v_problem           text;
    v_notes             text;
    v_photo_url         text;
    v_triage_notes      text;
BEGIN
    SELECT *
      INTO v_woi
      FROM stage.work_order_intake
     WHERE intake_id = p_intake_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'WOI % not found', p_intake_id;
    END IF;

    v_woi.triage_dropdown := nullif(btrim(v_woi.triage_dropdown), '');

    v_problem      := nullif(btrim(v_woi.problem_raw), '');
    v_notes        := nullif(btrim(v_woi.notes_raw), '');
    v_photo_url    := nullif(btrim(v_woi.photo_url_raw), '');
    v_triage_notes := nullif(btrim(v_woi.triage_notes), '');

    IF v_woi.triage_dropdown = '1' THEN
        action_taken := 'NO_ACTION_SUBMITTED';
        new_work_order_id := NULL;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_woi.triage_dropdown = '4' THEN
        DELETE FROM stage.work_order_intake
         WHERE intake_id = v_woi.intake_id;

        action_taken := 'DENIED_DELETED';
        new_work_order_id := NULL;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_woi.triage_dropdown = '3' THEN

        IF v_problem IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: problem statement is required', v_woi.intake_id;
        END IF;

        IF char_length(v_problem) > 255 THEN
            RAISE EXCEPTION 'Cannot promote WOI %: problem statement must be 255 characters or less', v_woi.intake_id;
        END IF;

        IF v_woi.urgency_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: urgency_id is required', v_woi.intake_id;
        END IF;

        IF v_woi.task_type_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: task_type_id is required', v_woi.intake_id;
        END IF;

        IF v_woi.stage_id IS NULL AND v_woi.work_area_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: stage_id or work_area_id is required', v_woi.intake_id;
        END IF;

        INSERT INTO ops.work_order (
            stage_id,
            work_area_id,
            task_type_id,
            urgency_id,
            target_year,
            problem,
            notes,
            photo_url,
            source_intake_id,
            source_system,
            source_form_name,
            submitted_by_person_id,
            submitted_at,
            triaged_at,
            triaged_by_person_id,
            triage_notes,
            created_by_person_id,
            updated_by_person_id,
            created_by,
            updated_by
        )
        VALUES (
            v_woi.stage_id,
            v_woi.work_area_id,
            v_woi.task_type_id,
            v_woi.urgency_id,
            v_woi.target_year,
            v_problem,
            v_notes,
            v_photo_url,
            v_woi.intake_id,
            v_woi.source_system,
            v_woi.source_form_name,
            v_woi.submitter_person_id,
            v_woi.submitted_at,
            v_woi.triaged_at,
            v_woi.triaged_by_person_id,
            v_triage_notes,
            COALESCE(v_woi.updated_by_person_id, v_woi.created_by_person_id),
            COALESCE(v_woi.updated_by_person_id, v_woi.created_by_person_id),
            COALESCE(v_woi.updated_by, v_woi.created_by, current_user),
            COALESCE(v_woi.updated_by, v_woi.created_by, current_user)
        )
        RETURNING work_order_id
          INTO v_new_work_order_id;

        DELETE FROM stage.work_order_intake
         WHERE intake_id = v_woi.intake_id;

        action_taken := 'APPROVED_PROMOTED';
        new_work_order_id := v_new_work_order_id;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    RAISE EXCEPTION
        'Cannot process WOI %: unsupported triage_dropdown value = %',
        v_woi.intake_id,
        v_woi.triage_dropdown;
END;
$$;


--
-- TOC entry 413 (class 1255 OID 17172)
-- Name: reset_display_sheet(); Type: PROCEDURE; Schema: stage; Owner: -
--

CREATE PROCEDURE stage.reset_display_sheet()
    LANGUAGE plpgsql
    AS $$/*
reset_display_sheet
*/
begin
  truncate table stage.display_sheet_csv;
  truncate table stage.display_sheet_raw;
end;
$$;


--
-- TOC entry 1130 (class 1255 OID 20086)
-- Name: tf_process_work_order_intake_on_triage(); Type: FUNCTION; Schema: stage; Owner: -
--

CREATE FUNCTION stage.tf_process_work_order_intake_on_triage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.triage_dropdown IS DISTINCT FROM OLD.triage_dropdown
       AND NEW.triage_dropdown IS NOT NULL
    THEN
        IF NEW.triage_dropdown = '1' THEN
            RETURN NEW;
        END IF;

        PERFORM *
        FROM stage.p_process_work_order_intake(NEW.intake_id);

        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 1020 (class 1255 OID 20097)
-- Name: tf_resolve_work_order_intake_submitter(); Type: FUNCTION; Schema: stage; Owner: -
--

CREATE FUNCTION stage.tf_resolve_work_order_intake_submitter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_email_norm text;
    v_person_id  bigint;
BEGIN
    IF NEW.submitter_person_id IS NOT NULL THEN
        RETURN NEW;
    END IF;

    v_email_norm := lower(nullif(btrim(NEW.submitter_email_raw), ''));

    IF v_email_norm IS NOT NULL THEN
        SELECT p.person_id
          INTO v_person_id
          FROM ref.person p
         WHERE lower(nullif(btrim(p.email), '')) = v_email_norm
         ORDER BY p.person_id
         LIMIT 1;

        IF v_person_id IS NOT NULL THEN
            NEW.submitter_person_id := v_person_id;
            RETURN NEW;
        END IF;
    END IF;

    IF NEW.created_by_person_id IS NOT NULL THEN
        NEW.submitter_person_id := NEW.created_by_person_id;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 691 (class 1255 OID 17139)
-- Name: transform_display_sheet_csv_to_raw(); Type: PROCEDURE; Schema: stage; Owner: -
--

CREATE PROCEDURE stage.transform_display_sheet_csv_to_raw()
    LANGUAGE plpgsql
    AS $$/*
transform_display_sheet_scv_to_raw
*/
begin
  truncate table stage.display_sheet_raw;

  insert into stage.display_sheet_raw (
    display_name,
    inventory_type,
    display_status,
    designer_name,
    theme_name,
    frame_name,
    pallet_id_raw,
    year_built,
    amps_measured,
    est_light_count,
    dumb_controller,
    notes
  )
  select
    nullif(btrim(display_name),''),
    nullif(btrim(inventory_type),''),
    nullif(btrim(display_status),''),

    nullif(btrim(designer_id),'') as designer_name,
    nullif(btrim(theme_id),'')    as theme_name,
    nullif(btrim(frame_id),'')    as frame_name,

    nullif(btrim(pallet_id),'')   as pallet_id_raw,

    nullif(regexp_replace(btrim(coalesce(year_built,'')), '[^0-9]', '', 'g'), '')::integer,
    nullif(regexp_replace(btrim(coalesce(amps_measured,'')), '[^0-9\.]', '', 'g'), '')::numeric(8,2),
    nullif(regexp_replace(btrim(coalesce(est_light_count,'')), '[^0-9]', '', 'g'), '')::integer,

    nullif(btrim(dumb_controller),''),
    nullif(btrim(notes),'')
  from stage.display_sheet_csv
  where
    nullif(btrim(display_name),'') is not null
    and upper(coalesce(nullif(btrim(inventory_type),''), 'LOR')) <> 'IGNORE';
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 268 (class 1259 OID 16821)
-- Name: container; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.container (
    container_id integer NOT NULL,
    location_code text,
    container_type_id integer NOT NULL,
    description text,
    is_stackable_override boolean,
    year_built integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    width_in_override integer,
    depth_in_override integer,
    height_in_override integer,
    goes_to text,
    display_pallet boolean,
    testing_after_takedown boolean,
    display_pallet_flag boolean,
    goes_to_endpoint_id integer,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    label_required boolean DEFAULT true NOT NULL,
    print_label boolean DEFAULT false NOT NULL,
    label_print_count_cached integer DEFAULT 0 NOT NULL,
    label_print_last_at_cached timestamp with time zone,
    label_print_last_by_cached_id integer
);


--
-- TOC entry 5481 (class 0 OID 0)
-- Dependencies: 268
-- Name: COLUMN container.label_required; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.container.label_required IS 'Indicates whether this container represents a physical asset that requires printed labels.';


--
-- TOC entry 5482 (class 0 OID 0)
-- Dependencies: 268
-- Name: COLUMN container.print_label; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.container.print_label IS 'Operator action flag. Set true to request label printing. Cleared by print service after confirmed successful print and history write.';


--
-- TOC entry 5483 (class 0 OID 0)
-- Dependencies: 268
-- Name: COLUMN container.label_print_count_cached; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.container.label_print_count_cached IS 'System-maintained cached count of labels printed for this container. Derived from label batch history.';


--
-- TOC entry 5484 (class 0 OID 0)
-- Dependencies: 268
-- Name: COLUMN container.label_print_last_at_cached; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.container.label_print_last_at_cached IS 'System-maintained cached timestamp of the most recent successful label print for this container.';


--
-- TOC entry 277 (class 1259 OID 17051)
-- Name: display; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display (
    lor_prop_id text NOT NULL,
    display_name text NOT NULL,
    inventory_type text NOT NULL,
    display_status_id integer NOT NULL,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    stage_id integer,
    display_id bigint NOT NULL,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    label_required boolean DEFAULT true NOT NULL,
    print_label boolean DEFAULT false NOT NULL,
    label_print_count_cached integer DEFAULT 0 NOT NULL,
    label_print_last_at_cached timestamp with time zone,
    label_print_last_by_cached_id integer
);


--
-- TOC entry 5485 (class 0 OID 0)
-- Dependencies: 277
-- Name: COLUMN display.label_required; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.display.label_required IS 'Indicates whether this display represents a physical asset that requires a printed label.';


--
-- TOC entry 5486 (class 0 OID 0)
-- Dependencies: 277
-- Name: COLUMN display.print_label; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.display.print_label IS 'Operator action flag. Set true to request label printing. Cleared by print service after confirmed successful print and history write.';


--
-- TOC entry 5487 (class 0 OID 0)
-- Dependencies: 277
-- Name: COLUMN display.label_print_count_cached; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.display.label_print_count_cached IS 'System-maintained cached count of labels printed for this display. Derived from label batch history.';


--
-- TOC entry 5488 (class 0 OID 0)
-- Dependencies: 277
-- Name: COLUMN display.label_print_last_at_cached; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON COLUMN ref.display.label_print_last_at_cached IS 'System-maintained cached timestamp of the most recent successful label print for this display.';


--
-- TOC entry 243 (class 1259 OID 16457)
-- Name: dmx_channels; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.dmx_channels (
    import_run_id bigint NOT NULL,
    int_dmx_channel_id bigint NOT NULL,
    prop_id text,
    network text,
    start_universe integer,
    start_channel integer,
    end_channel integer,
    unknown text,
    preview_id text
);


--
-- TOC entry 239 (class 1259 OID 16391)
-- Name: import_run; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.import_run (
    import_run_id bigint NOT NULL,
    run_ts timestamp with time zone DEFAULT now() NOT NULL,
    notes text
);


--
-- TOC entry 238 (class 1259 OID 16390)
-- Name: import_run_import_run_id_seq; Type: SEQUENCE; Schema: lor_snap; Owner: -
--

CREATE SEQUENCE lor_snap.import_run_import_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5489 (class 0 OID 0)
-- Dependencies: 238
-- Name: import_run_import_run_id_seq; Type: SEQUENCE OWNED BY; Schema: lor_snap; Owner: -
--

ALTER SEQUENCE lor_snap.import_run_import_run_id_seq OWNED BY lor_snap.import_run.import_run_id;


--
-- TOC entry 240 (class 1259 OID 16400)
-- Name: previews; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.previews (
    import_run_id bigint NOT NULL,
    int_preview_id bigint NOT NULL,
    id text NOT NULL,
    stage_id text,
    name text,
    revision text,
    brightness double precision,
    background_file text
);


--
-- TOC entry 241 (class 1259 OID 16414)
-- Name: props; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.props (
    import_run_id bigint NOT NULL,
    int_prop_id bigint NOT NULL,
    prop_id text NOT NULL,
    name text,
    lor_comment text,
    device_type text,
    bulb_shape text,
    network text,
    uid text,
    start_channel integer,
    end_channel integer,
    unknown text,
    color text,
    custom_bulb_color text,
    dimming_curve_name text,
    individual_channels boolean,
    legacy_sequence_method text,
    max_channels integer,
    opacity double precision,
    master_dimmable boolean,
    preview_bulb_size double precision,
    master_prop_id text,
    separate_ids boolean,
    start_location text,
    string_type text,
    traditional_colors text,
    traditional_type text,
    effect_bulb_size double precision,
    tag text,
    parm1 text,
    parm2 text,
    parm3 text,
    parm4 text,
    parm5 text,
    parm6 text,
    parm7 text,
    parm8 text,
    lights integer,
    preview_id text
);


--
-- TOC entry 242 (class 1259 OID 16433)
-- Name: sub_props; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.sub_props (
    import_run_id bigint NOT NULL,
    int_sub_prop_id bigint NOT NULL,
    sub_prop_id text NOT NULL,
    name text,
    lor_comment text,
    device_type text,
    bulb_shape text,
    network text,
    uid text,
    start_channel integer,
    end_channel integer,
    unknown text,
    color text,
    custom_bulb_color text,
    dimming_curve_name text,
    individual_channels boolean,
    legacy_sequence_method text,
    max_channels integer,
    opacity double precision,
    master_dimmable boolean,
    preview_bulb_size double precision,
    rgb_order text,
    master_prop_id text,
    separate_ids boolean,
    start_location text,
    string_type text,
    traditional_colors text,
    traditional_type text,
    effect_bulb_size double precision,
    tag text,
    parm1 text,
    parm2 text,
    parm3 text,
    parm4 text,
    parm5 text,
    parm6 text,
    parm7 text,
    parm8 text,
    lights integer,
    preview_id text
);


--
-- TOC entry 244 (class 1259 OID 16479)
-- Name: v_current_run; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_run AS
 SELECT import_run_id,
    run_ts,
    notes
   FROM lor_snap.import_run ir
  ORDER BY import_run_id DESC
 LIMIT 1;


--
-- TOC entry 248 (class 1259 OID 16497)
-- Name: v_current_dmx_channels; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_dmx_channels AS
 SELECT dc.import_run_id,
    dc.int_dmx_channel_id,
    dc.prop_id,
    dc.network,
    dc.start_universe,
    dc.start_channel,
    dc.end_channel,
    dc.unknown,
    dc.preview_id
   FROM (lor_snap.dmx_channels dc
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = dc.import_run_id)));


--
-- TOC entry 245 (class 1259 OID 16483)
-- Name: v_current_previews; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_previews AS
 SELECT p.import_run_id,
    p.int_preview_id,
    p.id,
    p.stage_id,
    p.name,
    p.revision,
    p.brightness,
    p.background_file
   FROM (lor_snap.previews p
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = p.import_run_id)));


--
-- TOC entry 246 (class 1259 OID 16487)
-- Name: v_current_props; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_props AS
 SELECT p.import_run_id,
    p.int_prop_id,
    p.prop_id,
    p.name,
    p.lor_comment,
    p.device_type,
    p.bulb_shape,
    p.network,
    p.uid,
    p.start_channel,
    p.end_channel,
    p.unknown,
    p.color,
    p.custom_bulb_color,
    p.dimming_curve_name,
    p.individual_channels,
    p.legacy_sequence_method,
    p.max_channels,
    p.opacity,
    p.master_dimmable,
    p.preview_bulb_size,
    p.master_prop_id,
    p.separate_ids,
    p.start_location,
    p.string_type,
    p.traditional_colors,
    p.traditional_type,
    p.effect_bulb_size,
    p.tag,
    p.parm1,
    p.parm2,
    p.parm3,
    p.parm4,
    p.parm5,
    p.parm6,
    p.parm7,
    p.parm8,
    p.lights,
    p.preview_id
   FROM (lor_snap.props p
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = p.import_run_id)));


--
-- TOC entry 247 (class 1259 OID 16492)
-- Name: v_current_sub_props; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_sub_props AS
 SELECT sp.import_run_id,
    sp.int_sub_prop_id,
    sp.sub_prop_id,
    sp.name,
    sp.lor_comment,
    sp.device_type,
    sp.bulb_shape,
    sp.network,
    sp.uid,
    sp.start_channel,
    sp.end_channel,
    sp.unknown,
    sp.color,
    sp.custom_bulb_color,
    sp.dimming_curve_name,
    sp.individual_channels,
    sp.legacy_sequence_method,
    sp.max_channels,
    sp.opacity,
    sp.master_dimmable,
    sp.preview_bulb_size,
    sp.rgb_order,
    sp.master_prop_id,
    sp.separate_ids,
    sp.start_location,
    sp.string_type,
    sp.traditional_colors,
    sp.traditional_type,
    sp.effect_bulb_size,
    sp.tag,
    sp.parm1,
    sp.parm2,
    sp.parm3,
    sp.parm4,
    sp.parm5,
    sp.parm6,
    sp.parm7,
    sp.parm8,
    sp.lights,
    sp.preview_id
   FROM (lor_snap.sub_props sp
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = sp.import_run_id)));


--
-- TOC entry 249 (class 1259 OID 16509)
-- Name: preview_wiring_map_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_map_v6 AS
 SELECT pv.name AS preview_name,
    replace(btrim(p.lor_comment), ' '::text, '-'::text) AS display_name,
    p.name AS lor_name,
    p.network,
    p.uid AS controller,
    p.start_channel,
    p.end_channel,
    p.device_type,
    'PROP'::text AS source,
    p.tag AS lor_tag
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE ((p.network IS NOT NULL) AND (p.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.name AS preview_name,
    replace(btrim(COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment)), ' '::text, '-'::text) AS display_name,
    sp.name AS lor_name,
    sp.network,
    sp.uid AS controller,
    sp.start_channel,
    sp.end_channel,
    COALESCE(sp.device_type, 'LOR'::text) AS device_type,
    'SUBPROP'::text AS source,
    sp.tag AS lor_tag
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
UNION ALL
 SELECT pv.name AS preview_name,
    replace(btrim(p.lor_comment), ' '::text, '-'::text) AS display_name,
    p.name AS lor_name,
    dc.network,
    (dc.start_universe)::text AS controller,
    dc.start_channel,
    dc.end_channel,
    'DMX'::text AS device_type,
    'DMX'::text AS source,
    p.tag AS lor_tag
   FROM ((lor_snap.v_current_dmx_channels dc
     JOIN lor_snap.v_current_props p ON ((p.prop_id = dc.prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)));


--
-- TOC entry 250 (class 1259 OID 16514)
-- Name: preview_wiring_sorted_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_sorted_v6 AS
 SELECT preview_name,
    display_name,
    lor_name,
    network,
    controller,
    start_channel,
    end_channel,
    device_type,
    source,
    lor_tag
   FROM lor_snap.preview_wiring_map_v6
  ORDER BY (lower(preview_name)), (lower(display_name)), controller, start_channel;


--
-- TOC entry 251 (class 1259 OID 16518)
-- Name: preview_wiring_fieldmap_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_fieldmap_v6 AS
 WITH map AS (
         SELECT m.preview_name,
            m.source,
            m.lor_name AS channel_name,
            m.display_name,
            m.network,
            m.controller,
            m.start_channel,
            m.end_channel,
                CASE
                    WHEN (m.device_type = 'DMX'::text) THEN 'RGB'::text
                    ELSE NULL::text
                END AS color,
            m.device_type,
            m.lor_tag
           FROM lor_snap.preview_wiring_sorted_v6 m
          WHERE ((m.controller IS NOT NULL) AND (m.start_channel IS NOT NULL) AND (m.device_type <> 'None'::text))
        ), ranked AS (
         SELECT map.preview_name,
            map.source,
            map.channel_name,
            map.display_name,
            map.network,
            map.controller,
            map.start_channel,
            map.end_channel,
            map.color,
            map.device_type,
            map.lor_tag,
            row_number() OVER (PARTITION BY map.preview_name, map.network, map.controller, map.start_channel, map.display_name ORDER BY (map.source = 'PROP'::text) DESC, (lower(map.channel_name))) AS lead_rank
           FROM map
        ), span AS (
         SELECT ranked.preview_name,
            ranked.source,
            ranked.channel_name,
            ranked.display_name,
            ranked.network,
            ranked.controller,
            ranked.start_channel,
            ranked.end_channel,
            ranked.color,
            ranked.device_type,
            ranked.lor_tag,
            ranked.lead_rank,
            sum(
                CASE
                    WHEN (ranked.lead_rank = 1) THEN 1
                    ELSE 0
                END) OVER (PARTITION BY ranked.preview_name, ranked.network, ranked.controller, ranked.start_channel) AS display_span
           FROM ranked
        )
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
        CASE
            WHEN (lead_rank = 1) THEN 'FIELD'::text
            ELSE 'INTERNAL'::text
        END AS connection_type,
        CASE
            WHEN (display_span > 1) THEN 1
            ELSE 0
        END AS cross_display
   FROM span;


--
-- TOC entry 252 (class 1259 OID 16523)
-- Name: preview_wiring_fieldlead_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_fieldlead_v6 AS
 WITH ranked AS (
         SELECT f.preview_name,
            f.source,
            f.channel_name,
            f.display_name,
            f.network,
            f.controller,
            f.start_channel,
            f.end_channel,
            f.color,
            f.device_type,
            f.lor_tag,
            f.connection_type,
            f.cross_display,
            row_number() OVER (PARTITION BY f.preview_name, f.network, f.controller, f.start_channel, f.display_name ORDER BY (f.source = 'PROP'::text) DESC, (lower(f.channel_name))) AS lead_rank
           FROM lor_snap.preview_wiring_fieldmap_v6 f
        )
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
    connection_type,
    cross_display,
    lead_rank
   FROM ranked
  WHERE (lead_rank = 1);


--
-- TOC entry 253 (class 1259 OID 16528)
-- Name: preview_wiring_circuit_rollup_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_circuit_rollup_v6 AS
 SELECT preview_name,
    network,
    controller,
    start_channel,
    count(*) AS display_count,
    string_agg(display_name, ' | '::text ORDER BY (lower(display_name))) AS displays
   FROM lor_snap.preview_wiring_fieldlead_v6
  GROUP BY preview_name, network, controller, start_channel
  ORDER BY network,
        CASE
            WHEN (controller ~* '^[0-9a-f]+$'::text) THEN ((('x'::text || controller))::bit(32))::integer
            ELSE NULL::integer
        END, controller, start_channel;


--
-- TOC entry 254 (class 1259 OID 16532)
-- Name: preview_wiring_fieldonly_v6; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.preview_wiring_fieldonly_v6 AS
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
    connection_type,
    cross_display
   FROM lor_snap.preview_wiring_fieldmap_v6
  WHERE (connection_type = 'FIELD'::text);


--
-- TOC entry 402 (class 1259 OID 23021)
-- Name: scene_lor_props; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.scene_lor_props (
    import_run_id integer NOT NULL,
    int_scene_prop_id integer,
    preview_id text NOT NULL,
    prop_id text NOT NULL,
    raw_prop_id text NOT NULL,
    scene_id text,
    preview_stage_id text,
    scene_stage_id text,
    scene_prop_ordinal integer,
    scene_role text,
    source text
);


--
-- TOC entry 401 (class 1259 OID 23011)
-- Name: scenes; Type: TABLE; Schema: lor_snap; Owner: -
--

CREATE TABLE lor_snap.scenes (
    import_run_id integer NOT NULL,
    int_scene_id integer,
    scene_id text,
    preview_id text,
    stage_id text,
    name text,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text
);


--
-- TOC entry 255 (class 1259 OID 16548)
-- Name: stage_display_assets_v1; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.stage_display_assets_v1 AS
 SELECT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    p.name AS channel_name,
    COALESCE(p.device_type, 'LOR'::text) AS device_type,
    p.network,
    p.uid,
    p.start_channel,
    p.end_channel,
    1 AS has_wiring,
    'PROP'::text AS source
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE ((p.network IS NOT NULL) AND (p.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.stage_id,
    pv.name AS preview_name,
    COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment) AS display_name,
    sp.name AS channel_name,
    COALESCE(sp.device_type, 'LOR'::text) AS device_type,
    sp.network,
    sp.uid,
    sp.start_channel,
    sp.end_channel,
    1 AS has_wiring,
    'SUBPROP'::text AS source
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
  WHERE ((sp.network IS NOT NULL) AND (sp.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    p.name AS channel_name,
    'DMX'::text AS device_type,
    dc.network,
    (dc.start_universe)::text AS uid,
    dc.start_channel,
    dc.end_channel,
    1 AS has_wiring,
    'DMX'::text AS source
   FROM ((lor_snap.v_current_dmx_channels dc
     JOIN lor_snap.v_current_props p ON ((p.prop_id = dc.prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)));


--
-- TOC entry 256 (class 1259 OID 16553)
-- Name: stage_display_inventory_only_v1; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.stage_display_inventory_only_v1 AS
 SELECT DISTINCT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    NULL::text AS channel_name,
    COALESCE(p.device_type, 'INV'::text) AS device_type,
    NULL::text AS network,
    NULL::text AS uid,
    NULL::integer AS start_channel,
    NULL::integer AS end_channel,
    0 AS has_wiring,
    'PROP_INV'::text AS source
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE (((p.network IS NULL) OR (p.start_channel IS NULL)) AND (btrim(COALESCE(p.lor_comment, ''::text)) <> ''::text))
UNION
 SELECT DISTINCT pv.stage_id,
    pv.name AS preview_name,
    COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment) AS display_name,
    NULL::text AS channel_name,
    COALESCE(sp.device_type, 'INV'::text) AS device_type,
    NULL::text AS network,
    NULL::text AS uid,
    NULL::integer AS start_channel,
    NULL::integer AS end_channel,
    0 AS has_wiring,
    'SUBPROP_INV'::text AS source
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
  WHERE (((sp.network IS NULL) OR (sp.start_channel IS NULL)) AND (btrim(COALESCE(COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment), ''::text)) <> ''::text));


--
-- TOC entry 257 (class 1259 OID 16558)
-- Name: stage_display_assets_all_v1; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.stage_display_assets_all_v1 AS
 SELECT stage_display_assets_v1.stage_id,
    stage_display_assets_v1.preview_name,
    stage_display_assets_v1.display_name,
    stage_display_assets_v1.channel_name,
    stage_display_assets_v1.device_type,
    stage_display_assets_v1.network,
    stage_display_assets_v1.uid,
    stage_display_assets_v1.start_channel,
    stage_display_assets_v1.end_channel,
    stage_display_assets_v1.has_wiring,
    stage_display_assets_v1.source
   FROM lor_snap.stage_display_assets_v1
UNION ALL
 SELECT stage_display_inventory_only_v1.stage_id,
    stage_display_inventory_only_v1.preview_name,
    stage_display_inventory_only_v1.display_name,
    stage_display_inventory_only_v1.channel_name,
    stage_display_inventory_only_v1.device_type,
    stage_display_inventory_only_v1.network,
    stage_display_inventory_only_v1.uid,
    stage_display_inventory_only_v1.start_channel,
    stage_display_inventory_only_v1.end_channel,
    stage_display_inventory_only_v1.has_wiring,
    stage_display_inventory_only_v1.source
   FROM lor_snap.stage_display_inventory_only_v1;


--
-- TOC entry 258 (class 1259 OID 16563)
-- Name: stage_display_list_all_v1; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.stage_display_list_all_v1 AS
 WITH base AS (
         SELECT COALESCE(stage_display_assets_all_v1.stage_id, 'Unassigned'::text) AS stage_bucket,
            stage_display_assets_all_v1.preview_name,
            btrim(stage_display_assets_all_v1.display_name) AS display_name,
            stage_display_assets_all_v1.has_wiring
           FROM lor_snap.stage_display_assets_all_v1
          WHERE (btrim(COALESCE(stage_display_assets_all_v1.display_name, ''::text)) <> ''::text)
        ), labeled AS (
         SELECT base.stage_bucket,
            ((base.stage_bucket || ' — '::text) || base.preview_name) AS stage_preview_label,
            base.display_name,
            base.has_wiring
           FROM base
        ), aggregated AS (
         SELECT labeled.stage_bucket,
            labeled.stage_preview_label,
            labeled.display_name,
            max(labeled.has_wiring) AS has_wiring
           FROM labeled
          GROUP BY labeled.stage_bucket, labeled.stage_preview_label, labeled.display_name
        )
 SELECT stage_bucket,
    stage_preview_label,
    display_name,
    has_wiring
   FROM aggregated
  ORDER BY
        CASE
            WHEN (stage_bucket = 'Unassigned'::text) THEN 1
            ELSE 0
        END, (length(stage_bucket)), stage_bucket,
        CASE
            WHEN (stage_preview_label ~~ '%Show Background Stage%'::text) THEN 0
            ELSE 1
        END,
        CASE
            WHEN (stage_preview_label ~~ '%RGB Plus Prop Stage%'::text) THEN 0
            ELSE 1
        END, (lower(stage_preview_label)), (lower(display_name));


--
-- TOC entry 259 (class 1259 OID 16568)
-- Name: stage_display_unassigned_v1; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.stage_display_unassigned_v1 AS
 SELECT display_name
   FROM lor_snap.stage_display_list_all_v1
  WHERE (stage_bucket = 'Unassigned'::text);


--
-- TOC entry 404 (class 1259 OID 23042)
-- Name: v_current_scene_lor_props; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_scene_lor_props AS
 SELECT import_run_id,
    int_scene_prop_id,
    preview_id,
    prop_id,
    raw_prop_id,
    scene_id,
    preview_stage_id,
    scene_stage_id,
    scene_prop_ordinal,
    scene_role,
    source
   FROM lor_snap.scene_lor_props slp
  WHERE (import_run_id = ( SELECT max(import_run.import_run_id) AS max
           FROM lor_snap.import_run));


--
-- TOC entry 403 (class 1259 OID 23038)
-- Name: v_current_scenes; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_current_scenes AS
 SELECT import_run_id,
    int_scene_id,
    scene_id,
    preview_id,
    stage_id,
    name,
    scene_section,
    background_file,
    h_scroll,
    v_scroll,
    zoom,
    create_grid_view
   FROM lor_snap.scenes s
  WHERE (import_run_id = ( SELECT max(import_run.import_run_id) AS max
           FROM lor_snap.import_run));


--
-- TOC entry 275 (class 1259 OID 16991)
-- Name: v_prop_identity; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_prop_identity AS
 SELECT import_run_id,
    prop_id,
    uid,
    device_type,
    lor_comment
   FROM lor_snap.props;


--
-- TOC entry 285 (class 1259 OID 17187)
-- Name: v_props_diff_latest_prev; Type: VIEW; Schema: lor_snap; Owner: -
--

CREATE VIEW lor_snap.v_props_diff_latest_prev AS
 WITH runs AS (
         SELECT ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run) AS run_new,
            ( SELECT (max(import_run.import_run_id) - 1)
                   FROM lor_snap.import_run) AS run_old
        ), newp AS (
         SELECT props.import_run_id,
            props.int_prop_id,
            props.prop_id,
            props.name,
            props.lor_comment,
            props.device_type,
            props.bulb_shape,
            props.network,
            props.uid,
            props.start_channel,
            props.end_channel,
            props.unknown,
            props.color,
            props.custom_bulb_color,
            props.dimming_curve_name,
            props.individual_channels,
            props.legacy_sequence_method,
            props.max_channels,
            props.opacity,
            props.master_dimmable,
            props.preview_bulb_size,
            props.master_prop_id,
            props.separate_ids,
            props.start_location,
            props.string_type,
            props.traditional_colors,
            props.traditional_type,
            props.effect_bulb_size,
            props.tag,
            props.parm1,
            props.parm2,
            props.parm3,
            props.parm4,
            props.parm5,
            props.parm6,
            props.parm7,
            props.parm8,
            props.lights,
            props.preview_id
           FROM lor_snap.props
          WHERE (props.import_run_id = ( SELECT runs.run_new
                   FROM runs))
        ), oldp AS (
         SELECT props.import_run_id,
            props.int_prop_id,
            props.prop_id,
            props.name,
            props.lor_comment,
            props.device_type,
            props.bulb_shape,
            props.network,
            props.uid,
            props.start_channel,
            props.end_channel,
            props.unknown,
            props.color,
            props.custom_bulb_color,
            props.dimming_curve_name,
            props.individual_channels,
            props.legacy_sequence_method,
            props.max_channels,
            props.opacity,
            props.master_dimmable,
            props.preview_bulb_size,
            props.master_prop_id,
            props.separate_ids,
            props.start_location,
            props.string_type,
            props.traditional_colors,
            props.traditional_type,
            props.effect_bulb_size,
            props.tag,
            props.parm1,
            props.parm2,
            props.parm3,
            props.parm4,
            props.parm5,
            props.parm6,
            props.parm7,
            props.parm8,
            props.lights,
            props.preview_id
           FROM lor_snap.props
          WHERE (props.import_run_id = ( SELECT runs.run_old
                   FROM runs))
        ), j AS (
         SELECT COALESCE(n.prop_id, o.prop_id) AS prop_id,
            (n.prop_id IS NOT NULL) AS in_new,
            (o.prop_id IS NOT NULL) AS in_old,
            n.lor_comment AS new_lor_comment,
            o.lor_comment AS old_lor_comment,
            n.device_type AS new_device_type,
            o.device_type AS old_device_type,
            n.start_channel AS new_start_channel,
            o.start_channel AS old_start_channel,
            n.end_channel AS new_end_channel,
            o.end_channel AS old_end_channel,
            n.network AS new_network,
            o.network AS old_network,
            n.uid AS new_uid,
            o.uid AS old_uid,
            n.name AS new_name,
            o.name AS old_name
           FROM (newp n
             FULL JOIN oldp o USING (prop_id))
        )
 SELECT
        CASE
            WHEN (in_new AND (NOT in_old)) THEN 'ADDED'::text
            WHEN (in_old AND (NOT in_new)) THEN 'REMOVED'::text
            WHEN (in_new AND in_old AND ((new_lor_comment IS DISTINCT FROM old_lor_comment) OR (new_device_type IS DISTINCT FROM old_device_type) OR (new_start_channel IS DISTINCT FROM old_start_channel) OR (new_end_channel IS DISTINCT FROM old_end_channel) OR (new_network IS DISTINCT FROM old_network) OR (new_uid IS DISTINCT FROM old_uid) OR (new_name IS DISTINCT FROM old_name))) THEN 'CHANGED'::text
            ELSE 'SAME'::text
        END AS change_type,
    prop_id,
    old_lor_comment,
    new_lor_comment,
    old_device_type,
    new_device_type,
    old_start_channel,
    new_start_channel,
    old_end_channel,
    new_end_channel,
    old_network,
    new_network,
    old_uid,
    new_uid,
    old_name,
    new_name
   FROM j
  WHERE (NOT (in_new AND in_old AND (NOT (new_lor_comment IS DISTINCT FROM old_lor_comment)) AND (NOT (new_device_type IS DISTINCT FROM old_device_type)) AND (NOT (new_start_channel IS DISTINCT FROM old_start_channel)) AND (NOT (new_end_channel IS DISTINCT FROM old_end_channel)) AND (NOT (new_network IS DISTINCT FROM old_network)) AND (NOT (new_uid IS DISTINCT FROM old_uid)) AND (NOT (new_name IS DISTINCT FROM old_name))));


--
-- TOC entry 393 (class 1259 OID 20710)
-- Name: container_label_batch; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.container_label_batch (
    container_label_batch_id bigint NOT NULL,
    batch_started_at timestamp with time zone DEFAULT now() NOT NULL,
    batch_completed_at timestamp with time zone,
    started_by_person_id integer,
    started_by_text text,
    status text DEFAULT 'PENDING'::text NOT NULL,
    notes text
);


--
-- TOC entry 392 (class 1259 OID 20709)
-- Name: container_label_batch_container_label_batch_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.container_label_batch_container_label_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5490 (class 0 OID 0)
-- Dependencies: 392
-- Name: container_label_batch_container_label_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.container_label_batch_container_label_batch_id_seq OWNED BY ops.container_label_batch.container_label_batch_id;


--
-- TOC entry 395 (class 1259 OID 20722)
-- Name: container_label_batch_item; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.container_label_batch_item (
    container_label_batch_item_id bigint NOT NULL,
    container_label_batch_id bigint NOT NULL,
    container_id integer NOT NULL,
    qr_url text,
    container_label text,
    label_orientation text NOT NULL,
    printed_flag boolean DEFAULT false NOT NULL,
    printed_at timestamp with time zone,
    container_type_id integer,
    CONSTRAINT ck_container_label_batch_item_orientation CHECK ((label_orientation = ANY (ARRAY['VERTICAL'::text, 'HORIZONTAL'::text])))
);


--
-- TOC entry 394 (class 1259 OID 20721)
-- Name: container_label_batch_item_container_label_batch_item_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5491 (class 0 OID 0)
-- Dependencies: 394
-- Name: container_label_batch_item_container_label_batch_item_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq OWNED BY ops.container_label_batch_item.container_label_batch_item_id;


--
-- TOC entry 386 (class 1259 OID 20611)
-- Name: container_label_print; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.container_label_print (
    container_label_print_id bigint NOT NULL,
    container_id integer NOT NULL,
    printed_at timestamp with time zone DEFAULT now() NOT NULL,
    printed_by_person_id integer,
    printed_by_text text,
    print_method text DEFAULT 'POLLING_SERVICE'::text NOT NULL,
    label_orientation text NOT NULL,
    label_qty integer DEFAULT 2 NOT NULL,
    qr_url text,
    container_label text,
    notes text,
    CONSTRAINT ck_container_label_print_orientation CHECK ((label_orientation = ANY (ARRAY['VERTICAL'::text, 'HORIZONTAL'::text]))),
    CONSTRAINT ck_container_label_print_qty CHECK ((label_qty > 0))
);


--
-- TOC entry 5492 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE container_label_print; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON TABLE ops.container_label_print IS 'Successful container label print history. One row per print event per container.';


--
-- TOC entry 5493 (class 0 OID 0)
-- Dependencies: 386
-- Name: COLUMN container_label_print.label_orientation; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON COLUMN ops.container_label_print.label_orientation IS 'VERTICAL when container_type_id = 1, otherwise HORIZONTAL.';


--
-- TOC entry 385 (class 1259 OID 20610)
-- Name: container_label_print_container_label_print_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.container_label_print_container_label_print_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5494 (class 0 OID 0)
-- Dependencies: 385
-- Name: container_label_print_container_label_print_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.container_label_print_container_label_print_id_seq OWNED BY ops.container_label_print.container_label_print_id;


--
-- TOC entry 389 (class 1259 OID 20675)
-- Name: display_label_batch; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.display_label_batch (
    display_label_batch_id bigint NOT NULL,
    batch_started_at timestamp with time zone DEFAULT now() NOT NULL,
    batch_completed_at timestamp with time zone,
    started_by_person_id integer,
    started_by_text text,
    status text DEFAULT 'PENDING'::text NOT NULL,
    notes text
);


--
-- TOC entry 388 (class 1259 OID 20674)
-- Name: display_label_batch_display_label_batch_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.display_label_batch_display_label_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5495 (class 0 OID 0)
-- Dependencies: 388
-- Name: display_label_batch_display_label_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.display_label_batch_display_label_batch_id_seq OWNED BY ops.display_label_batch.display_label_batch_id;


--
-- TOC entry 391 (class 1259 OID 20687)
-- Name: display_label_batch_item; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.display_label_batch_item (
    display_label_batch_item_id bigint NOT NULL,
    display_label_batch_id bigint NOT NULL,
    display_id integer NOT NULL,
    qr_url text,
    line1 text,
    line2 text,
    printed_flag boolean DEFAULT false NOT NULL,
    printed_at timestamp with time zone,
    container_id integer,
    display_name text
);


--
-- TOC entry 390 (class 1259 OID 20686)
-- Name: display_label_batch_item_display_label_batch_item_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5496 (class 0 OID 0)
-- Dependencies: 390
-- Name: display_label_batch_item_display_label_batch_item_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq OWNED BY ops.display_label_batch_item.display_label_batch_item_id;


--
-- TOC entry 384 (class 1259 OID 20591)
-- Name: display_label_print; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.display_label_print (
    display_label_print_id bigint NOT NULL,
    display_id bigint NOT NULL,
    printed_at timestamp with time zone DEFAULT now() NOT NULL,
    printed_by_person_id integer,
    printed_by_text text,
    print_method text DEFAULT 'POLLING_SERVICE'::text NOT NULL,
    label_qty integer DEFAULT 1 NOT NULL,
    qr_url text,
    line1 text,
    line2 text,
    notes text,
    CONSTRAINT ck_display_label_print_qty CHECK ((label_qty > 0))
);


--
-- TOC entry 5497 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE display_label_print; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON TABLE ops.display_label_print IS 'Successful display label print history. One row per print event per display.';


--
-- TOC entry 5498 (class 0 OID 0)
-- Dependencies: 384
-- Name: COLUMN display_label_print.printed_by_person_id; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON COLUMN ops.display_label_print.printed_by_person_id IS 'Optional Directus/person reference when known.';


--
-- TOC entry 5499 (class 0 OID 0)
-- Dependencies: 384
-- Name: COLUMN display_label_print.printed_by_text; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON COLUMN ops.display_label_print.printed_by_text IS 'Fallback text identifier for service/manual printing when person_id is not available.';


--
-- TOC entry 5500 (class 0 OID 0)
-- Dependencies: 384
-- Name: COLUMN display_label_print.print_method; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON COLUMN ops.display_label_print.print_method IS 'Examples: POLLING_SERVICE, MANUAL_CATCHUP, REPRINT, TEST';


--
-- TOC entry 383 (class 1259 OID 20590)
-- Name: display_label_print_display_label_print_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.display_label_print_display_label_print_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5501 (class 0 OID 0)
-- Dependencies: 383
-- Name: display_label_print_display_label_print_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.display_label_print_display_label_print_id_seq OWNED BY ops.display_label_print.display_label_print_id;


--
-- TOC entry 289 (class 1259 OID 17288)
-- Name: display_test_session; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.display_test_session (
    display_test_session_id bigint NOT NULL,
    test_session_id bigint NOT NULL,
    lor_prop_id text NOT NULL,
    is_display_present boolean,
    checked_at timestamp with time zone,
    checked_by text,
    notes text,
    checked_date_text text,
    stage_id integer,
    test_status text,
    amps_measured numeric,
    light_count integer,
    display_state text,
    is_spare boolean DEFAULT false NOT NULL,
    stage_key text,
    display_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    created_by_person_id integer,
    updated_by_person_id integer,
    checked_by_person_id integer,
    CONSTRAINT chk_display_test_session_state CHECK (((display_state IS NULL) OR (display_state = ANY (ARRAY['PASS'::text, 'FAIL'::text, 'DEFERRED'::text, 'NOT_PRESENT'::text, 'REMOVED_FOR_REPAIR'::text]))))
);


--
-- TOC entry 288 (class 1259 OID 17287)
-- Name: display_test_session_display_test_session_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.display_test_session_display_test_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5502 (class 0 OID 0)
-- Dependencies: 288
-- Name: display_test_session_display_test_session_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.display_test_session_display_test_session_id_seq OWNED BY ops.display_test_session.display_test_session_id;


--
-- TOC entry 287 (class 1259 OID 17257)
-- Name: test_session; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.test_session (
    test_session_id bigint NOT NULL,
    season_year integer NOT NULL,
    container_id integer NOT NULL,
    container_status_legacy text DEFAULT 'ACTIVE'::text NOT NULL,
    home_location_code text,
    work_location_code text,
    pulled_at timestamp with time zone,
    pulled_by text,
    returned_to_storage_at timestamp with time zone,
    returned_to_storage_by text,
    remaining_notes text,
    done_at timestamp with time zone,
    done_by text,
    notes text,
    tag_state text,
    legacy_flag boolean DEFAULT false NOT NULL,
    container_test_status_id integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    container_search_helper character varying(20),
    pulled_by_person_id integer,
    refresh_requested boolean DEFAULT false NOT NULL,
    last_refreshed_at timestamp with time zone,
    last_refreshed_by text,
    last_refreshed_by_person_id integer,
    last_refresh_add_count integer DEFAULT 0,
    last_refresh_delete_count integer DEFAULT 0,
    CONSTRAINT chk_test_session_tag_state CHECK (((tag_state IS NULL) OR (tag_state = ANY (ARRAY['GREEN'::text, 'YELLOW'::text, 'RED'::text])))),
    CONSTRAINT test_session_status_check CHECK ((container_status_legacy = ANY (ARRAY['NOT_STARTED'::text, 'IN_PROGRESS'::text, 'DONE'::text])))
);


--
-- TOC entry 286 (class 1259 OID 17256)
-- Name: test_session_test_session_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.test_session_test_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5503 (class 0 OID 0)
-- Dependencies: 286
-- Name: test_session_test_session_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.test_session_test_session_id_seq OWNED BY ops.test_session.test_session_id;


--
-- TOC entry 387 (class 1259 OID 20635)
-- Name: v_container_label_last_print; Type: VIEW; Schema: ops; Owner: -
--

CREATE VIEW ops.v_container_label_last_print AS
 SELECT DISTINCT ON (container_id) container_id,
    printed_at AS last_printed_at,
    printed_by_person_id,
    printed_by_text,
    print_method,
    label_orientation,
    label_qty,
    container_label
   FROM ops.container_label_print p
  ORDER BY container_id, printed_at DESC, container_label_print_id DESC;


--
-- TOC entry 328 (class 1259 OID 18094)
-- Name: stage; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.stage (
    stage_id integer NOT NULL,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    park_order integer,
    sub_order integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    parent_stage_key text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 347 (class 1259 OID 18813)
-- Name: v_stage_container_contents; Type: VIEW; Schema: ops; Owner: -
--

CREATE VIEW ops.v_stage_container_contents AS
 SELECT s.stage_name,
    d.container_id,
    ts.container_status_legacy AS container_status,
    d.display_id,
    d.display_name,
    d.string_type,
    d.color
   FROM ((ref.display d
     LEFT JOIN ref.stage s ON ((s.stage_id = d.stage_id)))
     LEFT JOIN ops.test_session ts ON ((ts.container_id = d.container_id)));


--
-- TOC entry 348 (class 1259 OID 18869)
-- Name: v_test_session_container_box; Type: VIEW; Schema: ops; Owner: -
--

CREATE VIEW ops.v_test_session_container_box AS
 SELECT ts.test_session_id AS id,
    ts.test_session_id,
    ts.season_year,
    ts.container_status_legacy AS status,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.pulled_at,
    ts.pulled_by,
    ts.returned_to_storage_at,
    ts.returned_to_storage_by,
    ts.done_at,
    ts.done_by,
    ts.remaining_notes,
    ts.notes AS test_session_notes,
    ts.tag_state,
    ts.legacy_flag,
    c.location_code AS container_location_code,
    c.container_type_id,
    c.description AS container_description,
    c.notes AS container_notes,
    c.year_built AS container_year_built,
    c.width_in_override,
    c.depth_in_override,
    c.height_in_override,
    c.goes_to,
    c.display_pallet,
    c.testing_after_takedown,
    c.display_pallet_flag
   FROM (ops.test_session ts
     JOIN ref.container c ON ((c.container_id = ts.container_id)));


--
-- TOC entry 349 (class 1259 OID 18879)
-- Name: v_test_session_container_box_ui; Type: VIEW; Schema: ops; Owner: -
--

CREATE VIEW ops.v_test_session_container_box_ui AS
 SELECT ts.test_session_id AS id,
    ts.test_session_id,
    ts.season_year,
    ts.container_status_legacy AS status,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.pulled_at,
    ts.pulled_by,
    ts.done_at,
    ts.done_by,
    ts.remaining_notes,
    ts.notes AS test_session_notes,
    c.location_code AS container_location_code,
    c.container_type_id,
    c.description AS container_description,
    c.notes AS container_notes,
    c.year_built AS container_year_built,
    c.width_in_override,
    c.depth_in_override,
    c.height_in_override,
    c.goes_to,
    c.testing_after_takedown,
    c.display_pallet_flag
   FROM (ops.test_session ts
     JOIN ref.container c ON ((c.container_id = ts.container_id)));


--
-- TOC entry 352 (class 1259 OID 18939)
-- Name: container_test_status; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.container_test_status (
    container_test_status_id integer NOT NULL,
    container_test_status_code text NOT NULL,
    container_test_status_name text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id integer,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id integer
);


--
-- TOC entry 363 (class 1259 OID 19131)
-- Name: v_test_session_insights; Type: VIEW; Schema: ops; Owner: -
--

CREATE VIEW ops.v_test_session_insights AS
 SELECT ts.test_session_id,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.container_test_status_id AS container_test_status_id_num,
    cts.container_test_status_name,
        CASE
            WHEN (ts.container_test_status_id = 2) THEN 1
            WHEN (ts.container_test_status_id = 1) THEN 2
            WHEN (ts.container_test_status_id = 3) THEN 3
            ELSE 9
        END AS status_sort
   FROM (ops.test_session ts
     JOIN ref.container_test_status cts ON ((ts.container_test_status_id = cts.container_test_status_id)))
  WHERE (ts.container_test_status_id <> 4);


--
-- TOC entry 338 (class 1259 OID 18484)
-- Name: work_order; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.work_order (
    work_order_id bigint NOT NULL,
    stage_id integer,
    work_area_id bigint,
    task_type_id bigint NOT NULL,
    urgency_id smallint,
    target_year integer,
    legacy_priority_raw text,
    problem text NOT NULL,
    notes text,
    photo_url text,
    date_completed timestamp with time zone,
    completed_by_person_id integer,
    completion_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_person_id integer NOT NULL,
    display_lor_prop_id text,
    display_id bigint,
    display_test_session_id bigint,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    repair_complete boolean DEFAULT false NOT NULL,
    source_intake_id bigint,
    submitted_by_person_id integer,
    submitted_at timestamp with time zone,
    source_system character varying(30),
    source_form_name character varying(30),
    triaged_at timestamp with time zone,
    triaged_by_person_id bigint,
    triage_notes text,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_work_order_completion_required CHECK (((date_completed IS NULL) OR (completed_by_person_id IS NOT NULL))),
    CONSTRAINT ck_work_order_location_required CHECK (((stage_id IS NOT NULL) OR (work_area_id IS NOT NULL))),
    CONSTRAINT ck_work_order_target_year_reasonable CHECK (((target_year IS NULL) OR ((target_year >= 2000) AND (target_year <= 2100))))
);


--
-- TOC entry 5504 (class 0 OID 0)
-- Dependencies: 338
-- Name: COLUMN work_order.source_intake_id; Type: COMMENT; Schema: ops; Owner: -
--

COMMENT ON COLUMN ops.work_order.source_intake_id IS 'Original intake ID for audit/reference only. No FK — intake records are deleted after triage.';


--
-- TOC entry 358 (class 1259 OID 19008)
-- Name: work_order_assignment; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.work_order_assignment (
    work_order_assignment_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    person_id integer NOT NULL,
    assignment_role text DEFAULT 'ASSIGNEE'::text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by_person_id integer,
    unassigned_at timestamp with time zone,
    unassigned_by_person_id integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer
);


--
-- TOC entry 357 (class 1259 OID 19007)
-- Name: work_order_assignment_work_order_assignment_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

ALTER TABLE ops.work_order_assignment ALTER COLUMN work_order_assignment_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_assignment_work_order_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 362 (class 1259 OID 19069)
-- Name: work_order_outbound_message; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.work_order_outbound_message (
    outbound_message_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    channel text DEFAULT 'EMAIL'::text NOT NULL,
    template_key text,
    to_address text,
    subject text,
    body_preview text,
    sent_flag boolean DEFAULT false NOT NULL,
    sent_at timestamp with time zone,
    provider_message_id text,
    error_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_person_id bigint,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL
);


--
-- TOC entry 361 (class 1259 OID 19068)
-- Name: work_order_outbound_message_outbound_message_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

ALTER TABLE ops.work_order_outbound_message ALTER COLUMN outbound_message_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_outbound_message_outbound_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 360 (class 1259 OID 19044)
-- Name: work_order_status_history; Type: TABLE; Schema: ops; Owner: -
--

CREATE TABLE ops.work_order_status_history (
    work_order_status_history_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    work_order_status_id bigint NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by_person_id bigint,
    notes text
);


--
-- TOC entry 359 (class 1259 OID 19043)
-- Name: work_order_status_history_work_order_status_history_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

ALTER TABLE ops.work_order_status_history ALTER COLUMN work_order_status_history_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_status_history_work_order_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 337 (class 1259 OID 18483)
-- Name: work_order_work_order_id_seq; Type: SEQUENCE; Schema: ops; Owner: -
--

CREATE SEQUENCE ops.work_order_work_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5505 (class 0 OID 0)
-- Dependencies: 337
-- Name: work_order_work_order_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: -
--

ALTER SEQUENCE ops.work_order_work_order_id_seq OWNED BY ops.work_order.work_order_id;


--
-- TOC entry 279 (class 1259 OID 17094)
-- Name: display_sheet_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.display_sheet_raw (
    display_name text,
    inventory_type text,
    display_status text,
    designer_name text,
    theme_name text,
    frame_name text,
    pallet_id_raw text,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text
);


--
-- TOC entry 368 (class 1259 OID 19212)
-- Name: audit_collection_policy; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.audit_collection_policy (
    audit_collection_policy_id integer NOT NULL,
    schema_name text NOT NULL,
    collection_name text NOT NULL,
    insert_actor_enabled boolean DEFAULT false NOT NULL,
    update_actor_enabled boolean DEFAULT false NOT NULL,
    checked_actor_enabled boolean DEFAULT false NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id bigint,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id bigint
);


--
-- TOC entry 367 (class 1259 OID 19211)
-- Name: audit_collection_policy_audit_collection_policy_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.audit_collection_policy ALTER COLUMN audit_collection_policy_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.audit_collection_policy_audit_collection_policy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 365 (class 1259 OID 19207)
-- Name: container_container_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.container_container_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5506 (class 0 OID 0)
-- Dependencies: 365
-- Name: container_container_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.container_container_id_seq OWNED BY ref.container.container_id;


--
-- TOC entry 332 (class 1259 OID 18282)
-- Name: container_endpoint; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.container_endpoint (
    endpoint_id integer NOT NULL,
    endpoint_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


--
-- TOC entry 364 (class 1259 OID 19205)
-- Name: container_endpoint_endpoint_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.container_endpoint_endpoint_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5507 (class 0 OID 0)
-- Dependencies: 364
-- Name: container_endpoint_endpoint_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.container_endpoint_endpoint_id_seq OWNED BY ref.container_endpoint.endpoint_id;


--
-- TOC entry 351 (class 1259 OID 18938)
-- Name: container_test_status_container_test_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.container_test_status ALTER COLUMN container_test_status_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.container_test_status_container_test_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 369 (class 1259 OID 19295)
-- Name: container_test_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.container_test_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 267 (class 1259 OID 16806)
-- Name: container_type; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.container_type (
    container_type_id integer NOT NULL,
    container_type_name text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    default_width_in integer,
    default_depth_in integer,
    default_height_in integer,
    is_stackable_default boolean,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 372 (class 1259 OID 20326)
-- Name: display_backup_20260317; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_backup_20260317 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 376 (class 1259 OID 20431)
-- Name: display_backup_20260318_after_run22_success; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_backup_20260318_after_run22_success (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 378 (class 1259 OID 20453)
-- Name: display_backup_20260319_after_run23_baseline; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_backup_20260319_after_run23_baseline (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 382 (class 1259 OID 20534)
-- Name: display_backup_20260319_before_run25_p2; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_backup_20260319_before_run25_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 380 (class 1259 OID 20476)
-- Name: display_backup_20260319_run23_post_p2; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_backup_20260319_run23_post_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 346 (class 1259 OID 18722)
-- Name: display_display_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.display ALTER COLUMN display_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.display_display_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 265 (class 1259 OID 16761)
-- Name: display_status; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_status (
    display_status_id integer NOT NULL,
    display_status_name text NOT NULL,
    description text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 264 (class 1259 OID 16760)
-- Name: display_status_display_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.display_status ALTER COLUMN display_status_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.display_status_display_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 350 (class 1259 OID 18907)
-- Name: display_test_status; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.display_test_status (
    test_status_code text NOT NULL,
    sort_order integer NOT NULL,
    label text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


--
-- TOC entry 261 (class 1259 OID 16706)
-- Name: frame; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.frame (
    frame_id integer NOT NULL,
    frame_name text NOT NULL,
    w_ft integer,
    h_ft integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    CONSTRAINT chk_frame_dimensions CHECK ((((frame_name = ANY (ARRAY['Custom'::text, 'None'::text])) AND (w_ft IS NULL) AND (h_ft IS NULL)) OR ((frame_name <> ALL (ARRAY['Custom'::text, 'None'::text])) AND (w_ft IS NOT NULL) AND (h_ft IS NOT NULL))))
);


--
-- TOC entry 260 (class 1259 OID 16705)
-- Name: frame_frame_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.frame ALTER COLUMN frame_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.frame_frame_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 276 (class 1259 OID 17028)
-- Name: inventory_type; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.inventory_type (
    inventory_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


--
-- TOC entry 266 (class 1259 OID 16805)
-- Name: pallet_type_pallet_type_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.container_type ALTER COLUMN container_type_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.pallet_type_pallet_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 272 (class 1259 OID 16953)
-- Name: person; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.person (
    person_id integer NOT NULL,
    first_name text NOT NULL,
    last_name text,
    preferred_name text,
    email text,
    cell_phone text,
    active_flag boolean DEFAULT true NOT NULL,
    is_manager boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    is_team boolean DEFAULT false NOT NULL,
    personal_email text,
    directus_user_id uuid,
    pg_login_name character varying(20),
    created_by_person_id bigint,
    updated_by_person_id bigint,
    available_for_work_orders boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_cell_phone_digits_10 CHECK (((cell_phone IS NULL) OR (cell_phone ~ '^\d{10}$'::text))),
    CONSTRAINT chk_person_last_name_if_not_team CHECK (((is_team = true) OR ((last_name IS NOT NULL) AND (btrim(last_name) <> ''::text))))
);


--
-- TOC entry 366 (class 1259 OID 19209)
-- Name: person_person_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.person_person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5508 (class 0 OID 0)
-- Dependencies: 366
-- Name: person_person_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.person_person_id_seq OWNED BY ref.person.person_id;


--
-- TOC entry 274 (class 1259 OID 16973)
-- Name: person_xref; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.person_xref (
    source_system text NOT NULL,
    source_user_id text NOT NULL,
    person_id integer NOT NULL,
    email text,
    username text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


--
-- TOC entry 370 (class 1259 OID 19486)
-- Name: season; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.season (
    season_year integer NOT NULL,
    season_name text NOT NULL,
    season_start_date date,
    season_end_date date,
    active_flag boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id integer,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id integer
);


--
-- TOC entry 339 (class 1259 OID 18556)
-- Name: spare_channel; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel (
    lor_prop_id text NOT NULL,
    display_name text NOT NULL,
    inventory_type text NOT NULL,
    display_status_id integer NOT NULL,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 373 (class 1259 OID 20331)
-- Name: spare_channel_backup_20260317; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260317 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 377 (class 1259 OID 20438)
-- Name: spare_channel_backup_20260318_after_run22_success; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260318_after_run22_success (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 374 (class 1259 OID 20359)
-- Name: spare_channel_backup_20260318_lor_raw_fix; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260318_lor_raw_fix (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 375 (class 1259 OID 20365)
-- Name: spare_channel_backup_20260318_partial_raw_restore; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260318_partial_raw_restore (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 379 (class 1259 OID 20460)
-- Name: spare_channel_backup_20260319_after_run23_baseline; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260319_after_run23_baseline (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 381 (class 1259 OID 20510)
-- Name: spare_channel_backup_20260319_before_run24_p2; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.spare_channel_backup_20260319_before_run24_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 329 (class 1259 OID 18103)
-- Name: stage_history; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.stage_history (
    import_run_id integer NOT NULL,
    stage_id integer NOT NULL,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text,
    captured_at timestamp with time zone DEFAULT now() NOT NULL,
    captured_by text DEFAULT CURRENT_USER NOT NULL
);


--
-- TOC entry 330 (class 1259 OID 18171)
-- Name: stage_stage_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.stage_stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5509 (class 0 OID 0)
-- Dependencies: 330
-- Name: stage_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.stage_stage_id_seq OWNED BY ref.stage.stage_id;


--
-- TOC entry 269 (class 1259 OID 16841)
-- Name: storage_location; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.storage_location (
    type_code text NOT NULL,
    rack_row_code text NOT NULL,
    column_num integer,
    shelf_level_code text,
    slot_bin_num integer,
    description text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    location_code text GENERATED ALWAYS AS (
CASE
    WHEN (type_code = 'R'::text) THEN ((((((type_code || rack_row_code) || lpad((column_num)::text, 2, '0'::text)) || '-'::text) || shelf_level_code) || '-'::text) || lpad((slot_bin_num)::text, 2, '0'::text))
    WHEN (type_code = 'Z'::text) THEN (('Z-'::text || rack_row_code) ||
    CASE
        WHEN ((shelf_level_code IS NULL) OR (btrim(shelf_level_code) = ''::text)) THEN ''::text
        ELSE ('-'::text || shelf_level_code)
    END)
    ELSE NULL::text
END) STORED NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_location_type CHECK ((type_code = ANY (ARRAY['R'::text, 'Z'::text]))),
    CONSTRAINT ck_storage_location_type_rules CHECK ((((type_code = 'R'::text) AND (rack_row_code IS NOT NULL) AND (column_num IS NOT NULL) AND (shelf_level_code IS NOT NULL) AND (slot_bin_num IS NOT NULL)) OR ((type_code = 'Z'::text) AND (rack_row_code IS NOT NULL) AND (column_num IS NULL) AND (slot_bin_num IS NULL))))
);


--
-- TOC entry 334 (class 1259 OID 18393)
-- Name: task_type; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.task_type (
    task_type_id bigint NOT NULL,
    task_type_key text NOT NULL,
    task_type_name text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 333 (class 1259 OID 18392)
-- Name: task_type_task_type_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.task_type_task_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5510 (class 0 OID 0)
-- Dependencies: 333
-- Name: task_type_task_type_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.task_type_task_type_id_seq OWNED BY ref.task_type.task_type_id;


--
-- TOC entry 263 (class 1259 OID 16746)
-- Name: theme; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.theme (
    theme_id integer NOT NULL,
    theme_name text NOT NULL,
    additional_info text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 262 (class 1259 OID 16745)
-- Name: theme_theme_pk_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.theme ALTER COLUMN theme_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.theme_theme_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 371 (class 1259 OID 19624)
-- Name: urgency; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.urgency (
    urgency_id smallint NOT NULL,
    urgency_code text NOT NULL,
    urgency_label text NOT NULL,
    sort_order integer NOT NULL,
    active_flag boolean DEFAULT true NOT NULL
);


--
-- TOC entry 336 (class 1259 OID 18423)
-- Name: work_area; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.work_area (
    work_area_id bigint NOT NULL,
    work_area_key text NOT NULL,
    work_area_name text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 335 (class 1259 OID 18422)
-- Name: work_area_work_area_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

CREATE SEQUENCE ref.work_area_work_area_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5511 (class 0 OID 0)
-- Dependencies: 335
-- Name: work_area_work_area_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: -
--

ALTER SEQUENCE ref.work_area_work_area_id_seq OWNED BY ref.work_area.work_area_id;


--
-- TOC entry 354 (class 1259 OID 18962)
-- Name: work_order_status; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.work_order_status (
    work_order_status_id bigint NOT NULL,
    status_key text NOT NULL,
    status_name text NOT NULL,
    is_terminal boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


--
-- TOC entry 353 (class 1259 OID 18961)
-- Name: work_order_status_work_order_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: -
--

ALTER TABLE ref.work_order_status ALTER COLUMN work_order_status_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.work_order_status_work_order_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 278 (class 1259 OID 17088)
-- Name: display_sheet_csv; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.display_sheet_csv (
    display_name text,
    inventory_type text,
    display_status text,
    designer_id text,
    theme_id text,
    frame_id text,
    pallet_id text,
    year_built text,
    amps_measured text,
    est_light_count text,
    dumb_controller text,
    notes text
);


--
-- TOC entry 270 (class 1259 OID 16868)
-- Name: location_raw_full; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.location_raw_full (
    storage_id text,
    storage_no text,
    type text,
    location text,
    column_num integer,
    shelf text,
    slot_bin integer,
    description text,
    pallet_fk text,
    msb_sku text,
    notes text
);


--
-- TOC entry 331 (class 1259 OID 18248)
-- Name: pallet_raw_2026; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.pallet_raw_2026 (
    pallet_id integer NOT NULL,
    rack_code text,
    pallet_type text,
    description text,
    stage_id text,
    notes text,
    distribution text,
    display_pallet_flag text,
    testing_after_takedown text,
    year_built text
);


--
-- TOC entry 327 (class 1259 OID 18067)
-- Name: test_plan_2026_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.test_plan_2026_raw (
    rack_location_text text,
    container_id_text text,
    old_display_name text,
    new_db_display_name text,
    date_tested_text text,
    tested_initials text,
    need_rgb_tested_text text,
    rgb_tested_date_text text,
    rgb_tested_initials text,
    car_counter_testing text,
    controller_testing text,
    laser_light_testing text,
    repair_yes_no_defer text,
    amp_reading_needed_yes_no_na text,
    pallet_label_needed_text text,
    notes text
);


--
-- TOC entry 281 (class 1259 OID 17108)
-- Name: v_sheet_match; Type: VIEW; Schema: stage; Owner: -
--

CREATE VIEW stage.v_sheet_match AS
 WITH lor AS (
         SELECT p.prop_id AS lor_prop_id,
            p.lor_comment,
            lower(regexp_replace(COALESCE(p.lor_comment, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS key_norm
           FROM lor_snap.props p
          WHERE (p.import_run_id = ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run))
        )
 SELECT s.display_name,
    s.inventory_type,
    s.display_status,
    s.designer_name,
    s.theme_name,
    s.frame_name,
    s.pallet_id_raw,
    s.year_built,
    s.amps_measured,
    s.est_light_count,
    s.dumb_controller,
    s.notes,
    l.lor_prop_id,
    l.lor_comment AS matched_lor_comment
   FROM (stage.display_sheet_raw s
     LEFT JOIN lor l ON ((l.key_norm = lower(regexp_replace(COALESCE(s.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)))));


--
-- TOC entry 343 (class 1259 OID 18688)
-- Name: work_order_completed_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.work_order_completed_raw (
    src_row_num bigint NOT NULL,
    done_raw text,
    priority_raw text,
    task_raw text,
    area_raw text,
    problem_raw text,
    notes_raw text,
    photo_raw text,
    assigned_to_raw text,
    date_added_raw text,
    added_by_raw text,
    date_complete_raw text,
    completed_by_raw text,
    email_sent_raw text,
    source_sheet text DEFAULT 'completed'::text NOT NULL,
    imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 341 (class 1259 OID 18653)
-- Name: work_order_todo_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.work_order_todo_raw (
    src_row_num bigint NOT NULL,
    done_raw text,
    priority_raw text,
    task_raw text,
    area_raw text,
    problem_raw text,
    notes_raw text,
    photo_raw text,
    assigned_to_raw text,
    date_added_raw text,
    added_by_raw text,
    date_complete_raw text,
    completed_by_raw text,
    email_sent_raw text,
    source_sheet text DEFAULT 'todo'::text NOT NULL,
    imported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 344 (class 1259 OID 18704)
-- Name: v_work_order_all_raw; Type: VIEW; Schema: stage; Owner: -
--

CREATE VIEW stage.v_work_order_all_raw AS
 SELECT 'todo'::text AS source_tab,
    NULLIF(btrim(work_order_todo_raw.priority_raw), ''::text) AS priority_raw,
    NULLIF(btrim(work_order_todo_raw.task_raw), ''::text) AS task_type_raw,
    NULLIF(btrim(work_order_todo_raw.area_raw), ''::text) AS work_area_raw,
    NULLIF(btrim(work_order_todo_raw.problem_raw), ''::text) AS problem_raw,
    NULLIF(btrim(work_order_todo_raw.notes_raw), ''::text) AS notes_raw,
    NULLIF(btrim(work_order_todo_raw.photo_raw), ''::text) AS photo_raw,
    NULLIF(btrim(work_order_todo_raw.assigned_to_raw), ''::text) AS assigned_to_raw,
    NULLIF(btrim(work_order_todo_raw.date_added_raw), ''::text) AS date_added_raw,
    NULLIF(btrim(work_order_todo_raw.added_by_raw), ''::text) AS added_by_raw,
    NULLIF(btrim(work_order_todo_raw.date_complete_raw), ''::text) AS date_complete_raw,
    NULLIF(btrim(work_order_todo_raw.completed_by_raw), ''::text) AS completed_by_raw
   FROM stage.work_order_todo_raw
UNION ALL
 SELECT 'completed'::text AS source_tab,
    NULLIF(btrim(work_order_completed_raw.priority_raw), ''::text) AS priority_raw,
    NULLIF(btrim(work_order_completed_raw.task_raw), ''::text) AS task_type_raw,
    NULLIF(btrim(work_order_completed_raw.area_raw), ''::text) AS work_area_raw,
    NULLIF(btrim(work_order_completed_raw.problem_raw), ''::text) AS problem_raw,
    NULLIF(btrim(work_order_completed_raw.notes_raw), ''::text) AS notes_raw,
    NULLIF(btrim(work_order_completed_raw.photo_raw), ''::text) AS photo_raw,
    NULLIF(btrim(work_order_completed_raw.assigned_to_raw), ''::text) AS assigned_to_raw,
    NULLIF(btrim(work_order_completed_raw.date_added_raw), ''::text) AS date_added_raw,
    NULLIF(btrim(work_order_completed_raw.added_by_raw), ''::text) AS added_by_raw,
    NULLIF(btrim(work_order_completed_raw.date_complete_raw), ''::text) AS date_complete_raw,
    NULLIF(btrim(work_order_completed_raw.completed_by_raw), ''::text) AS completed_by_raw
   FROM stage.work_order_completed_raw;


--
-- TOC entry 271 (class 1259 OID 16889)
-- Name: val_stages_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.val_stages_raw (
    stage_id_text text,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text
);


--
-- TOC entry 273 (class 1259 OID 16968)
-- Name: val_user_raw; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.val_user_raw (
    "UserID (PK)" integer,
    "First_Name" text,
    "Last_Name" text,
    "Prefered_Name" text,
    "Email" text,
    "Status" text,
    "Cell_Phone" text,
    "Title" text,
    "Committee" text,
    "Full Name" text,
    "Manager" boolean
);


--
-- TOC entry 342 (class 1259 OID 18687)
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: -
--

CREATE SEQUENCE stage.work_order_completed_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5512 (class 0 OID 0)
-- Dependencies: 342
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE OWNED BY; Schema: stage; Owner: -
--

ALTER SEQUENCE stage.work_order_completed_raw_src_row_num_seq OWNED BY stage.work_order_completed_raw.src_row_num;


--
-- TOC entry 356 (class 1259 OID 18976)
-- Name: work_order_intake; Type: TABLE; Schema: stage; Owner: -
--

CREATE TABLE stage.work_order_intake (
    intake_id bigint NOT NULL,
    source_system character varying(30) DEFAULT 'GOOGLE_FORM'::text NOT NULL,
    source_form_name character varying(30),
    source_payload jsonb,
    source_row_hash character varying(64),
    submitter_email_raw character varying(64),
    submitter_name_raw character varying(100),
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    priority_raw character varying(10) NOT NULL,
    task_type_raw character varying(50) NOT NULL,
    stage_raw character varying(100),
    problem_raw character varying(255) NOT NULL,
    notes_raw text,
    photo_url_raw character varying(255),
    triaged_at timestamp with time zone,
    triaged_by_person_id integer,
    triage_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    location_type_raw character varying(20),
    work_area_raw character varying(100),
    submitter_person_id integer,
    stage_id bigint,
    work_area_id bigint,
    task_type_id bigint,
    urgency_id smallint,
    target_year integer,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    triage_dropdown character varying(255) DEFAULT '1'::character varying,
    CONSTRAINT ck_work_order_intake_triage_dropdown CHECK (((triage_dropdown)::text = ANY ((ARRAY['1'::character varying, '3'::character varying, '4'::character varying])::text[])))
);


--
-- TOC entry 5513 (class 0 OID 0)
-- Dependencies: 356
-- Name: COLUMN work_order_intake.stage_raw; Type: COMMENT; Schema: stage; Owner: -
--

COMMENT ON COLUMN stage.work_order_intake.stage_raw IS 'Raw stage value selected in the Google Form when STAGE branch is used';


--
-- TOC entry 5514 (class 0 OID 0)
-- Dependencies: 356
-- Name: COLUMN work_order_intake.location_type_raw; Type: COMMENT; Schema: stage; Owner: -
--

COMMENT ON COLUMN stage.work_order_intake.location_type_raw IS 'Branch selected in the Google Form: WORK_AREA or STAGE';


--
-- TOC entry 5515 (class 0 OID 0)
-- Dependencies: 356
-- Name: COLUMN work_order_intake.work_area_raw; Type: COMMENT; Schema: stage; Owner: -
--

COMMENT ON COLUMN stage.work_order_intake.work_area_raw IS 'Raw work area selected in the Google Form when WORK_AREA branch is used';


--
-- TOC entry 355 (class 1259 OID 18975)
-- Name: work_order_intake_intake_id_seq; Type: SEQUENCE; Schema: stage; Owner: -
--

ALTER TABLE stage.work_order_intake ALTER COLUMN intake_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME stage.work_order_intake_intake_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 340 (class 1259 OID 18652)
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: -
--

CREATE SEQUENCE stage.work_order_todo_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5516 (class 0 OID 0)
-- Dependencies: 340
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE OWNED BY; Schema: stage; Owner: -
--

ALTER SEQUENCE stage.work_order_todo_raw_src_row_num_seq OWNED BY stage.work_order_todo_raw.src_row_num;


--
-- TOC entry 4745 (class 2604 OID 16394)
-- Name: import_run import_run_id; Type: DEFAULT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.import_run ALTER COLUMN import_run_id SET DEFAULT nextval('lor_snap.import_run_import_run_id_seq'::regclass);


--
-- TOC entry 4906 (class 2604 OID 20713)
-- Name: container_label_batch container_label_batch_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch ALTER COLUMN container_label_batch_id SET DEFAULT nextval('ops.container_label_batch_container_label_batch_id_seq'::regclass);


--
-- TOC entry 4909 (class 2604 OID 20725)
-- Name: container_label_batch_item container_label_batch_item_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item ALTER COLUMN container_label_batch_item_id SET DEFAULT nextval('ops.container_label_batch_item_container_label_batch_item_id_seq'::regclass);


--
-- TOC entry 4897 (class 2604 OID 20614)
-- Name: container_label_print container_label_print_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_print ALTER COLUMN container_label_print_id SET DEFAULT nextval('ops.container_label_print_container_label_print_id_seq'::regclass);


--
-- TOC entry 4901 (class 2604 OID 20678)
-- Name: display_label_batch display_label_batch_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch ALTER COLUMN display_label_batch_id SET DEFAULT nextval('ops.display_label_batch_display_label_batch_id_seq'::regclass);


--
-- TOC entry 4904 (class 2604 OID 20690)
-- Name: display_label_batch_item display_label_batch_item_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item ALTER COLUMN display_label_batch_item_id SET DEFAULT nextval('ops.display_label_batch_item_display_label_batch_item_id_seq'::regclass);


--
-- TOC entry 4893 (class 2604 OID 20594)
-- Name: display_label_print display_label_print_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_print ALTER COLUMN display_label_print_id SET DEFAULT nextval('ops.display_label_print_display_label_print_id_seq'::regclass);


--
-- TOC entry 4812 (class 2604 OID 17291)
-- Name: display_test_session display_test_session_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session ALTER COLUMN display_test_session_id SET DEFAULT nextval('ops.display_test_session_display_test_session_id_seq'::regclass);


--
-- TOC entry 4801 (class 2604 OID 17260)
-- Name: test_session test_session_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session ALTER COLUMN test_session_id SET DEFAULT nextval('ops.test_session_test_session_id_seq'::regclass);


--
-- TOC entry 4836 (class 2604 OID 18487)
-- Name: work_order work_order_id; Type: DEFAULT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order ALTER COLUMN work_order_id SET DEFAULT nextval('ops.work_order_work_order_id_seq'::regclass);


--
-- TOC entry 4763 (class 2604 OID 19208)
-- Name: container container_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container ALTER COLUMN container_id SET DEFAULT nextval('ref.container_container_id_seq'::regclass);


--
-- TOC entry 4821 (class 2604 OID 19206)
-- Name: container_endpoint endpoint_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_endpoint ALTER COLUMN endpoint_id SET DEFAULT nextval('ref.container_endpoint_endpoint_id_seq'::regclass);


--
-- TOC entry 4777 (class 2604 OID 19210)
-- Name: person person_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person ALTER COLUMN person_id SET DEFAULT nextval('ref.person_person_id_seq'::regclass);


--
-- TOC entry 4814 (class 2604 OID 18188)
-- Name: stage stage_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage ALTER COLUMN stage_id SET DEFAULT nextval('ref.stage_stage_id_seq'::regclass);


--
-- TOC entry 4826 (class 2604 OID 18396)
-- Name: task_type task_type_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.task_type ALTER COLUMN task_type_id SET DEFAULT nextval('ref.task_type_task_type_id_seq'::regclass);


--
-- TOC entry 4831 (class 2604 OID 18426)
-- Name: work_area work_area_id; Type: DEFAULT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_area ALTER COLUMN work_area_id SET DEFAULT nextval('ref.work_area_work_area_id_seq'::regclass);


--
-- TOC entry 4850 (class 2604 OID 18691)
-- Name: work_order_completed_raw src_row_num; Type: DEFAULT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_completed_raw ALTER COLUMN src_row_num SET DEFAULT nextval('stage.work_order_completed_raw_src_row_num_seq'::regclass);


--
-- TOC entry 4847 (class 2604 OID 18656)
-- Name: work_order_todo_raw src_row_num; Type: DEFAULT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_todo_raw ALTER COLUMN src_row_num SET DEFAULT nextval('stage.work_order_todo_raw_src_row_num_seq'::regclass);


--
-- TOC entry 4942 (class 2606 OID 16463)
-- Name: dmx_channels dmx_channels_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_pkey PRIMARY KEY (import_run_id, int_dmx_channel_id);


--
-- TOC entry 4928 (class 2606 OID 16399)
-- Name: import_run import_run_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.import_run
    ADD CONSTRAINT import_run_pkey PRIMARY KEY (import_run_id);


--
-- TOC entry 4930 (class 2606 OID 16408)
-- Name: previews previews_import_run_id_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_import_run_id_id_key UNIQUE (import_run_id, id);


--
-- TOC entry 4932 (class 2606 OID 16406)
-- Name: previews previews_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_pkey PRIMARY KEY (import_run_id, int_preview_id);


--
-- TOC entry 4934 (class 2606 OID 16422)
-- Name: props props_import_run_id_prop_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_prop_id_key UNIQUE (import_run_id, prop_id);


--
-- TOC entry 4936 (class 2606 OID 16420)
-- Name: props props_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_pkey PRIMARY KEY (import_run_id, int_prop_id);


--
-- TOC entry 4938 (class 2606 OID 16441)
-- Name: sub_props sub_props_import_run_id_sub_prop_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_sub_prop_id_key UNIQUE (import_run_id, sub_prop_id);


--
-- TOC entry 4940 (class 2606 OID 16439)
-- Name: sub_props sub_props_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_pkey PRIMARY KEY (import_run_id, int_sub_prop_id);


--
-- TOC entry 5100 (class 2606 OID 20732)
-- Name: container_label_batch_item container_label_batch_item_container_label_batch_id_contain_key; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_label_batch_id_contain_key UNIQUE (container_label_batch_id, container_id);


--
-- TOC entry 5102 (class 2606 OID 20730)
-- Name: container_label_batch_item container_label_batch_item_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_pkey PRIMARY KEY (container_label_batch_item_id);


--
-- TOC entry 5097 (class 2606 OID 20719)
-- Name: container_label_batch container_label_batch_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch
    ADD CONSTRAINT container_label_batch_pkey PRIMARY KEY (container_label_batch_id);


--
-- TOC entry 5082 (class 2606 OID 20623)
-- Name: container_label_print container_label_print_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT container_label_print_pkey PRIMARY KEY (container_label_print_id);


--
-- TOC entry 5089 (class 2606 OID 20697)
-- Name: display_label_batch_item display_label_batch_item_display_label_batch_id_display_id_key; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_label_batch_id_display_id_key UNIQUE (display_label_batch_id, display_id);


--
-- TOC entry 5091 (class 2606 OID 20695)
-- Name: display_label_batch_item display_label_batch_item_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_pkey PRIMARY KEY (display_label_batch_item_id);


--
-- TOC entry 5086 (class 2606 OID 20684)
-- Name: display_label_batch display_label_batch_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch
    ADD CONSTRAINT display_label_batch_pkey PRIMARY KEY (display_label_batch_id);


--
-- TOC entry 5078 (class 2606 OID 20602)
-- Name: display_label_print display_label_print_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT display_label_print_pkey PRIMARY KEY (display_label_print_id);


--
-- TOC entry 5003 (class 2606 OID 17296)
-- Name: display_test_session display_test_session_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT display_test_session_pkey PRIMARY KEY (display_test_session_id);


--
-- TOC entry 4998 (class 2606 OID 17267)
-- Name: test_session test_session_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT test_session_pkey PRIMARY KEY (test_session_id);


--
-- TOC entry 5106 (class 2606 OID 20779)
-- Name: container_label_batch_item uq_container_label_batch_item_batch_container; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT uq_container_label_batch_item_batch_container UNIQUE (container_label_batch_id, container_id);


--
-- TOC entry 5095 (class 2606 OID 20761)
-- Name: display_label_batch_item uq_display_label_batch_item_batch_display; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT uq_display_label_batch_item_batch_display UNIQUE (display_label_batch_id, display_id);


--
-- TOC entry 5005 (class 2606 OID 18748)
-- Name: display_test_session uq_display_per_session_display_id; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT uq_display_per_session_display_id UNIQUE (test_session_id, display_id);


--
-- TOC entry 5000 (class 2606 OID 19543)
-- Name: test_session uq_test_session_season_container; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT uq_test_session_season_container UNIQUE (season_year, container_id);


--
-- TOC entry 5060 (class 2606 OID 19019)
-- Name: work_order_assignment work_order_assignment_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT work_order_assignment_pkey PRIMARY KEY (work_order_assignment_id);


--
-- TOC entry 5066 (class 2606 OID 19079)
-- Name: work_order_outbound_message work_order_outbound_message_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT work_order_outbound_message_pkey PRIMARY KEY (outbound_message_id);


--
-- TOC entry 5031 (class 2606 OID 18493)
-- Name: work_order work_order_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT work_order_pkey PRIMARY KEY (work_order_id);


--
-- TOC entry 5063 (class 2606 OID 19051)
-- Name: work_order_status_history work_order_status_history_pkey; Type: CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT work_order_status_history_pkey PRIMARY KEY (work_order_status_history_id);


--
-- TOC entry 5068 (class 2606 OID 19222)
-- Name: audit_collection_policy audit_collection_policy_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT audit_collection_policy_pkey PRIMARY KEY (audit_collection_policy_id);


--
-- TOC entry 5016 (class 2606 OID 18288)
-- Name: container_endpoint container_endpoint_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT container_endpoint_pkey PRIMARY KEY (endpoint_id);


--
-- TOC entry 5042 (class 2606 OID 18949)
-- Name: container_test_status container_test_status_container_test_status_code_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_test_status
    ADD CONSTRAINT container_test_status_container_test_status_code_key UNIQUE (container_test_status_code);


--
-- TOC entry 5044 (class 2606 OID 18947)
-- Name: container_test_status container_test_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_test_status
    ADD CONSTRAINT container_test_status_pkey PRIMARY KEY (container_test_status_id);


--
-- TOC entry 4983 (class 2606 OID 18845)
-- Name: display display_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT display_pkey PRIMARY KEY (display_id);


--
-- TOC entry 4954 (class 2606 OID 16773)
-- Name: display_status display_status_display_status_name_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT display_status_display_status_name_key UNIQUE (display_status_name);


--
-- TOC entry 4956 (class 2606 OID 16771)
-- Name: display_status display_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT display_status_pkey PRIMARY KEY (display_status_id);


--
-- TOC entry 5040 (class 2606 OID 18913)
-- Name: display_test_status display_test_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT display_test_status_pkey PRIMARY KEY (test_status_code);


--
-- TOC entry 4944 (class 2606 OID 16716)
-- Name: frame frame_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT frame_pkey PRIMARY KEY (frame_id);


--
-- TOC entry 4981 (class 2606 OID 17034)
-- Name: inventory_type inventory_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT inventory_type_pkey PRIMARY KEY (inventory_type);


--
-- TOC entry 4962 (class 2606 OID 16831)
-- Name: container pallet_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT pallet_pkey PRIMARY KEY (container_id);


--
-- TOC entry 4958 (class 2606 OID 16818)
-- Name: container_type pallet_type_pallet_type_name_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT pallet_type_pallet_type_name_key UNIQUE (container_type_name);


--
-- TOC entry 4960 (class 2606 OID 16816)
-- Name: container_type pallet_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT pallet_type_pkey PRIMARY KEY (container_type_id);


--
-- TOC entry 4972 (class 2606 OID 16966)
-- Name: person person_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (person_id);


--
-- TOC entry 4979 (class 2606 OID 16986)
-- Name: person_xref pk_person_xref; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT pk_person_xref PRIMARY KEY (source_system, source_user_id);


--
-- TOC entry 4985 (class 2606 OID 18741)
-- Name: display ref_display_display_id_uk; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ref_display_display_id_uk UNIQUE (display_id);


--
-- TOC entry 5072 (class 2606 OID 19493)
-- Name: season season_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.season
    ADD CONSTRAINT season_pkey PRIMARY KEY (season_year);


--
-- TOC entry 5034 (class 2606 OID 18566)
-- Name: spare_channel spare_channel_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT spare_channel_pkey PRIMARY KEY (lor_prop_id);


--
-- TOC entry 5014 (class 2606 OID 18111)
-- Name: stage_history stage_history_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage_history
    ADD CONSTRAINT stage_history_pkey PRIMARY KEY (import_run_id, stage_id);


--
-- TOC entry 5010 (class 2606 OID 18102)
-- Name: stage stage_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT stage_pkey PRIMARY KEY (stage_id);


--
-- TOC entry 4965 (class 2606 OID 18906)
-- Name: storage_location storage_location_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT storage_location_pkey PRIMARY KEY (location_code);


--
-- TOC entry 5018 (class 2606 OID 18404)
-- Name: task_type task_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT task_type_pkey PRIMARY KEY (task_type_id);


--
-- TOC entry 4950 (class 2606 OID 16756)
-- Name: theme theme_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT theme_pkey PRIMARY KEY (theme_id);


--
-- TOC entry 4952 (class 2606 OID 16758)
-- Name: theme theme_theme_name_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT theme_theme_name_key UNIQUE (theme_name);


--
-- TOC entry 5070 (class 2606 OID 19224)
-- Name: audit_collection_policy uq_audit_collection_policy; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT uq_audit_collection_policy UNIQUE (schema_name, collection_name);


--
-- TOC entry 4946 (class 2606 OID 16718)
-- Name: frame uq_frame_code; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT uq_frame_code UNIQUE (frame_name);


--
-- TOC entry 4948 (class 2606 OID 16720)
-- Name: frame uq_frame_size; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT uq_frame_size UNIQUE (w_ft, h_ft);


--
-- TOC entry 4967 (class 2606 OID 16854)
-- Name: storage_location uq_location_parts; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT uq_location_parts UNIQUE (type_code, rack_row_code, column_num, shelf_level_code, slot_bin_num);


--
-- TOC entry 4974 (class 2606 OID 19130)
-- Name: person uq_person_directus_user_id; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT uq_person_directus_user_id UNIQUE (directus_user_id);


--
-- TOC entry 4987 (class 2606 OID 18734)
-- Name: display uq_ref_display_display_id; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT uq_ref_display_display_id UNIQUE (display_id);


--
-- TOC entry 5012 (class 2606 OID 18163)
-- Name: stage uq_ref_stage_stage_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT uq_ref_stage_stage_key UNIQUE (stage_key);


--
-- TOC entry 5074 (class 2606 OID 19631)
-- Name: urgency urgency_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.urgency
    ADD CONSTRAINT urgency_pkey PRIMARY KEY (urgency_id);


--
-- TOC entry 5076 (class 2606 OID 19633)
-- Name: urgency urgency_urgency_code_key; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.urgency
    ADD CONSTRAINT urgency_urgency_code_key UNIQUE (urgency_code);


--
-- TOC entry 4989 (class 2606 OID 18843)
-- Name: display ux_display_lor_prop_id; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ux_display_lor_prop_id UNIQUE (lor_prop_id);


--
-- TOC entry 5022 (class 2606 OID 18434)
-- Name: work_area work_area_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT work_area_pkey PRIMARY KEY (work_area_id);


--
-- TOC entry 5047 (class 2606 OID 18973)
-- Name: work_order_status work_order_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT work_order_status_pkey PRIMARY KEY (work_order_status_id);


--
-- TOC entry 5038 (class 2606 OID 18697)
-- Name: work_order_completed_raw work_order_completed_raw_pkey; Type: CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_completed_raw
    ADD CONSTRAINT work_order_completed_raw_pkey PRIMARY KEY (src_row_num);


--
-- TOC entry 5055 (class 2606 OID 18987)
-- Name: work_order_intake work_order_intake_pkey; Type: CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT work_order_intake_pkey PRIMARY KEY (intake_id);


--
-- TOC entry 5036 (class 2606 OID 18662)
-- Name: work_order_todo_raw work_order_todo_raw_pkey; Type: CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_todo_raw
    ADD CONSTRAINT work_order_todo_raw_pkey PRIMARY KEY (src_row_num);


--
-- TOC entry 5110 (class 1259 OID 23034)
-- Name: ix_lor_snap_scene_lor_props_run; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scene_lor_props_run ON lor_snap.scene_lor_props USING btree (import_run_id);


--
-- TOC entry 5111 (class 1259 OID 23037)
-- Name: ix_lor_snap_scene_lor_props_run_preview; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_preview ON lor_snap.scene_lor_props USING btree (import_run_id, preview_id);


--
-- TOC entry 5112 (class 1259 OID 23036)
-- Name: ix_lor_snap_scene_lor_props_run_prop; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_prop ON lor_snap.scene_lor_props USING btree (import_run_id, prop_id);


--
-- TOC entry 5113 (class 1259 OID 23035)
-- Name: ix_lor_snap_scene_lor_props_run_scene; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_scene ON lor_snap.scene_lor_props USING btree (import_run_id, scene_id);


--
-- TOC entry 5107 (class 1259 OID 23031)
-- Name: ix_lor_snap_scenes_run; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scenes_run ON lor_snap.scenes USING btree (import_run_id);


--
-- TOC entry 5108 (class 1259 OID 23033)
-- Name: ix_lor_snap_scenes_run_preview; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scenes_run_preview ON lor_snap.scenes USING btree (import_run_id, preview_id);


--
-- TOC entry 5109 (class 1259 OID 23032)
-- Name: ix_lor_snap_scenes_run_scene; Type: INDEX; Schema: lor_snap; Owner: -
--

CREATE INDEX ix_lor_snap_scenes_run_scene ON lor_snap.scenes USING btree (import_run_id, scene_id);


--
-- TOC entry 5103 (class 1259 OID 20743)
-- Name: idx_container_batch_item_batch; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_container_batch_item_batch ON ops.container_label_batch_item USING btree (container_label_batch_id);


--
-- TOC entry 5104 (class 1259 OID 20781)
-- Name: idx_container_label_batch_item_batch; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_container_label_batch_item_batch ON ops.container_label_batch_item USING btree (container_label_batch_id);


--
-- TOC entry 5098 (class 1259 OID 20720)
-- Name: idx_container_label_batch_status; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_container_label_batch_status ON ops.container_label_batch USING btree (status);


--
-- TOC entry 5083 (class 1259 OID 20629)
-- Name: idx_container_label_print_container_id; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_container_label_print_container_id ON ops.container_label_print USING btree (container_id);


--
-- TOC entry 5084 (class 1259 OID 20630)
-- Name: idx_container_label_print_printed_at; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_container_label_print_printed_at ON ops.container_label_print USING btree (printed_at DESC);


--
-- TOC entry 5092 (class 1259 OID 20708)
-- Name: idx_display_batch_item_batch; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_display_batch_item_batch ON ops.display_label_batch_item USING btree (display_label_batch_id);


--
-- TOC entry 5093 (class 1259 OID 20762)
-- Name: idx_display_label_batch_item_batch; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_display_label_batch_item_batch ON ops.display_label_batch_item USING btree (display_label_batch_id);


--
-- TOC entry 5087 (class 1259 OID 20685)
-- Name: idx_display_label_batch_status; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_display_label_batch_status ON ops.display_label_batch USING btree (status);


--
-- TOC entry 5079 (class 1259 OID 20793)
-- Name: idx_display_label_print_display_id; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_display_label_print_display_id ON ops.display_label_print USING btree (display_id);


--
-- TOC entry 5080 (class 1259 OID 20609)
-- Name: idx_display_label_print_printed_at; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX idx_display_label_print_printed_at ON ops.display_label_print USING btree (printed_at DESC);


--
-- TOC entry 4993 (class 1259 OID 18956)
-- Name: ix_test_session_container_test_status; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_test_session_container_test_status ON ops.test_session USING btree (container_test_status_id);


--
-- TOC entry 4994 (class 1259 OID 17286)
-- Name: ix_test_session_pallet; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_test_session_pallet ON ops.test_session USING btree (container_id);


--
-- TOC entry 4995 (class 1259 OID 18082)
-- Name: ix_test_session_season_status; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_test_session_season_status ON ops.test_session USING btree (season_year, container_status_legacy);


--
-- TOC entry 4996 (class 1259 OID 17285)
-- Name: ix_test_session_status; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_test_session_status ON ops.test_session USING btree (season_year, container_status_legacy);


--
-- TOC entry 5056 (class 1259 OID 19866)
-- Name: ix_woa_person; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_woa_person ON ops.work_order_assignment USING btree (person_id);


--
-- TOC entry 5057 (class 1259 OID 19041)
-- Name: ix_woa_work_order; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_woa_work_order ON ops.work_order_assignment USING btree (work_order_id);


--
-- TOC entry 5064 (class 1259 OID 19095)
-- Name: ix_woom_work_order; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_woom_work_order ON ops.work_order_outbound_message USING btree (work_order_id, created_at DESC);


--
-- TOC entry 5023 (class 1259 OID 18584)
-- Name: ix_work_order_display_lor_prop_id; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_display_lor_prop_id ON ops.work_order USING btree (display_lor_prop_id);


--
-- TOC entry 5024 (class 1259 OID 18528)
-- Name: ix_work_order_open; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_open ON ops.work_order USING btree (date_completed) WHERE (date_completed IS NULL);


--
-- TOC entry 5025 (class 1259 OID 19799)
-- Name: ix_work_order_stage_open; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_stage_open ON ops.work_order USING btree (stage_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5026 (class 1259 OID 18531)
-- Name: ix_work_order_target_year; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_target_year ON ops.work_order USING btree (target_year);


--
-- TOC entry 5027 (class 1259 OID 19772)
-- Name: ix_work_order_urgency_open; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_urgency_open ON ops.work_order USING btree (urgency_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5028 (class 1259 OID 18530)
-- Name: ix_work_order_work_area_open; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_work_order_work_area_open ON ops.work_order USING btree (work_area_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5061 (class 1259 OID 19067)
-- Name: ix_wosh_work_order; Type: INDEX; Schema: ops; Owner: -
--

CREATE INDEX ix_wosh_work_order ON ops.work_order_status_history USING btree (work_order_id, changed_at DESC);


--
-- TOC entry 5006 (class 1259 OID 18350)
-- Name: ux_display_test_session_session_prop; Type: INDEX; Schema: ops; Owner: -
--

CREATE UNIQUE INDEX ux_display_test_session_session_prop ON ops.display_test_session USING btree (test_session_id, lor_prop_id);


--
-- TOC entry 5001 (class 1259 OID 18349)
-- Name: ux_test_session_season_container; Type: INDEX; Schema: ops; Owner: -
--

CREATE UNIQUE INDEX ux_test_session_season_container ON ops.test_session USING btree (season_year, container_id);


--
-- TOC entry 5058 (class 1259 OID 19865)
-- Name: ux_woa_active; Type: INDEX; Schema: ops; Owner: -
--

CREATE UNIQUE INDEX ux_woa_active ON ops.work_order_assignment USING btree (work_order_id, person_id) WHERE (active_flag = true);


--
-- TOC entry 5029 (class 1259 OID 18772)
-- Name: ux_work_order_open_per_checklist_line; Type: INDEX; Schema: ops; Owner: -
--

CREATE UNIQUE INDEX ux_work_order_open_per_checklist_line ON ops.work_order USING btree (display_test_session_id) WHERE ((display_test_session_id IS NOT NULL) AND (date_completed IS NULL));


--
-- TOC entry 4970 (class 1259 OID 17192)
-- Name: idx_person_personal_email; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX idx_person_personal_email ON ref.person USING btree (personal_email);


--
-- TOC entry 4976 (class 1259 OID 16988)
-- Name: ix_person_xref_email; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX ix_person_xref_email ON ref.person_xref USING btree (lower(email));


--
-- TOC entry 4977 (class 1259 OID 16987)
-- Name: ix_person_xref_person_id; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX ix_person_xref_person_id ON ref.person_xref USING btree (person_id);


--
-- TOC entry 5007 (class 1259 OID 18161)
-- Name: ix_ref_stage_parent; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX ix_ref_stage_parent ON ref.stage USING btree (parent_stage_key);


--
-- TOC entry 5008 (class 1259 OID 18131)
-- Name: ix_stage_order; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX ix_stage_order ON ref.stage USING btree (park_order, sub_order);


--
-- TOC entry 5032 (class 1259 OID 18567)
-- Name: spare_channel_lor_prop_id_idx; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX spare_channel_lor_prop_id_idx ON ref.spare_channel USING btree (lor_prop_id);


--
-- TOC entry 4963 (class 1259 OID 18749)
-- Name: ux_container_location_code_non_zone; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_container_location_code_non_zone ON ref.container USING btree (location_code) WHERE ((location_code IS NOT NULL) AND (location_code !~~ 'Z-%'::text));


--
-- TOC entry 4968 (class 1259 OID 18332)
-- Name: ux_location_rack_slot; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_location_rack_slot ON ref.storage_location USING btree (rack_row_code, column_num, shelf_level_code, slot_bin_num) WHERE (type_code = 'R'::text);


--
-- TOC entry 4975 (class 1259 OID 16967)
-- Name: ux_person_email; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_person_email ON ref.person USING btree (lower(email)) WHERE ((email IS NOT NULL) AND (btrim(email) <> ''::text));


--
-- TOC entry 4990 (class 1259 OID 18583)
-- Name: ux_ref_display_display_name; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_ref_display_display_name ON ref.display USING btree (upper(btrim(display_name))) WHERE ((display_name IS NOT NULL) AND (btrim(display_name) <> ''::text));


--
-- TOC entry 4991 (class 1259 OID 17255)
-- Name: ux_ref_display_lor_prop_id; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_ref_display_lor_prop_id ON ref.display USING btree (lor_prop_id);


--
-- TOC entry 4992 (class 1259 OID 18731)
-- Name: ux_ref_display_name; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_ref_display_name ON ref.display USING btree (display_name);


--
-- TOC entry 4969 (class 1259 OID 18315)
-- Name: ux_storage_location_code; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_storage_location_code ON ref.storage_location USING btree (location_code);


--
-- TOC entry 5019 (class 1259 OID 18405)
-- Name: ux_task_type_key; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_task_type_key ON ref.task_type USING btree (upper(btrim(task_type_key)));


--
-- TOC entry 5020 (class 1259 OID 18435)
-- Name: ux_work_area_key; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_work_area_key ON ref.work_area USING btree (upper(btrim(work_area_key)));


--
-- TOC entry 5045 (class 1259 OID 18974)
-- Name: ux_work_order_status_key; Type: INDEX; Schema: ref; Owner: -
--

CREATE UNIQUE INDEX ux_work_order_status_key ON ref.work_order_status USING btree (upper(btrim(status_key)));


--
-- TOC entry 5048 (class 1259 OID 19003)
-- Name: ix_intake_submitted_at; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_intake_submitted_at ON stage.work_order_intake USING btree (submitted_at DESC);


--
-- TOC entry 5049 (class 1259 OID 19654)
-- Name: ix_work_order_intake_stage_id; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_work_order_intake_stage_id ON stage.work_order_intake USING btree (stage_id);


--
-- TOC entry 5050 (class 1259 OID 19876)
-- Name: ix_work_order_intake_submitter_person; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_work_order_intake_submitter_person ON stage.work_order_intake USING btree (submitter_person_id);


--
-- TOC entry 5051 (class 1259 OID 19656)
-- Name: ix_work_order_intake_task_type_id; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_work_order_intake_task_type_id ON stage.work_order_intake USING btree (task_type_id);


--
-- TOC entry 5052 (class 1259 OID 19657)
-- Name: ix_work_order_intake_urgency_id; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_work_order_intake_urgency_id ON stage.work_order_intake USING btree (urgency_id);


--
-- TOC entry 5053 (class 1259 OID 19655)
-- Name: ix_work_order_intake_work_area_id; Type: INDEX; Schema: stage; Owner: -
--

CREATE INDEX ix_work_order_intake_work_area_id ON stage.work_order_intake USING btree (work_area_id);


--
-- TOC entry 5255 (class 2620 OID 19556)
-- Name: test_session trg_after_refresh_test_session; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_after_refresh_test_session AFTER UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_after_refresh_test_session();


--
-- TOC entry 5256 (class 2620 OID 19303)
-- Name: test_session trg_after_start_container_pull; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_after_start_container_pull AFTER UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_after_start_container_pull();


--
-- TOC entry 5261 (class 2620 OID 19144)
-- Name: display_test_session trg_display_test_session_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_display_test_session_set_actor_insert BEFORE INSERT ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5262 (class 2620 OID 19191)
-- Name: display_test_session trg_display_test_session_set_actor_update; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_display_test_session_set_actor_update BEFORE UPDATE ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5263 (class 2620 OID 19176)
-- Name: display_test_session trg_display_test_session_set_checked_actor; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_display_test_session_set_checked_actor BEFORE UPDATE ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ops.set_checked_actor();


--
-- TOC entry 5257 (class 2620 OID 19298)
-- Name: test_session trg_set_container_search_helper; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_set_container_search_helper BEFORE INSERT OR UPDATE OF container_id ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.set_container_search_helper();


--
-- TOC entry 5258 (class 2620 OID 19302)
-- Name: test_session trg_start_container_pull; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_start_container_pull BEFORE UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_start_container_pull();


--
-- TOC entry 5259 (class 2620 OID 19145)
-- Name: test_session trg_test_session_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_test_session_set_actor_insert BEFORE INSERT ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5260 (class 2620 OID 19192)
-- Name: test_session trg_test_session_set_actor_update; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_test_session_set_actor_update BEFORE UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5264 (class 2620 OID 19561)
-- Name: display_test_session trg_validate_display_test_session_notes; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_validate_display_test_session_notes BEFORE INSERT OR UPDATE OF test_status, notes ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_validate_display_test_session_notes();


--
-- TOC entry 5283 (class 2620 OID 19825)
-- Name: work_order_assignment trg_work_order_assignment_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_assignment_set_actor_insert BEFORE INSERT ON ops.work_order_assignment FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5284 (class 2620 OID 19826)
-- Name: work_order_assignment trg_work_order_assignment_set_actor_update; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_assignment_set_actor_update BEFORE UPDATE ON ops.work_order_assignment FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5272 (class 2620 OID 19575)
-- Name: work_order trg_work_order_autofill_completion_on_repair_complete; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_autofill_completion_on_repair_complete BEFORE UPDATE ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete();


--
-- TOC entry 5286 (class 2620 OID 19119)
-- Name: work_order_outbound_message trg_work_order_outbound_message_set_updated; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_outbound_message_set_updated BEFORE UPDATE ON ops.work_order_outbound_message FOR EACH ROW EXECUTE FUNCTION ref.set_updated_fields();


--
-- TOC entry 5273 (class 2620 OID 19823)
-- Name: work_order trg_work_order_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_set_actor_insert BEFORE INSERT ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5274 (class 2620 OID 19824)
-- Name: work_order trg_work_order_set_actor_update; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_set_actor_update BEFORE UPDATE ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5285 (class 2620 OID 19124)
-- Name: work_order_status_history trg_work_order_status_history_set_updated; Type: TRIGGER; Schema: ops; Owner: -
--

CREATE TRIGGER trg_work_order_status_history_set_updated BEFORE UPDATE ON ops.work_order_status_history FOR EACH ROW EXECUTE FUNCTION ref.set_updated_fields();


--
-- TOC entry 5287 (class 2620 OID 19226)
-- Name: audit_collection_policy trg_audit_collection_policy_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_audit_collection_policy_set_actor_insert BEFORE INSERT ON ref.audit_collection_policy FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5288 (class 2620 OID 19225)
-- Name: audit_collection_policy trg_audit_collection_policy_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_audit_collection_policy_set_actor_update BEFORE UPDATE ON ref.audit_collection_policy FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5266 (class 2620 OID 19172)
-- Name: container_endpoint trg_container_endpoint_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_endpoint_set_actor_insert BEFORE INSERT ON ref.container_endpoint FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5267 (class 2620 OID 19174)
-- Name: container_endpoint trg_container_endpoint_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_endpoint_set_actor_update BEFORE UPDATE ON ref.container_endpoint FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5246 (class 2620 OID 19177)
-- Name: container trg_container_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_set_actor_insert BEFORE INSERT ON ref.container FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5247 (class 2620 OID 19178)
-- Name: container trg_container_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_set_actor_update BEFORE UPDATE ON ref.container FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5277 (class 2620 OID 19195)
-- Name: container_test_status trg_container_test_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_test_status_set_actor_insert BEFORE INSERT ON ref.container_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5278 (class 2620 OID 19196)
-- Name: container_test_status trg_container_test_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_test_status_set_actor_update BEFORE UPDATE ON ref.container_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5244 (class 2620 OID 19183)
-- Name: container_type trg_container_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_type_set_actor_insert BEFORE INSERT ON ref.container_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5245 (class 2620 OID 19184)
-- Name: container_type trg_container_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_container_type_set_actor_update BEFORE UPDATE ON ref.container_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5254 (class 2620 OID 19180)
-- Name: display trg_display_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_display_set_actor_update BEFORE UPDATE ON ref.display FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5242 (class 2620 OID 19185)
-- Name: display_status trg_display_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_display_status_set_actor_insert BEFORE INSERT ON ref.display_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5243 (class 2620 OID 19186)
-- Name: display_status trg_display_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_display_status_set_actor_update BEFORE UPDATE ON ref.display_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5275 (class 2620 OID 19197)
-- Name: display_test_status trg_display_test_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_display_test_status_set_actor_insert BEFORE INSERT ON ref.display_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5276 (class 2620 OID 19198)
-- Name: display_test_status trg_display_test_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_display_test_status_set_actor_update BEFORE UPDATE ON ref.display_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5238 (class 2620 OID 19187)
-- Name: frame trg_frame_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_frame_set_actor_insert BEFORE INSERT ON ref.frame FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5239 (class 2620 OID 19188)
-- Name: frame trg_frame_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_frame_set_actor_update BEFORE UPDATE ON ref.frame FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5252 (class 2620 OID 19199)
-- Name: inventory_type trg_inventory_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_inventory_type_set_actor_insert BEFORE INSERT ON ref.inventory_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5253 (class 2620 OID 19200)
-- Name: inventory_type trg_inventory_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_inventory_type_set_actor_update BEFORE UPDATE ON ref.inventory_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5250 (class 2620 OID 19189)
-- Name: person trg_person_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_person_set_actor_insert BEFORE INSERT ON ref.person FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5251 (class 2620 OID 19190)
-- Name: person trg_person_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_person_set_actor_update BEFORE UPDATE ON ref.person FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5289 (class 2620 OID 19494)
-- Name: season trg_season_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_season_set_actor_insert BEFORE INSERT ON ref.season FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5290 (class 2620 OID 19495)
-- Name: season trg_season_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_season_set_actor_update BEFORE UPDATE ON ref.season FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5265 (class 2620 OID 19182)
-- Name: stage trg_stage_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_stage_set_actor_update BEFORE UPDATE ON ref.stage FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5249 (class 2620 OID 19181)
-- Name: storage_location trg_storage_location_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_storage_location_set_actor_update BEFORE UPDATE ON ref.storage_location FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5248 (class 2620 OID 19300)
-- Name: container trg_sync_container_search_helper_to_test_session; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_sync_container_search_helper_to_test_session AFTER UPDATE OF description ON ref.container FOR EACH ROW WHEN ((old.description IS DISTINCT FROM new.description)) EXECUTE FUNCTION ref.sync_container_search_helper_to_test_session();


--
-- TOC entry 5268 (class 2620 OID 19201)
-- Name: task_type trg_task_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_task_type_set_actor_insert BEFORE INSERT ON ref.task_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5269 (class 2620 OID 19202)
-- Name: task_type trg_task_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_task_type_set_actor_update BEFORE UPDATE ON ref.task_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5240 (class 2620 OID 19193)
-- Name: theme trg_theme_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_theme_set_actor_insert BEFORE INSERT ON ref.theme FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5241 (class 2620 OID 19194)
-- Name: theme trg_theme_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_theme_set_actor_update BEFORE UPDATE ON ref.theme FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5270 (class 2620 OID 19203)
-- Name: work_area trg_work_area_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_work_area_set_actor_insert BEFORE INSERT ON ref.work_area FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5271 (class 2620 OID 19204)
-- Name: work_area trg_work_area_set_actor_update; Type: TRIGGER; Schema: ref; Owner: -
--

CREATE TRIGGER trg_work_area_set_actor_update BEFORE UPDATE ON ref.work_area FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5279 (class 2620 OID 20088)
-- Name: work_order_intake trg_process_work_order_intake_on_triage; Type: TRIGGER; Schema: stage; Owner: -
--

CREATE TRIGGER trg_process_work_order_intake_on_triage AFTER UPDATE OF triage_dropdown ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_process_work_order_intake_on_triage();


--
-- TOC entry 5280 (class 2620 OID 20098)
-- Name: work_order_intake trg_resolve_work_order_intake_submitter; Type: TRIGGER; Schema: stage; Owner: -
--

CREATE TRIGGER trg_resolve_work_order_intake_submitter BEFORE INSERT OR UPDATE OF submitter_email_raw, submitter_person_id, created_by_person_id ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_resolve_work_order_intake_submitter();


--
-- TOC entry 5281 (class 2620 OID 19845)
-- Name: work_order_intake trg_work_order_intake_set_actor_insert; Type: TRIGGER; Schema: stage; Owner: -
--

CREATE TRIGGER trg_work_order_intake_set_actor_insert BEFORE INSERT ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5282 (class 2620 OID 19846)
-- Name: work_order_intake trg_work_order_intake_set_actor_update; Type: TRIGGER; Schema: stage; Owner: -
--

CREATE TRIGGER trg_work_order_intake_set_actor_update BEFORE UPDATE ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5120 (class 2606 OID 16464)
-- Name: dmx_channels dmx_channels_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5121 (class 2606 OID 16474)
-- Name: dmx_channels dmx_channels_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5122 (class 2606 OID 16469)
-- Name: dmx_channels dmx_channels_import_run_id_prop_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_prop_id_fkey FOREIGN KEY (import_run_id, prop_id) REFERENCES lor_snap.props(import_run_id, prop_id) ON DELETE RESTRICT;


--
-- TOC entry 5237 (class 2606 OID 23026)
-- Name: scene_lor_props fk_scene_lor_props_import_run; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.scene_lor_props
    ADD CONSTRAINT fk_scene_lor_props_import_run FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5236 (class 2606 OID 23016)
-- Name: scenes fk_scenes_import_run; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.scenes
    ADD CONSTRAINT fk_scenes_import_run FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5114 (class 2606 OID 16409)
-- Name: previews previews_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5115 (class 2606 OID 16423)
-- Name: props props_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5116 (class 2606 OID 16428)
-- Name: props props_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5117 (class 2606 OID 16442)
-- Name: sub_props sub_props_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5118 (class 2606 OID 16447)
-- Name: sub_props sub_props_import_run_id_master_prop_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_master_prop_id_fkey FOREIGN KEY (import_run_id, master_prop_id) REFERENCES lor_snap.props(import_run_id, prop_id) ON DELETE RESTRICT;


--
-- TOC entry 5119 (class 2606 OID 16452)
-- Name: sub_props sub_props_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: -
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5232 (class 2606 OID 20738)
-- Name: container_label_batch_item container_label_batch_item_container_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_id_fkey FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5233 (class 2606 OID 20733)
-- Name: container_label_batch_item container_label_batch_item_container_label_batch_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_label_batch_id_fkey FOREIGN KEY (container_label_batch_id) REFERENCES ops.container_label_batch(container_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5227 (class 2606 OID 20703)
-- Name: display_label_batch_item display_label_batch_item_display_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_id_fkey FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5228 (class 2606 OID 20698)
-- Name: display_label_batch_item display_label_batch_item_display_label_batch_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_label_batch_id_fkey FOREIGN KEY (display_label_batch_id) REFERENCES ops.display_label_batch(display_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5165 (class 2606 OID 17299)
-- Name: display_test_session display_test_session_test_session_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT display_test_session_test_session_id_fkey FOREIGN KEY (test_session_id) REFERENCES ops.test_session(test_session_id) ON DELETE CASCADE;


--
-- TOC entry 5234 (class 2606 OID 20768)
-- Name: container_label_batch_item fk_container_label_batch_item_batch; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT fk_container_label_batch_item_batch FOREIGN KEY (container_label_batch_id) REFERENCES ops.container_label_batch(container_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5235 (class 2606 OID 20773)
-- Name: container_label_batch_item fk_container_label_batch_item_container; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT fk_container_label_batch_item_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5231 (class 2606 OID 20763)
-- Name: container_label_batch fk_container_label_batch_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_batch
    ADD CONSTRAINT fk_container_label_batch_person FOREIGN KEY (started_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5224 (class 2606 OID 20812)
-- Name: container_label_print fk_container_label_print_container; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT fk_container_label_print_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON DELETE SET NULL;


--
-- TOC entry 5225 (class 2606 OID 20668)
-- Name: container_label_print fk_container_label_print_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT fk_container_label_print_person FOREIGN KEY (printed_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5229 (class 2606 OID 20750)
-- Name: display_label_batch_item fk_display_label_batch_item_batch; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT fk_display_label_batch_item_batch FOREIGN KEY (display_label_batch_id) REFERENCES ops.display_label_batch(display_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5230 (class 2606 OID 20755)
-- Name: display_label_batch_item fk_display_label_batch_item_display; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT fk_display_label_batch_item_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5226 (class 2606 OID 20745)
-- Name: display_label_batch fk_display_label_batch_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_batch
    ADD CONSTRAINT fk_display_label_batch_person FOREIGN KEY (started_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5222 (class 2606 OID 20817)
-- Name: display_label_print fk_display_label_print_display; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT fk_display_label_print_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON DELETE SET NULL;


--
-- TOC entry 5223 (class 2606 OID 20663)
-- Name: display_label_print fk_display_label_print_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT fk_display_label_print_person FOREIGN KEY (printed_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5166 (class 2606 OID 19267)
-- Name: display_test_session fk_display_test_session_checked_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_checked_by_person FOREIGN KEY (checked_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5167 (class 2606 OID 19257)
-- Name: display_test_session fk_display_test_session_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5168 (class 2606 OID 18933)
-- Name: display_test_session fk_display_test_session_stage; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5169 (class 2606 OID 18928)
-- Name: display_test_session fk_display_test_session_test_status; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_test_status FOREIGN KEY (test_status) REFERENCES ref.display_test_status(test_status_code);


--
-- TOC entry 5170 (class 2606 OID 19262)
-- Name: display_test_session fk_display_test_session_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5156 (class 2606 OID 19527)
-- Name: test_session fk_test_session_container; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id);


--
-- TOC entry 5157 (class 2606 OID 18951)
-- Name: test_session fk_test_session_container_test_status; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_container_test_status FOREIGN KEY (container_test_status_id) REFERENCES ref.container_test_status(container_test_status_id);


--
-- TOC entry 5158 (class 2606 OID 19247)
-- Name: test_session fk_test_session_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5159 (class 2606 OID 19532)
-- Name: test_session fk_test_session_home_location; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_home_location FOREIGN KEY (home_location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5160 (class 2606 OID 19549)
-- Name: test_session fk_test_session_last_refreshed_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_last_refreshed_by_person FOREIGN KEY (last_refreshed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5161 (class 2606 OID 19497)
-- Name: test_session fk_test_session_pulled_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_pulled_by_person FOREIGN KEY (pulled_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5162 (class 2606 OID 19522)
-- Name: test_session fk_test_session_season; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_season FOREIGN KEY (season_year) REFERENCES ref.season(season_year);


--
-- TOC entry 5163 (class 2606 OID 19252)
-- Name: test_session fk_test_session_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5164 (class 2606 OID 19537)
-- Name: test_session fk_test_session_work_location; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_work_location FOREIGN KEY (work_location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5206 (class 2606 OID 19923)
-- Name: work_order_assignment fk_woa_assigned_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_assigned_by FOREIGN KEY (assigned_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5207 (class 2606 OID 19918)
-- Name: work_order_assignment fk_woa_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_person FOREIGN KEY (person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5208 (class 2606 OID 19928)
-- Name: work_order_assignment fk_woa_unassigned_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_unassigned_by FOREIGN KEY (unassigned_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5209 (class 2606 OID 20126)
-- Name: work_order_assignment fk_woa_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5215 (class 2606 OID 19085)
-- Name: work_order_outbound_message fk_woom_created_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_created_by FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5216 (class 2606 OID 19090)
-- Name: work_order_outbound_message fk_woom_updated_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_updated_by FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5217 (class 2606 OID 19080)
-- Name: work_order_outbound_message fk_woom_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5210 (class 2606 OID 19933)
-- Name: work_order_assignment fk_work_order_assignment_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_work_order_assignment_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5211 (class 2606 OID 19938)
-- Name: work_order_assignment fk_work_order_assignment_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_work_order_assignment_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5180 (class 2606 OID 19903)
-- Name: work_order fk_work_order_completed_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_completed_by FOREIGN KEY (completed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5181 (class 2606 OID 19908)
-- Name: work_order fk_work_order_created_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_created_by FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5182 (class 2606 OID 18762)
-- Name: work_order fk_work_order_display; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5183 (class 2606 OID 18846)
-- Name: work_order fk_work_order_display_lor_prop; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_display_lor_prop FOREIGN KEY (display_lor_prop_id) REFERENCES ref.display(lor_prop_id);


--
-- TOC entry 5184 (class 2606 OID 18767)
-- Name: work_order fk_work_order_display_test_session; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_display_test_session FOREIGN KEY (display_test_session_id) REFERENCES ops.display_test_session(display_test_session_id);


--
-- TOC entry 5218 (class 2606 OID 19282)
-- Name: work_order_outbound_message fk_work_order_outbound_message_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_work_order_outbound_message_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5219 (class 2606 OID 19287)
-- Name: work_order_outbound_message fk_work_order_outbound_message_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_work_order_outbound_message_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5185 (class 2606 OID 19814)
-- Name: work_order fk_work_order_stage; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5186 (class 2606 OID 20038)
-- Name: work_order fk_work_order_submitted_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_submitted_by_person FOREIGN KEY (submitted_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5187 (class 2606 OID 18504)
-- Name: work_order fk_work_order_task_type; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_task_type FOREIGN KEY (task_type_id) REFERENCES ref.task_type(task_type_id);


--
-- TOC entry 5188 (class 2606 OID 20089)
-- Name: work_order fk_work_order_triaged_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_triaged_by_person FOREIGN KEY (triaged_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5189 (class 2606 OID 19913)
-- Name: work_order fk_work_order_updated_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_updated_by FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5190 (class 2606 OID 19787)
-- Name: work_order fk_work_order_urgency; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_urgency FOREIGN KEY (urgency_id) REFERENCES ref.urgency(urgency_id);


--
-- TOC entry 5191 (class 2606 OID 18499)
-- Name: work_order fk_work_order_work_area; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_work_area FOREIGN KEY (work_area_id) REFERENCES ref.work_area(work_area_id);


--
-- TOC entry 5212 (class 2606 OID 19062)
-- Name: work_order_status_history fk_wosh_changed_by; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_changed_by FOREIGN KEY (changed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5213 (class 2606 OID 19057)
-- Name: work_order_status_history fk_wosh_status; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_status FOREIGN KEY (work_order_status_id) REFERENCES ref.work_order_status(work_order_status_id);


--
-- TOC entry 5214 (class 2606 OID 19052)
-- Name: work_order_status_history fk_wosh_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5171 (class 2606 OID 18742)
-- Name: display_test_session ops_display_test_session_display_id_fk; Type: FK CONSTRAINT; Schema: ops; Owner: -
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT ops_display_test_session_display_id_fk FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5220 (class 2606 OID 19227)
-- Name: audit_collection_policy fk_audit_collection_policy_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT fk_audit_collection_policy_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5221 (class 2606 OID 19232)
-- Name: audit_collection_policy fk_audit_collection_policy_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT fk_audit_collection_policy_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5131 (class 2606 OID 19324)
-- Name: container fk_container_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5174 (class 2606 OID 19242)
-- Name: container_endpoint fk_container_endpoint_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT fk_container_endpoint_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5175 (class 2606 OID 19237)
-- Name: container_endpoint fk_container_endpoint_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT fk_container_endpoint_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5132 (class 2606 OID 18915)
-- Name: container fk_container_goes_to_endpoint; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_goes_to_endpoint FOREIGN KEY (goes_to_endpoint_id) REFERENCES ref.container_endpoint(endpoint_id);


--
-- TOC entry 5133 (class 2606 OID 21095)
-- Name: container fk_container_label_print_last_by_cached_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_label_print_last_by_cached_person FOREIGN KEY (label_print_last_by_cached_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5129 (class 2606 OID 19334)
-- Name: container_type fk_container_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT fk_container_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5130 (class 2606 OID 19339)
-- Name: container_type fk_container_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT fk_container_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5134 (class 2606 OID 19329)
-- Name: container fk_container_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5146 (class 2606 OID 19344)
-- Name: display fk_display_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5147 (class 2606 OID 17204)
-- Name: display fk_display_designer; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_designer FOREIGN KEY (designer_id) REFERENCES ref.person(person_id) ON DELETE SET NULL;


--
-- TOC entry 5148 (class 2606 OID 17199)
-- Name: display fk_display_frame; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_frame FOREIGN KEY (frame_id) REFERENCES ref.frame(frame_id);


--
-- TOC entry 5149 (class 2606 OID 17062)
-- Name: display fk_display_inventory_type; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_inventory_type FOREIGN KEY (inventory_type) REFERENCES ref.inventory_type(inventory_type);


--
-- TOC entry 5150 (class 2606 OID 21090)
-- Name: display fk_display_label_print_last_by_cached_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_label_print_last_by_cached_person FOREIGN KEY (label_print_last_by_cached_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5151 (class 2606 OID 17077)
-- Name: display fk_display_pallet; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_pallet FOREIGN KEY (container_id) REFERENCES ref.container(container_id);


--
-- TOC entry 5152 (class 2606 OID 17067)
-- Name: display fk_display_status; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_status FOREIGN KEY (display_status_id) REFERENCES ref.display_status(display_status_id);


--
-- TOC entry 5127 (class 2606 OID 19354)
-- Name: display_status fk_display_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT fk_display_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5128 (class 2606 OID 19359)
-- Name: display_status fk_display_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT fk_display_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5194 (class 2606 OID 19364)
-- Name: display_test_status fk_display_test_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT fk_display_test_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5195 (class 2606 OID 19369)
-- Name: display_test_status fk_display_test_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT fk_display_test_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5153 (class 2606 OID 17194)
-- Name: display fk_display_theme; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_theme FOREIGN KEY (theme_id) REFERENCES ref.theme(theme_id);


--
-- TOC entry 5154 (class 2606 OID 19349)
-- Name: display fk_display_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5123 (class 2606 OID 19374)
-- Name: frame fk_frame_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT fk_frame_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5124 (class 2606 OID 19379)
-- Name: frame fk_frame_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT fk_frame_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5144 (class 2606 OID 19384)
-- Name: inventory_type fk_inventory_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT fk_inventory_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5145 (class 2606 OID 19389)
-- Name: inventory_type fk_inventory_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT fk_inventory_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5135 (class 2606 OID 18316)
-- Name: container fk_pallet_location; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_pallet_location FOREIGN KEY (location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5139 (class 2606 OID 19394)
-- Name: person fk_person_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT fk_person_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5140 (class 2606 OID 19399)
-- Name: person fk_person_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT fk_person_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5141 (class 2606 OID 19404)
-- Name: person_xref fk_person_xref_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT fk_person_xref_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5142 (class 2606 OID 19409)
-- Name: person_xref fk_person_xref_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT fk_person_xref_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5192 (class 2606 OID 19414)
-- Name: spare_channel fk_spare_channel_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT fk_spare_channel_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5193 (class 2606 OID 19419)
-- Name: spare_channel fk_spare_channel_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT fk_spare_channel_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5172 (class 2606 OID 19424)
-- Name: stage fk_stage_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT fk_stage_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5173 (class 2606 OID 19429)
-- Name: stage fk_stage_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT fk_stage_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5137 (class 2606 OID 19434)
-- Name: storage_location fk_storage_location_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT fk_storage_location_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5138 (class 2606 OID 19439)
-- Name: storage_location fk_storage_location_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT fk_storage_location_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5176 (class 2606 OID 19444)
-- Name: task_type fk_task_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT fk_task_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5177 (class 2606 OID 19449)
-- Name: task_type fk_task_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT fk_task_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5125 (class 2606 OID 19454)
-- Name: theme fk_theme_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT fk_theme_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5126 (class 2606 OID 19459)
-- Name: theme fk_theme_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT fk_theme_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5178 (class 2606 OID 19464)
-- Name: work_area fk_work_area_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT fk_work_area_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5179 (class 2606 OID 19469)
-- Name: work_area fk_work_area_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT fk_work_area_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5196 (class 2606 OID 19474)
-- Name: work_order_status fk_work_order_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT fk_work_order_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5197 (class 2606 OID 19479)
-- Name: work_order_status fk_work_order_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT fk_work_order_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5136 (class 2606 OID 16834)
-- Name: container pallet_pallet_type_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT pallet_pallet_type_id_fkey FOREIGN KEY (container_type_id) REFERENCES ref.container_type(container_type_id);


--
-- TOC entry 5143 (class 2606 OID 16980)
-- Name: person_xref person_xref_person_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT person_xref_person_id_fkey FOREIGN KEY (person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5155 (class 2606 OID 18335)
-- Name: display ref_display_stage_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ref_display_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 5198 (class 2606 OID 19943)
-- Name: work_order_intake fk_intake_triaged_by; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_intake_triaged_by FOREIGN KEY (triaged_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5199 (class 2606 OID 19987)
-- Name: work_order_intake fk_work_order_intake_created_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5200 (class 2606 OID 19634)
-- Name: work_order_intake fk_work_order_intake_stage; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5201 (class 2606 OID 19948)
-- Name: work_order_intake fk_work_order_intake_submitter_person; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_submitter_person FOREIGN KEY (submitter_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5202 (class 2606 OID 19644)
-- Name: work_order_intake fk_work_order_intake_task_type; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_task_type FOREIGN KEY (task_type_id) REFERENCES ref.task_type(task_type_id);


--
-- TOC entry 5203 (class 2606 OID 19992)
-- Name: work_order_intake fk_work_order_intake_updated_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5204 (class 2606 OID 19649)
-- Name: work_order_intake fk_work_order_intake_urgency; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_urgency FOREIGN KEY (urgency_id) REFERENCES ref.urgency(urgency_id);


--
-- TOC entry 5205 (class 2606 OID 19639)
-- Name: work_order_intake fk_work_order_intake_work_area; Type: FK CONSTRAINT; Schema: stage; Owner: -
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_work_area FOREIGN KEY (work_area_id) REFERENCES ref.work_area(work_area_id);


-- Completed on 2026-07-31 08:06:30

--
-- PostgreSQL database dump complete
--

\unrestrict uaNgop6UwyfdJZRis2g9cNEF2lwlH1lO9Mb4Ajx9bxYVSQnJtfcaA3Sv9Z8HYQh

