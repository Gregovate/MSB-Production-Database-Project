/* MSB Setup #206 — governed historical Extra Material requirement restore.
   REVIEW BEFORE PRODUCTION.

   Operator rule:
   - restoring historical reusable-task authority reactivates the exact existing
     requirement row;
   - its existing source rows remain attached to that requirement;
   - the application role never receives direct UPDATE/row-lock authority on
     ref.setup_task_extra_material;
   - competing reconstructed requirements are reviewed separately.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure(
            'ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean)'
          ) IS NULL THEN
        RAISE EXCEPTION 'Accepted Extra Material authority foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.restore_setup_task_extra_material(
    p_email text,
    p_setup_task_id bigint,
    p_setup_task_extra_material_id bigint
)
RETURNS TABLE (
    restored_setup_task_extra_material_id bigint,
    setup_task_id bigint,
    material_name text,
    task_name text,
    active_source_count integer,
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
    v_material_name text;
    v_task_name text;
    v_setup_extra_material_id integer;
    v_quantity_required numeric;
    v_quantity_uom text;
    v_size_text text;
    v_length_value numeric;
    v_length_unit text;
    v_color text;
    v_quantity_qualifier text;
    v_verification_state text;
    v_notes text;
    v_source_count integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    SELECT
        tm.setup_extra_material_id,
        tm.quantity_required,
        tm.quantity_uom,
        tm.size_text,
        tm.length_value,
        tm.length_unit,
        tm.color,
        tm.quantity_qualifier,
        tm.verification_state,
        tm.notes,
        m.material_name,
        t.task_name
      INTO
        v_setup_extra_material_id,
        v_quantity_required,
        v_quantity_uom,
        v_size_text,
        v_length_value,
        v_length_unit,
        v_color,
        v_quantity_qualifier,
        v_verification_state,
        v_notes,
        v_material_name,
        v_task_name
    FROM ref.setup_task_extra_material AS tm
    JOIN ref.setup_extra_material AS m
      ON m.setup_extra_material_id = tm.setup_extra_material_id
    JOIN ref.setup_task AS t
      ON t.setup_task_id = tm.setup_task_id
    WHERE tm.setup_task_extra_material_id = p_setup_task_extra_material_id
      AND tm.setup_task_id = p_setup_task_id
      AND NOT tm.active_flag
      AND t.active_flag
      AND m.active_flag
    FOR UPDATE OF tm;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE='P0002',
            MESSAGE='Inactive historical Setup task Extra Material requirement was not found';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    PERFORM 1
    FROM ref.set_setup_task_extra_material(
        p_email,
        p_setup_task_extra_material_id,
        p_setup_task_id,
        v_setup_extra_material_id,
        v_quantity_required,
        v_quantity_uom,
        v_size_text,
        v_length_value,
        v_length_unit,
        v_color,
        v_quantity_qualifier,
        v_verification_state,
        v_notes,
        true
    );

    SELECT count(*)::integer
      INTO v_source_count
    FROM ref.setup_task_extra_material_source AS src
    WHERE src.setup_task_extra_material_id = p_setup_task_extra_material_id
      AND src.active_flag;

    RETURN QUERY
    SELECT
        p_setup_task_extra_material_id,
        p_setup_task_id,
        v_material_name,
        v_task_name,
        coalesce(v_source_count, 0),
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.restore_setup_task_extra_material(text,bigint,bigint)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.restore_setup_task_extra_material(text,bigint,bigint)
    TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege(
        'fieldwiring_app',
        'ref.restore_setup_task_extra_material(text,bigint,bigint)',
        'EXECUTE'
    ) AS fieldwiring_app_can_restore_historical_task_requirement;
