/* MSB Setup #167 — governed Container expected-content commands. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Migration 032 and current Setup Manager boundary are required first';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.set_setup_container_extra_material(
    p_email text,
    p_setup_container_extra_material_id bigint,
    p_container_id integer,
    p_setup_extra_material_id integer,
    p_expected_quantity numeric,
    p_quantity_uom text,
    p_size_text text,
    p_length_value numeric,
    p_length_unit text,
    p_color text,
    p_verification_state text,
    p_notes text,
    p_active_flag boolean
)
RETURNS TABLE (
    setup_container_extra_material_id bigint,
    container_id integer,
    setup_extra_material_id integer,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_row_id bigint := p_setup_container_extra_material_id;
    v_uom text := upper(btrim(coalesce(p_quantity_uom, 'EA')));
    v_size text := nullif(btrim(p_size_text), '');
    v_length_unit text := nullif(upper(btrim(p_length_unit)), '');
    v_color text := nullif(btrim(p_color), '');
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (SELECT 1 FROM ref.container c WHERE c.container_id=p_container_id) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Container was not found';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        WHERE m.setup_extra_material_id=p_setup_extra_material_id AND m.active_flag
    ) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Active Extra Material was not found';
    END IF;
    IF p_expected_quantity IS NOT NULL AND p_expected_quantity <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Expected Container quantity must be greater than zero when supplied';
    END IF;
    IF v_uom = '' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Container content quantity UOM is required';
    END IF;
    IF v_verification NOT IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Container content verification state';
    END IF;
    IF p_length_value IS NOT NULL AND (p_length_value <= 0 OR v_length_unit NOT IN ('IN','FT','MM','CM','M')) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Container content length requires a positive value and supported unit';
    END IF;
    IF p_length_value IS NULL AND v_length_unit IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Container content length unit requires a length value';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF v_row_id IS NULL THEN
        INSERT INTO ref.setup_container_extra_material(
            container_id, setup_extra_material_id, expected_quantity, quantity_uom,
            size_text, length_value, length_unit, color, verification_state,
            notes, active_flag
        ) VALUES (
            p_container_id, p_setup_extra_material_id, p_expected_quantity, v_uom,
            v_size, p_length_value, v_length_unit, v_color, v_verification,
            nullif(btrim(p_notes), ''), coalesce(p_active_flag, true)
        ) RETURNING ref.setup_container_extra_material.setup_container_extra_material_id INTO v_row_id;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM ref.setup_container_extra_material cem
            WHERE cem.setup_container_extra_material_id=v_row_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Container Extra Material row was not found';
        END IF;

        /* Inventory history is attached to this exact material/spec/Container
           identity. Never reinterpret prior events by editing identity fields. */
        IF EXISTS (
            SELECT 1
            FROM ops.setup_extra_material_inventory_event e
            WHERE e.setup_container_extra_material_id=v_row_id
        ) AND EXISTS (
            SELECT 1
            FROM ref.setup_container_extra_material cem
            WHERE cem.setup_container_extra_material_id=v_row_id
              AND (
                  cem.container_id IS DISTINCT FROM p_container_id
                  OR cem.setup_extra_material_id IS DISTINCT FROM p_setup_extra_material_id
                  OR cem.quantity_uom IS DISTINCT FROM v_uom
                  OR cem.size_text IS DISTINCT FROM v_size
                  OR cem.length_value IS DISTINCT FROM p_length_value
                  OR cem.length_unit IS DISTINCT FROM v_length_unit
                  OR cem.color IS DISTINCT FROM v_color
              )
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE='22023',
                MESSAGE='Inventoried Container material identity cannot be changed; create a new material/spec row instead';
        END IF;

        /* Do not hide real stock by deactivating an expected-content row while
           its durable physical balance is still nonzero. */
        IF NOT coalesce(p_active_flag, true) AND EXISTS (
            SELECT 1
            FROM ops.setup_extra_material_inventory_balance b
            WHERE b.setup_container_extra_material_id=v_row_id
              AND coalesce(b.on_hand_quantity, 0) <> 0
        ) THEN
            RAISE EXCEPTION USING
                ERRCODE='22023',
                MESSAGE='Container material cannot be removed while physical on-hand inventory is nonzero';
        END IF;

        UPDATE ref.setup_container_extra_material cem
           SET container_id=p_container_id,
               setup_extra_material_id=p_setup_extra_material_id,
               expected_quantity=p_expected_quantity,
               quantity_uom=v_uom,
               size_text=v_size,
               length_value=p_length_value,
               length_unit=v_length_unit,
               color=v_color,
               verification_state=v_verification,
               notes=nullif(btrim(p_notes), ''),
               active_flag=coalesce(p_active_flag, true)
         WHERE cem.setup_container_extra_material_id=v_row_id;
    END IF;

    RETURN QUERY SELECT v_row_id, p_container_id, p_setup_extra_material_id, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_setup_container_unverified_items(
    p_email text,
    p_container_id integer,
    p_unverified_items_text text
)
RETURNS TABLE (
    container_id integer,
    has_unverified_items boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_text text := nullif(btrim(p_unverified_items_text), '');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (SELECT 1 FROM ref.container c WHERE c.container_id=p_container_id) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Container was not found';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF v_text IS NULL THEN
        DELETE FROM ref.setup_container_extra_material_review r
        WHERE r.container_id=p_container_id;
    ELSE
        INSERT INTO ref.setup_container_extra_material_review(container_id, unverified_items_text)
        VALUES (p_container_id, v_text)
        ON CONFLICT (container_id)
        DO UPDATE SET unverified_items_text=EXCLUDED.unverified_items_text;
    END IF;

    RETURN QUERY SELECT p_container_id, v_text IS NOT NULL, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_container_extra_material(text,bigint,integer,integer,numeric,text,text,numeric,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_container_extra_material(text,bigint,integer,integer,numeric,text,text,numeric,text,text,text,text,boolean) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.set_setup_container_unverified_items(text,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_container_unverified_items(text,integer,text) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege('fieldwiring_app','ref.set_setup_container_extra_material(text,bigint,integer,integer,numeric,text,text,numeric,text,text,text,text,boolean)','EXECUTE') AS can_set_container_content,
    has_function_privilege('fieldwiring_app','ref.set_setup_container_unverified_items(text,integer,text)','EXECUTE') AS can_set_unverified_text;
