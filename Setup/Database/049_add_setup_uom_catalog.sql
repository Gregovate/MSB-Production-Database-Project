/* MSB Setup #191 — governed Unit-of-Measure catalog for Extra Materials. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Current Extra Material and Setup Manager foundation is required first';
    END IF;

    /* Refuse to normalize malformed legacy codes silently. Current values must
       fit the same stable-code grammar used for all future Manager-created UOMs. */
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT upper(btrim(default_uom)) AS uom_code FROM ref.setup_extra_material
            UNION
            SELECT upper(btrim(quantity_uom)) FROM ref.setup_task_extra_material
            UNION
            SELECT upper(btrim(quantity_uom)) FROM ref.setup_container_extra_material
        ) existing
        WHERE nullif(existing.uom_code, '') IS NULL
           OR existing.uom_code !~ '^[A-Z0-9][A-Z0-9._/-]{0,15}$'
    ) THEN
        RAISE EXCEPTION 'Current Setup Extra Material data contains a malformed UOM code; review it before migration 049';
    END IF;

    /* The active relationship uniqueness rules include UOM. If legacy rows
       differ only by UOM case/outer whitespace, canonicalization could collapse
       them onto one active key. Fail before any UPDATE rather than guess. */
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT
                setup_task_id,
                setup_extra_material_id,
                upper(btrim(quantity_uom)) AS normalized_uom,
                coalesce(lower(btrim(size_text)), '') AS size_key,
                coalesce(length_value, -1::numeric) AS length_key,
                coalesce(length_unit, '') AS length_unit_key,
                coalesce(lower(btrim(color)), '') AS color_key,
                count(*) AS row_count
            FROM ref.setup_task_extra_material
            WHERE active_flag
            GROUP BY
                setup_task_id,
                setup_extra_material_id,
                upper(btrim(quantity_uom)),
                coalesce(lower(btrim(size_text)), ''),
                coalesce(length_value, -1::numeric),
                coalesce(length_unit, ''),
                coalesce(lower(btrim(color)), '')
            HAVING count(*) > 1
        ) collisions
    ) THEN
        RAISE EXCEPTION 'UOM normalization would collide active Setup task Extra Material rows; review before migration 049';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT
                container_id,
                setup_extra_material_id,
                upper(btrim(quantity_uom)) AS normalized_uom,
                coalesce(lower(btrim(size_text)), '') AS size_key,
                coalesce(length_value, -1::numeric) AS length_key,
                coalesce(length_unit, '') AS length_unit_key,
                coalesce(lower(btrim(color)), '') AS color_key,
                count(*) AS row_count
            FROM ref.setup_container_extra_material
            WHERE active_flag
            GROUP BY
                container_id,
                setup_extra_material_id,
                upper(btrim(quantity_uom)),
                coalesce(lower(btrim(size_text)), ''),
                coalesce(length_value, -1::numeric),
                coalesce(length_unit, ''),
                coalesce(lower(btrim(color)), '')
            HAVING count(*) > 1
        ) collisions
    ) THEN
        RAISE EXCEPTION 'UOM normalization would collide active Container Extra Material rows; review before migration 049';
    END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS ref.setup_uom (
    uom_code text PRIMARY KEY,
    display_name text NOT NULL,
    active_flag boolean NOT NULL DEFAULT true,
    display_order integer NOT NULL DEFAULT 100,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer REFERENCES ref.person(person_id),
    updated_by_person_id integer REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_uom_code_nonblank CHECK (btrim(uom_code) <> ''),
    CONSTRAINT ck_setup_uom_code_canonical CHECK (uom_code = upper(btrim(uom_code))),
    CONSTRAINT ck_setup_uom_code_format CHECK (uom_code ~ '^[A-Z0-9][A-Z0-9._/-]{0,15}$'),
    CONSTRAINT ck_setup_uom_display_name CHECK (btrim(display_name) <> ''),
    CONSTRAINT ck_setup_uom_order CHECK (display_order >= 0)
);

CREATE INDEX IF NOT EXISTS ix_setup_uom_catalog
ON ref.setup_uom(active_flag, display_order, uom_code);

/* Normalize current values before harvesting them. Existing commands already
   uppercase new writes; these updates are no-ops unless older/manual rows drifted. */
UPDATE ref.setup_extra_material
SET default_uom = upper(btrim(default_uom))
WHERE default_uom IS DISTINCT FROM upper(btrim(default_uom));

UPDATE ref.setup_task_extra_material
SET quantity_uom = upper(btrim(quantity_uom))
WHERE quantity_uom IS DISTINCT FROM upper(btrim(quantity_uom));

UPDATE ref.setup_container_extra_material
SET quantity_uom = upper(btrim(quantity_uom))
WHERE quantity_uom IS DISTINCT FROM upper(btrim(quantity_uom));

