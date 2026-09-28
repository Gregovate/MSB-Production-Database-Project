/* MSB Setup #122 / #206 — hard-delete mistaken Extra Material requirements.
   REVIEW BEFORE PRODUCTION.

   Operator rule:
   - a mistaken reusable-task Extra Material requirement is deleted, not carried
     forward as inactive authority;
   - deleting the mistaken requirement also deletes its task-source allocations;
   - matching Container expected-content rows are deleted only when they become
     unused and have no physical inventory history;
   - Extra Material catalog identity, Display/LOR identity, and physical inventory
     history are independent and remain untouched;
   - new requirement creation is made source-required by the application/API using
     the existing governed requirement + source commands in one transaction.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure(
            'ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean)'
          ) IS NULL
       OR to_regprocedure(
            'ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean)'
          ) IS NULL THEN
        RAISE EXCEPTION 'Accepted Extra Material authority foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.delete_setup_task_extra_material(
    p_email text,
    p_setup_task_id bigint,
    p_setup_task_extra_material_id bigint
)
RETURNS TABLE (
    deleted_setup_task_extra_material_id bigint,
    deleted_source_count integer,
    deleted_container_content_count integer,
    material_name text,
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
    v_source_count integer := 0;
    v_content_count integer := 0;
    v_candidate_content_ids bigint[];
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    SELECT m.material_name
      INTO v_material_name
    FROM ref.setup_task_extra_material AS tm
    JOIN ref.setup_extra_material AS m
      ON m.setup_extra_material_id = tm.setup_extra_material_id
    WHERE tm.setup_task_extra_material_id = p_setup_task_extra_material_id
      AND tm.setup_task_id = p_setup_task_id
    FOR UPDATE OF tm;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE='P0002',
            MESSAGE='Setup task Extra Material requirement was not found for the specified reusable task';
    END IF;

    SELECT array_agg(DISTINCT cem.setup_container_extra_material_id)
      INTO v_candidate_content_ids
    FROM ref.setup_task_extra_material AS tm
    JOIN ref.setup_task_extra_material_source AS src
      ON src.setup_task_extra_material_id = tm.setup_task_extra_material_id
     AND src.active_flag
    JOIN ref.setup_container_extra_material AS cem
      ON cem.container_id = src.container_id
     AND cem.setup_extra_material_id = tm.setup_extra_material_id
     AND cem.quantity_uom = tm.quantity_uom
     AND cem.size_text IS NOT DISTINCT FROM tm.size_text
     AND cem.length_value IS NOT DISTINCT FROM tm.length_value
     AND cem.length_unit IS NOT DISTINCT FROM tm.length_unit
     AND cem.color IS NOT DISTINCT FROM tm.color
     AND cem.active_flag
    WHERE tm.setup_task_extra_material_id = p_setup_task_extra_material_id
      AND tm.setup_task_id = p_setup_task_id;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    DELETE FROM ref.setup_task_extra_material_source AS src
     WHERE src.setup_task_extra_material_id = p_setup_task_extra_material_id;
    GET DIAGNOSTICS v_source_count = ROW_COUNT;

    DELETE FROM ref.setup_task_extra_material AS tm
     WHERE tm.setup_task_extra_material_id = p_setup_task_extra_material_id
       AND tm.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE='P0002',
            MESSAGE='Setup task Extra Material requirement disappeared before deletion';
    END IF;

    IF coalesce(array_length(v_candidate_content_ids, 1), 0) > 0 THEN
        DELETE FROM ref.setup_container_extra_material AS cem
         WHERE cem.setup_container_extra_material_id = ANY(v_candidate_content_ids)
           AND NOT EXISTS (
               SELECT 1
               FROM ops.setup_extra_material_inventory_event AS event
               WHERE event.setup_container_extra_material_id = cem.setup_container_extra_material_id
           )
           AND NOT EXISTS (
               SELECT 1
               FROM ref.setup_task_extra_material_source AS src
               JOIN ref.setup_task_extra_material AS remaining_tm
                 ON remaining_tm.setup_task_extra_material_id = src.setup_task_extra_material_id
               JOIN ref.setup_task AS remaining_task
                 ON remaining_task.setup_task_id = remaining_tm.setup_task_id
               WHERE src.container_id = cem.container_id
                 AND src.active_flag
                 AND remaining_tm.active_flag
                 AND remaining_task.active_flag
                 AND remaining_tm.setup_extra_material_id = cem.setup_extra_material_id
                 AND remaining_tm.quantity_uom = cem.quantity_uom
                 AND remaining_tm.size_text IS NOT DISTINCT FROM cem.size_text
                 AND remaining_tm.length_value IS NOT DISTINCT FROM cem.length_value
                 AND remaining_tm.length_unit IS NOT DISTINCT FROM cem.length_unit
                 AND remaining_tm.color IS NOT DISTINCT FROM cem.color
           );
        GET DIAGNOSTICS v_content_count = ROW_COUNT;
    END IF;

    RETURN QUERY
    SELECT
        p_setup_task_extra_material_id,
        v_source_count,
        v_content_count,
        v_material_name,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.delete_setup_task_extra_material(text,bigint,bigint)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.delete_setup_task_extra_material(text,bigint,bigint)
    TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_task_extra_material(text,bigint,bigint)',
        'EXECUTE'
    ) AS fieldwiring_app_can_delete_mistaken_task_requirement;
