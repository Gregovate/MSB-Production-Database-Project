/* ============================================================================
Controller Inventory — harden Display assignment model capability
Issue: #110
Revision: 2026-09-02 V0.1.0

Purpose:
  Preserve the broader managed-device inventory while preventing Controller
  models marked display_assignment_capable=false from receiving new/replacement
  Display relationships through the browser command boundary.

Unassign remains available so an incorrect historical relationship can be
cleaned up without changing or deleting permanent Controller identity.
============================================================================ */

BEGIN;

CREATE OR REPLACE FUNCTION ref.assign_controller_display(
    p_email text,
    p_controller_id bigint,
    p_display_id bigint,
    p_wiring_source_display_id bigint,
    p_placement_note text,
    p_notes text,
    p_mark_deployed boolean DEFAULT true
)
RETURNS TABLE (
    controller_id bigint,
    display_id bigint,
    controller_status_name text,
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
    v_status text;
    v_assignment_capable boolean;
    v_deployed_status_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    SELECT s.controller_status_name, m.display_assignment_capable
      INTO v_status, v_assignment_capable
    FROM ref.controller AS c
    JOIN ref.controller_status AS s
      ON s.controller_status_id = c.controller_status_id
    JOIN ref.controller_model AS m
      ON m.controller_model_id = c.controller_model_id
    WHERE c.controller_id = p_controller_id
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    IF coalesce(v_assignment_capable, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Controller %s model is not a Display-assignment device', p_controller_id);
    END IF;

    IF v_status IN ('REPAIR', 'RETIRED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Controller %s is %s and cannot be assigned until status is changed explicitly',
                             p_controller_id, v_status);
    END IF;

    PERFORM 1 FROM ref.display AS d
    WHERE d.display_id = p_display_id
      AND d.display_status_id = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Display %s is not an active assignable Display', p_display_id);
    END IF;

    IF p_wiring_source_display_id = p_display_id THEN
        p_wiring_source_display_id := NULL;
    END IF;

    IF p_wiring_source_display_id IS NOT NULL THEN
        PERFORM 1 FROM ref.display AS d
        WHERE d.display_id = p_wiring_source_display_id
          AND d.display_status_id = 1;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format('Wiring source Display %s is not active', p_wiring_source_display_id);
        END IF;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.controller_display (
        controller_id, display_id, wiring_source_display_id, placement_note, notes
    ) VALUES (
        p_controller_id,
        p_display_id,
        p_wiring_source_display_id,
        nullif(btrim(p_placement_note), ''),
        nullif(btrim(p_notes), '')
    );

    IF v_status = 'AVAILABLE' AND coalesce(p_mark_deployed, true) THEN
        SELECT s.controller_status_id INTO v_deployed_status_id
        FROM ref.controller_status AS s
        WHERE s.controller_status_name = 'DEPLOYED';

        UPDATE ref.controller
           SET controller_status_id = v_deployed_status_id
         WHERE ref.controller.controller_id = p_controller_id;
        v_status := 'DEPLOYED';
    END IF;

    RETURN QUERY SELECT p_controller_id, p_display_id, v_status, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.reassign_controller_display(
    p_email text,
    p_controller_id bigint,
    p_old_display_id bigint,
    p_new_display_id bigint,
    p_wiring_source_display_id bigint,
    p_placement_note text,
    p_notes text
)
RETURNS TABLE (
    controller_id bigint,
    old_display_id bigint,
    new_display_id bigint,
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
    v_assignment_capable boolean;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    SELECT m.display_assignment_capable
      INTO v_assignment_capable
    FROM ref.controller AS c
    JOIN ref.controller_model AS m
      ON m.controller_model_id = c.controller_model_id
    WHERE c.controller_id = p_controller_id
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    IF coalesce(v_assignment_capable, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Controller %s model is not a Display-assignment device', p_controller_id);
    END IF;

    IF p_old_display_id = p_new_display_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Replacement Display must be different from the current Display';
    END IF;

    PERFORM 1 FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id
      AND cd.display_id = p_old_display_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s is not assigned to Display %s',
                             p_controller_id, p_old_display_id);
    END IF;

    PERFORM 1 FROM ref.display AS d
    WHERE d.display_id = p_new_display_id
      AND d.display_status_id = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Display %s is not an active assignable Display', p_new_display_id);
    END IF;

    IF p_wiring_source_display_id = p_new_display_id THEN
        p_wiring_source_display_id := NULL;
    END IF;

    IF p_wiring_source_display_id IS NOT NULL THEN
        PERFORM 1 FROM ref.display AS d
        WHERE d.display_id = p_wiring_source_display_id
          AND d.display_status_id = 1;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format('Wiring source Display %s is not active', p_wiring_source_display_id);
        END IF;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.controller_display (
        controller_id, display_id, wiring_source_display_id, placement_note, notes
    ) VALUES (
        p_controller_id,
        p_new_display_id,
        p_wiring_source_display_id,
        nullif(btrim(p_placement_note), ''),
        nullif(btrim(p_notes), '')
    );

    DELETE FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id
      AND cd.display_id = p_old_display_id;

    RETURN QUERY SELECT p_controller_id, p_old_display_id, p_new_display_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean) TO fieldwiring_app;
REVOKE ALL ON FUNCTION ref.reassign_controller_display(text,bigint,bigint,bigint,bigint,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.reassign_controller_display(text,bigint,bigint,bigint,bigint,text,text) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege(
        'fieldwiring_app',
        'ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean)',
        'EXECUTE'
    ) AS can_assign_controller,
    has_function_privilege(
        'fieldwiring_app',
        'ref.reassign_controller_display(text,bigint,bigint,bigint,bigint,text,text)',
        'EXECUTE'
    ) AS can_reassign_controller,
    has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
        AS forbidden_direct_assignment_insert;