/* Preserve every UOM already present in current Production before adding FKs. */
WITH current_uom AS (
    SELECT upper(btrim(default_uom)) AS uom_code FROM ref.setup_extra_material
    UNION
    SELECT upper(btrim(quantity_uom)) FROM ref.setup_task_extra_material
    UNION
    SELECT upper(btrim(quantity_uom)) FROM ref.setup_container_extra_material
)
INSERT INTO ref.setup_uom(uom_code, display_name, active_flag, display_order, notes)
SELECT uom_code, uom_code, true, 100,
       'Harvested from current Setup Extra Material data by migration 049.'
FROM current_uom
WHERE nullif(uom_code, '') IS NOT NULL
ON CONFLICT (uom_code) DO NOTHING;

/* Known canonical starter vocabulary. Current Production codes above remain
   authoritative even when they are not listed here. Managers can add more. */
INSERT INTO ref.setup_uom(uom_code, display_name, active_flag, display_order, notes)
VALUES
    ('EA', 'Each', true, 10, 'Counted individual item.'),
    ('FT', 'Foot / feet', true, 20, 'Linear feet.'),
    ('IN', 'Inch / inches', true, 30, 'Linear inches.'),
    ('SHEET', 'Sheet', true, 40, 'Sheet count.'),
    ('SET', 'Set', true, 50, 'Counted set.'),
    ('ROLL', 'Roll', true, 60, 'Roll count.'),
    ('CAN', 'Can', true, 70, 'Can count.')
