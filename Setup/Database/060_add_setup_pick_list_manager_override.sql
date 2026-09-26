BEGIN;

CREATE TABLE IF NOT EXISTS ops.setup_pick_list_override (
    setup_pick_list_override_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    container_id integer NOT NULL,
    pick_by_date date NOT NULL,
    needed_for_date date,
    override_reason text NOT NULL,
    active_flag boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_pick_list_override_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_setup_pick_list_override_container
        FOREIGN KEY (container_id)
        REFERENCES ref.container(container_id),
    CONSTRAINT fk_setup_pick_list_override_created_by_person
        FOREIGN KEY (created_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_pick_list_override_updated_by_person
        FOREIGN KEY (updated_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT uq_setup_pick_list_override_session_container
        UNIQUE (setup_session_id, container_id),
    CONSTRAINT ck_setup_pick_list_override_reason
        CHECK (btrim(override_reason) <> '')
);

COMMENT ON TABLE ops.setup_pick_list_override IS
'Explicit annual Manager demand override for the Setup Pick List. Does not schedule work, assign material to a task, or mark material picked.';

DROP TRIGGER IF EXISTS trg_setup_pick_list_override_actor_insert
    ON ops.setup_pick_list_override;
CREATE TRIGGER trg_setup_pick_list_override_actor_insert
BEFORE INSERT ON ops.setup_pick_list_override
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_pick_list_override_actor_update
    ON ops.setup_pick_list_override;
CREATE TRIGGER trg_setup_pick_list_override_actor_update
BEFORE UPDATE ON ops.setup_pick_list_override
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE INDEX IF NOT EXISTS ix_setup_pick_list_override_active
    ON ops.setup_pick_list_override(setup_session_id, pick_by_date, container_id)
    WHERE active_flag;

CREATE OR REPLACE FUNCTION ops.set_setup_pick_list_override(
    p_email text,
    p_season_year integer,
    p_container_id integer,
    p_pick_by_date date,
    p_needed_for_date date,
    p_override_reason text,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_pick_list_override_id bigint,
    setup_session_id bigint,
    container_id integer,
    pick_by_date date,
    needed_for_date date,
    override_reason text,
    active_flag boolean,
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
    v_override_id bigint;
    v_reason text := nullif(btrim(p_override_reason), '');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year
      AND ss.session_status <> 'COMPLETE';

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

    IF coalesce(p_active, true) THEN
        IF p_pick_by_date IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Pick By date is required for a Manager Pick List override';
        END IF;
        IF extract(year FROM p_pick_by_date)::integer <> p_season_year THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Pick By date must be in the selected Setup Session year';
        END IF;
        IF p_needed_for_date IS NOT NULL
           AND extract(year FROM p_needed_for_date)::integer <> p_season_year THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Needed For date must be in the selected Setup Session year';
        END IF;
        IF p_needed_for_date IS NOT NULL
           AND p_needed_for_date < p_pick_by_date THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Needed For date cannot be before Pick By date';
        END IF;
        IF v_reason IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Manager override reason is required';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF coalesce(p_active, true) THEN
        INSERT INTO ops.setup_pick_list_override(
            setup_session_id,
            container_id,
            pick_by_date,
            needed_for_date,
            override_reason,
            active_flag
        ) VALUES (
            v_session_id,
            p_container_id,
            p_pick_by_date,
            p_needed_for_date,
            v_reason,
            true
        )
        ON CONFLICT ON CONSTRAINT uq_setup_pick_list_override_session_container
        DO UPDATE SET
            pick_by_date = EXCLUDED.pick_by_date,
            needed_for_date = EXCLUDED.needed_for_date,
            override_reason = EXCLUDED.override_reason,
            active_flag = true
        RETURNING ops.setup_pick_list_override.setup_pick_list_override_id
          INTO v_override_id;
    ELSE
        UPDATE ops.setup_pick_list_override o
           SET active_flag = false
         WHERE o.setup_session_id = v_session_id
           AND o.container_id = p_container_id
        RETURNING o.setup_pick_list_override_id INTO v_override_id;

        IF v_override_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Active Pick List override was not found for this Container';
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        o.setup_pick_list_override_id,
        o.setup_session_id,
        o.container_id,
        o.pick_by_date,
        o.needed_for_date,
        o.override_reason,
        o.active_flag,
        v_display_name
    FROM ops.setup_pick_list_override o
    WHERE o.setup_pick_list_override_id = v_override_id;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_pick_list_override(
    text,integer,integer,date,date,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_pick_list_override(
    text,integer,integer,date,date,text,boolean
) TO fieldwiring_app;

GRANT SELECT ON ops.setup_pick_list_override TO fieldwiring_app;

COMMIT;

SELECT
    to_regclass('ops.setup_pick_list_override') IS NOT NULL
        AS pick_list_override_table_ready,
    to_regprocedure(
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,text,boolean)'
    ) IS NOT NULL AS pick_list_override_command_ready;
