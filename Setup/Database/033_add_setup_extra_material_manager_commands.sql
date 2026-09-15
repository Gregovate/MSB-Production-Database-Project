/* MSB Setup #167 — governed Extra Material catalog/task commands. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Migration 032 and current Setup Manager boundary are required first';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.create_setup_extra_material(
    p_email text,
    p_material_name text,
    p_lifecycle_class text DEFAULT 'REUSABLE',
    p_default_uom text DEFAULT 'EA',
    p_notes text DEFAULT NULL
)
RETURNS TABLE (setup_extra_material_id integer, operator_display_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_material_id integer;
    v_name text := nullif(btrim(p_material_name), '');
    v_lifecycle text := upper(btrim(coalesce(p_lifecycle_class, 'REUSABLE')));
    v_uom text := upper(btrim(coalesce(p_default_uom, 'EA')));
    v_normalized_name text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material name is required';
    END IF;
    IF v_lifecycle NOT IN ('REUSABLE','CONSUMABLE','TEMP_REUSABLE','SPARE_REPLACEMENT') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Extra Material lifecycle class';
    END IF;
    IF v_uom = '' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material default UOM is required';
    END IF;

    v_normalized_name := lower(regexp_replace(v_name, '[[:space:]]+', ' ', 'g'));
    IF EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        WHERE lower(regexp_replace(btrim(m.material_name), '[[:space:]]+', ' ', 'g')) = v_normalized_name
    ) THEN
        RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='An Extra Material with the same normalized name already exists';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    INSERT INTO ref.setup_extra_material(material_name, lifecycle_class, default_uom, notes)
    VALUES (v_name, v_lifecycle, v_uom, nullif(btrim(p_notes), ''))
    RETURNING ref.setup_extra_material.setup_extra_material_id INTO v_material_id;

    RETURN QUERY SELECT v_material_id, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.update_setup_extra_material(
    p_email text,
    p_setup_extra_material_id integer,
    p_material_name text,
    p_lifecycle_class text,
    p_default_uom text,
    p_notes text,
    p_active_flag boolean,
    p_display_order integer
)
RETURNS TABLE (
    setup_extra_material_id integer,
    material_name text,
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
    v_display_name text;
    v_name text := nullif(btrim(p_material_name), '');
    v_lifecycle text := upper(btrim(coalesce(p_lifecycle_class, 'REUSABLE')));
    v_uom text := upper(btrim(coalesce(p_default_uom, 'EA')));
    v_order integer := coalesce(p_display_order, 100);
    v_normalized_name text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF p_setup_extra_material_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        WHERE m.setup_extra_material_id = p_setup_extra_material_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Extra Material was not found';
    END IF;
    IF v_name IS NULL OR v_order < 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material name and nonnegative display order are required';
    END IF;
    IF v_lifecycle NOT IN ('REUSABLE','CONSUMABLE','TEMP_REUSABLE','SPARE_REPLACEMENT') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Extra Material lifecycle class';
    END IF;
    IF v_uom = '' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material default UOM is required';
    END IF;

    v_normalized_name := lower(regexp_replace(v_name, '[[:space:]]+', ' ', 'g'));
    IF EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        WHERE m.setup_extra_material_id <> p_setup_extra_material_id
          AND lower(regexp_replace(btrim(m.material_name), '[[:space:]]+', ' ', 'g')) = v_normalized_name
    ) THEN
        RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='A different Extra Material with the same normalized name already exists';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    UPDATE ref.setup_extra_material m
       SET material_name=v_name,
           lifecycle_class=v_lifecycle,
           default_uom=v_uom,
           notes=nullif(btrim(p_notes), ''),
           active_flag=coalesce(p_active_flag, true),
           display_order=v_order
     WHERE m.setup_extra_material_id=p_setup_extra_material_id;

    RETURN QUERY
    SELECT m.setup_extra_material_id, m.material_name, m.active_flag, v_display_name
    FROM ref.setup_extra_material m
    WHERE m.setup_extra_material_id=p_setup_extra_material_id;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_extra_material(
    p_email text,
    p_setup_task_extra_material_id bigint,
    p_setup_task_id bigint,
    p_setup_extra_material_id integer,
    p_quantity_required numeric,
    p_quantity_uom text,
    p_size_text text,
    p_length_value numeric,
    p_length_unit text,
    p_color text,
    p_quantity_qualifier text,
    p_verification_state text,
    p_notes text,
    p_active_flag boolean
)
RETURNS TABLE (
    setup_task_extra_material_id bigint,
    setup_task_id bigint,
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
    v_row_id bigint := p_setup_task_extra_material_id;
    v_uom text := upper(btrim(coalesce(p_quantity_uom, 'EA')));
    v_length_unit text := nullif(upper(btrim(p_length_unit)), '');
    v_qualifier text := upper(btrim(coalesce(p_quantity_qualifier, 'EXACT')));
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id=p_setup_task_id AND t.active_flag) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Active Setup task was not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.setup_extra_material m WHERE m.setup_extra_material_id=p_setup_extra_material_id AND m.active_flag) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Active Extra Material was not found';
    END IF;
    IF p_quantity_required IS NOT NULL AND p_quantity_required <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material quantity must be greater than zero when supplied';
    END IF;
    IF v_uom = '' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material quantity UOM is required';
    END IF;
    IF v_qualifier NOT IN ('EXACT','MINIMUM','CONDITIONAL','SPARE') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Extra Material quantity qualifier';
    END IF;
    IF v_verification NOT IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid Extra Material verification state';
    END IF;
    IF p_length_value IS NOT NULL AND (p_length_value <= 0 OR v_length_unit NOT IN ('IN','FT','MM','CM','M')) THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material length requires a positive value and supported unit';
    END IF;
    IF p_length_value IS NULL AND v_length_unit IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Extra Material length unit requires a length value';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    IF v_row_id IS NULL THEN
        INSERT INTO ref.setup_task_extra_material(
            setup_task_id, setup_extra_material_id, quantity_required, quantity_uom,
            size_text, length_value, length_unit, color, quantity_qualifier,
            verification_state, notes, active_flag
        ) VALUES (
            p_setup_task_id, p_setup_extra_material_id, p_quantity_required, v_uom,
            nullif(btrim(p_size_text), ''), p_length_value, v_length_unit,
            nullif(btrim(p_color), ''), v_qualifier, v_verification,
            nullif(btrim(p_notes), ''), coalesce(p_active_flag, true)
        ) RETURNING ref.setup_task_extra_material.setup_task_extra_material_id INTO v_row_id;
    ELSE
        UPDATE ref.setup_task_extra_material tm
           SET setup_task_id=p_setup_task_id,
               setup_extra_material_id=p_setup_extra_material_id,
               quantity_required=p_quantity_required,
               quantity_uom=v_uom,
               size_text=nullif(btrim(p_size_text), ''),
               length_value=p_length_value,
               length_unit=v_length_unit,
               color=nullif(btrim(p_color), ''),
               quantity_qualifier=v_qualifier,
               verification_state=v_verification,
               notes=nullif(btrim(p_notes), ''),
               active_flag=coalesce(p_active_flag, true)
         WHERE tm.setup_task_extra_material_id=v_row_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Setup task Extra Material row was not found';
        END IF;
    END IF;

    RETURN QUERY SELECT v_row_id, p_setup_task_id, p_setup_extra_material_id, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_extra_material_source(
    p_email text,
    p_setup_task_extra_material_source_id bigint,
    p_setup_task_extra_material_id bigint,
    p_container_id integer,
    p_expected_quantity numeric,
    p_verification_state text,
    p_notes text,
    p_active_flag boolean
)
RETURNS TABLE (
    setup_task_extra_material_source_id bigint,
    setup_task_extra_material_id bigint,
    container_id integer,
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
    v_row_id bigint := p_setup_task_extra_material_source_id;
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_task_extra_material tm WHERE tm.setup_task_extra_material_id=p_setup_task_extra_material_id) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Setup task Extra Material requirement was not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.container c WHERE c.container_id=p_container_id) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Container was not found';
    END IF;
    IF p_expected_quantity IS NOT NULL AND p_expected_quantity <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Expected source quantity must be greater than zero when supplied';
    END IF;
    IF v_verification NOT IN ('UNVERIFIED','VERIFIED','NEEDS_REVIEW') THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid source verification state';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);
    IF v_row_id IS NULL THEN
        INSERT INTO ref.setup_task_extra_material_source(
            setup_task_extra_material_id, container_id, expected_quantity,
            verification_state, notes, active_flag
        ) VALUES (
            p_setup_task_extra_material_id, p_container_id, p_expected_quantity,
            v_verification, nullif(btrim(p_notes), ''), coalesce(p_active_flag, true)
        ) RETURNING ref.setup_task_extra_material_source.setup_task_extra_material_source_id INTO v_row_id;
    ELSE
        UPDATE ref.setup_task_extra_material_source s
           SET setup_task_extra_material_id=p_setup_task_extra_material_id,
               container_id=p_container_id,
               expected_quantity=p_expected_quantity,
               verification_state=v_verification,
               notes=nullif(btrim(p_notes), ''),
               active_flag=coalesce(p_active_flag, true)
         WHERE s.setup_task_extra_material_source_id=v_row_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Setup task Extra Material source row was not found';
        END IF;
    END IF;

    RETURN QUERY SELECT v_row_id, p_setup_task_extra_material_id, p_container_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_setup_extra_material(text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_setup_extra_material(text,text,text,text,text) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.update_setup_extra_material(text,integer,text,text,text,text,boolean,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_setup_extra_material(text,integer,text,text,text,text,boolean,integer) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege('fieldwiring_app','ref.create_setup_extra_material(text,text,text,text,text)','EXECUTE') AS can_create_catalog,
    has_function_privilege('fieldwiring_app','ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean)','EXECUTE') AS can_set_task_material;
