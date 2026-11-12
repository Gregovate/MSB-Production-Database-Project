BEGIN;

CREATE TABLE IF NOT EXISTS ops.setup_pick_list_delay (
    setup_pick_list_delay_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    container_id integer NOT NULL,
    release_setup_session_task_ids bigint[] NOT NULL,
    delay_reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_pick_list_delay_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_setup_pick_list_delay_container
        FOREIGN KEY (container_id)
        REFERENCES ref.container(container_id),
    CONSTRAINT fk_setup_pick_list_delay_created_by_person
        FOREIGN KEY (created_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_pick_list_delay_updated_by_person
        FOREIGN KEY (updated_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT uq_setup_pick_list_delay_session_container
        UNIQUE (setup_session_id, container_id),
    CONSTRAINT ck_setup_pick_list_delay_reason
        CHECK (btrim(delay_reason) <> ''),
    CONSTRAINT ck_setup_pick_list_delay_release_tasks
        CHECK (cardinality(release_setup_session_task_ids) > 0)
);

COMMENT ON TABLE ops.setup_pick_list_delay IS
'Transient annual Pick List logistics hold. Presence means DO NOT PICK YET. The row is deleted when a Manager resumes the pick or when a requiring downstream task is scheduled; it is not reusable or annual scheduling knowledge.';

DROP TRIGGER IF EXISTS trg_setup_pick_list_delay_actor_insert
    ON ops.setup_pick_list_delay;
CREATE TRIGGER trg_setup_pick_list_delay_actor_insert
BEFORE INSERT ON ops.setup_pick_list_delay
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_pick_list_delay_actor_update
    ON ops.setup_pick_list_delay;
CREATE TRIGGER trg_setup_pick_list_delay_actor_update
BEFORE UPDATE ON ops.setup_pick_list_delay
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE OR REPLACE FUNCTION ops.set_setup_pick_list_delay(
    p_email text,
    p_season_year integer,
    p_container_id integer,
    p_release_setup_session_task_ids bigint[],
    p_delay_reason text,
    p_delayed boolean DEFAULT true
)
RETURNS TABLE (
    setup_pick_list_delay_id bigint,
    setup_session_id bigint,
    container_id integer,
    release_setup_session_task_ids bigint[],
    delay_reason text,
    delayed boolean,
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
    v_delay_id bigint;
    v_delay_row ops.setup_pick_list_delay%ROWTYPE;
    v_reason text := nullif(btrim(p_delay_reason), '');
    v_release_ids bigint[];
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year
      AND ss.session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION');

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Open Setup Session was not found for this season';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.container c
        WHERE c.container_id = p_container_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Container was not found';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF coalesce(p_delayed, true) THEN
        IF v_reason IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Pick Delay reason is required';
        END IF;

        SELECT array_agg(DISTINCT x ORDER BY x)
          INTO v_release_ids
        FROM unnest(coalesce(p_release_setup_session_task_ids, ARRAY[]::bigint[])) AS x;

        IF coalesce(cardinality(v_release_ids), 0) = 0 THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Pick Delay requires at least one downstream task identity';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM unnest(v_release_ids) AS x
            LEFT JOIN ops.setup_session_task st
              ON st.setup_session_task_id = x
            WHERE st.setup_session_task_id IS NULL
               OR st.setup_session_id <> v_session_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23503',
                MESSAGE = 'Pick Delay release task must belong to the selected Setup Session';
        END IF;

        INSERT INTO ops.setup_pick_list_delay(
            setup_session_id,
            container_id,
            release_setup_session_task_ids,
            delay_reason
        ) VALUES (
            v_session_id,
            p_container_id,
            v_release_ids,
            v_reason
        )
        ON CONFLICT ON CONSTRAINT uq_setup_pick_list_delay_session_container
        DO UPDATE SET
            release_setup_session_task_ids = EXCLUDED.release_setup_session_task_ids,
            delay_reason = EXCLUDED.delay_reason
        RETURNING ops.setup_pick_list_delay.setup_pick_list_delay_id
          INTO v_delay_id;

        RETURN QUERY
        SELECT
            d.setup_pick_list_delay_id,
            d.setup_session_id,
            d.container_id,
            d.release_setup_session_task_ids,
            d.delay_reason,
            true,
            v_display_name
        FROM ops.setup_pick_list_delay d
        WHERE d.setup_pick_list_delay_id = v_delay_id;
        RETURN;
    END IF;

    DELETE FROM ops.setup_pick_list_delay d
     WHERE d.setup_session_id = v_session_id
       AND d.container_id = p_container_id
    RETURNING d.* INTO v_delay_row;

    IF v_delay_row.setup_pick_list_delay_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Pick Delay was not found for this Container';
    END IF;

    RETURN QUERY
    SELECT
        v_delay_row.setup_pick_list_delay_id,
        v_delay_row.setup_session_id,
        v_delay_row.container_id,
        v_delay_row.release_setup_session_task_ids,
        v_delay_row.delay_reason,
        false,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_pick_list_delay(
    text,integer,integer,bigint[],text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_pick_list_delay(
    text,integer,integer,bigint[],text,boolean
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.clear_setup_pick_list_delay_on_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_session_id bigint;
BEGIN
    SELECT wd.setup_session_id
      INTO v_session_id
    FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = NEW.setup_work_day_id;

    IF v_session_id IS NOT NULL THEN
        DELETE FROM ops.setup_pick_list_delay d
         WHERE d.setup_session_id = v_session_id
           AND NEW.setup_session_task_id = ANY(d.release_setup_session_task_ids);
    END IF;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION ops.clear_setup_pick_list_delay_on_schedule()
FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_setup_pick_list_delay_schedule_release
    ON ops.setup_work_day_task;
CREATE TRIGGER trg_setup_pick_list_delay_schedule_release
AFTER INSERT OR UPDATE OF setup_session_task_id
ON ops.setup_work_day_task
FOR EACH ROW EXECUTE FUNCTION ops.clear_setup_pick_list_delay_on_schedule();

GRANT SELECT ON ops.setup_pick_list_delay TO fieldwiring_app;

COMMIT;

SELECT
    to_regclass('ops.setup_pick_list_delay') IS NOT NULL
        AS pick_list_delay_table_ready,
    to_regprocedure(
        'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)'
    ) IS NOT NULL AS pick_list_delay_command_ready;