ON CONFLICT (uom_code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    display_order = LEAST(ref.setup_uom.display_order, EXCLUDED.display_order),
    notes = CASE
        WHEN ref.setup_uom.notes IS NULL
          OR ref.setup_uom.notes LIKE 'Harvested from current Setup Extra Material data%'
        THEN EXCLUDED.notes
        ELSE ref.setup_uom.notes
    END;

DROP TRIGGER IF EXISTS trg_setup_uom_actor_insert ON ref.setup_uom;
CREATE TRIGGER trg_setup_uom_actor_insert
BEFORE INSERT ON ref.setup_uom
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_uom_actor_update ON ref.setup_uom;
CREATE TRIGGER trg_setup_uom_actor_update
BEFORE UPDATE ON ref.setup_uom
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

ALTER TABLE ref.setup_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_extra_material_default_uom;
ALTER TABLE ref.setup_extra_material
    ADD CONSTRAINT fk_setup_extra_material_default_uom
    FOREIGN KEY (default_uom) REFERENCES ref.setup_uom(uom_code);

ALTER TABLE ref.setup_task_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_task_extra_material_quantity_uom;
ALTER TABLE ref.setup_task_extra_material
    ADD CONSTRAINT fk_setup_task_extra_material_quantity_uom
    FOREIGN KEY (quantity_uom) REFERENCES ref.setup_uom(uom_code);

ALTER TABLE ref.setup_container_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_container_extra_material_quantity_uom;
ALTER TABLE ref.setup_container_extra_material
    ADD CONSTRAINT fk_setup_container_extra_material_quantity_uom
    FOREIGN KEY (quantity_uom) REFERENCES ref.setup_uom(uom_code);

CREATE OR REPLACE FUNCTION ref.enforce_active_setup_uom()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_uom text;
BEGIN
    IF TG_TABLE_NAME = 'setup_extra_material' THEN
        v_uom := NEW.default_uom;
    ELSE
        v_uom := NEW.quantity_uom;
    END IF;

    /* Inactive historical rows may retain an inactive UOM code. Referential
       integrity still requires the code to exist; active operational rows must
       reference an active UOM. */
    IF NEW.active_flag AND NOT EXISTS (
        SELECT 1
        FROM ref.setup_uom u
        WHERE u.uom_code = v_uom
          AND u.active_flag
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Unknown or inactive Setup UOM: ' || coalesce(v_uom, '<blank>');
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_extra_material_active_uom ON ref.setup_extra_material;
CREATE TRIGGER trg_setup_extra_material_active_uom
BEFORE INSERT OR UPDATE OF default_uom, active_flag ON ref.setup_extra_material
FOR EACH ROW EXECUTE FUNCTION ref.enforce_active_setup_uom();

DROP TRIGGER IF EXISTS trg_setup_task_extra_material_active_uom ON ref.setup_task_extra_material;
CREATE TRIGGER trg_setup_task_extra_material_active_uom
BEFORE INSERT OR UPDATE OF quantity_uom, active_flag ON ref.setup_task_extra_material
FOR EACH ROW EXECUTE FUNCTION ref.enforce_active_setup_uom();

DROP TRIGGER IF EXISTS trg_setup_container_extra_material_active_uom ON ref.setup_container_extra_material;
CREATE TRIGGER trg_setup_container_extra_material_active_uom
BEFORE INSERT OR UPDATE OF quantity_uom, active_flag ON ref.setup_container_extra_material
FOR EACH ROW EXECUTE FUNCTION ref.enforce_active_setup_uom();

CREATE OR REPLACE FUNCTION ref.guard_setup_uom_identity_and_deactivation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    IF NEW.uom_code IS DISTINCT FROM OLD.uom_code THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Setup UOM code is a stable identity and cannot be renamed';
    END IF;

    IF OLD.active_flag AND NOT NEW.active_flag AND (
        EXISTS (
            SELECT 1 FROM ref.setup_extra_material m
            WHERE m.active_flag AND m.default_uom = OLD.uom_code
        )
        OR EXISTS (
            SELECT 1 FROM ref.setup_task_extra_material tm
            WHERE tm.active_flag AND tm.quantity_uom = OLD.uom_code
        )
        OR EXISTS (
            SELECT 1 FROM ref.setup_container_extra_material cm
            WHERE cm.active_flag AND cm.quantity_uom = OLD.uom_code
        )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='Setup UOM cannot be deactivated while active Extra Material rows still reference it';
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_uom_identity_deactivation_guard ON ref.setup_uom;
CREATE TRIGGER trg_setup_uom_identity_deactivation_guard
BEFORE UPDATE ON ref.setup_uom
FOR EACH ROW EXECUTE FUNCTION ref.guard_setup_uom_identity_and_deactivation();

CREATE OR REPLACE FUNCTION ref.create_setup_uom(
    p_email text,
    p_uom_code text,
    p_display_name text,
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    uom_code text,
    display_name text,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_operator_name text;
    v_code text := upper(btrim(coalesce(p_uom_code, '')));
    v_name text := nullif(btrim(p_display_name), '');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_operator_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_code = '' OR v_code !~ '^[A-Z0-9][A-Z0-9._/-]{0,15}$' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='UOM code must be 1-16 uppercase letters/numbers or . _ / -';
    END IF;
    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='UOM display name is required';
    END IF;
    IF EXISTS (SELECT 1 FROM ref.setup_uom u WHERE u.uom_code=v_code) THEN
        RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='Setup UOM code already exists';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    INSERT INTO ref.setup_uom(uom_code, display_name, notes)
    VALUES (v_code, v_name, nullif(btrim(p_notes), ''));

    RETURN QUERY SELECT v_code, v_name, v_operator_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.update_setup_uom(
    p_email text,
    p_uom_code text,
    p_display_name text,
    p_notes text,
    p_active_flag boolean,
    p_display_order integer
)
RETURNS TABLE (
    uom_code text,
    display_name text,
    active_flag boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_operator_name text;
    v_code text := upper(btrim(coalesce(p_uom_code, '')));
    v_name text := nullif(btrim(p_display_name), '');
    v_order integer := coalesce(p_display_order, 100);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_operator_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_uom u WHERE u.uom_code=v_code) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Setup UOM was not found';
    END IF;
    IF v_name IS NULL OR v_order < 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='UOM display name and nonnegative display order are required';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    UPDATE ref.setup_uom u
       SET display_name=v_name,
           notes=nullif(btrim(p_notes), ''),
           active_flag=coalesce(p_active_flag, true),
           display_order=v_order
     WHERE u.uom_code=v_code;

    RETURN QUERY
    SELECT u.uom_code, u.display_name, u.active_flag, v_operator_name
    FROM ref.setup_uom u
    WHERE u.uom_code=v_code;
END;
$function$;

REVOKE ALL ON ref.setup_uom FROM PUBLIC;
GRANT SELECT ON ref.setup_uom TO fieldwiring_app;
REVOKE INSERT, UPDATE, DELETE ON ref.setup_uom FROM fieldwiring_app;

REVOKE ALL ON FUNCTION ref.create_setup_uom(text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_setup_uom(text,text,text,text) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.update_setup_uom(text,text,text,text,boolean,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_setup_uom(text,text,text,text,boolean,integer) TO fieldwiring_app;

COMMENT ON TABLE ref.setup_uom IS
'Governed Setup Unit-of-Measure catalog. UOM code is stable identity; Extra Material catalog/task/Container UOM fields reference this table.';

COMMIT;

SELECT
    to_regclass('ref.setup_uom') IS NOT NULL AS uom_catalog_exists,
    (SELECT count(*) FROM ref.setup_uom WHERE uom_code IN ('EA','FT','IN','SHEET','SET','ROLL','CAN')) = 7 AS starter_uoms_present,
    NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        LEFT JOIN ref.setup_uom u ON u.uom_code=m.default_uom
        WHERE u.uom_code IS NULL
    ) AS no_orphan_material_uom,
    NOT EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material tm
        LEFT JOIN ref.setup_uom u ON u.uom_code=tm.quantity_uom
        WHERE u.uom_code IS NULL
    ) AS no_orphan_task_uom,
    NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cm
        LEFT JOIN ref.setup_uom u ON u.uom_code=cm.quantity_uom
        WHERE u.uom_code IS NULL
    ) AS no_orphan_container_uom,
    has_function_privilege('fieldwiring_app','ref.create_setup_uom(text,text,text,text)','EXECUTE') AS can_create_uom,
    has_function_privilege('fieldwiring_app','ref.update_setup_uom(text,text,text,text,boolean,integer)','EXECUTE') AS can_update_uom,
    NOT has_table_privilege('fieldwiring_app','ref.setup_uom','INSERT') AS no_broad_uom_insert;
