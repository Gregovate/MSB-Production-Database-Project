/* ============================================================================
MSB Setup Session — corrected reusable assignment layer
Issue: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-12 V0.2.0

Purpose:
  Correct the rejected V0.3.12 first-use Display assignment boundary and add the
  missing explicit reusable Setup task -> Kit Box assignment contract.

Authority boundaries:
  - Current LOR/Production Stage/real-Scene membership remains authoritative for
    the source set of Displays.
  - Display assignment changes Setup ownership only. It never changes LOR
    membership or ref.display.container_id.
  - A resolved Display may have at most one explicit reusable Setup-task owner.
  - Assigning a Display to an active task automatically makes that task
    requires_display_material=true; Managers do not pre-enable tasks merely to
    make them assignment targets.
  - Kit Boxes do not exist in LOR. They are existing ref.container rows with
    container_type_id=2 and are assigned explicitly by Setup.
  - Task -> Kit Box is many-to-many. Existing SUPPORT / REQUIRED_CONTAINER rows
    (for example Arch Trailer logistics) remain separate and unchanged.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.container_type') IS NULL THEN
        RAISE EXCEPTION 'Setup assignment-layer prerequisites are missing';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary is required first';
    END IF;

    IF to_regprocedure('ref.set_setup_task_display_owner(text,bigint,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 028 Display-owner command is required before correction 029';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.container_type
        WHERE container_type_id = 2
          AND container_type_name = 'Kit Box'
    ) THEN
        RAISE EXCEPTION 'Expected Production Kit Box container type 2 is missing or renamed';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* Keep existing trailer/support semantics and add a specific KIT relationship. */
ALTER TABLE ref.setup_task_container_support
    DROP CONSTRAINT IF EXISTS ck_setup_task_container_support_relationship;

ALTER TABLE ref.setup_task_container_support
    ADD CONSTRAINT ck_setup_task_container_support_relationship CHECK (
        relationship_type IN ('SUPPORT', 'REQUIRED_CONTAINER', 'KIT')
    );

COMMENT ON TABLE ref.setup_task_container_support IS
'Reusable Setup task -> physical Container relationships. SUPPORT / REQUIRED_CONTAINER retain existing logistics meaning. KIT is reserved for explicit task -> ref.container Kit Box assignments (container_type_id=2).';

/*
Correction to migration 028: assignment target eligibility is active task scope,
not a pre-existing material flag. The assignment itself establishes the flag.
*/
CREATE OR REPLACE FUNCTION ref.set_setup_task_display_owner(
    p_email text,
    p_display_id bigint,
    p_target_setup_task_id bigint,
    p_expected_source_setup_task_id bigint
)
RETURNS TABLE (
    display_id bigint,
    previous_setup_task_id bigint,
    setup_task_id bigint,
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
    v_current_setup_task_id bigint;
    v_target_exists boolean;
    v_display_active boolean;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_display_id IS NULL OR p_target_setup_task_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Display and target Setup task are required';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM ref.setup_task AS t
        WHERE t.setup_task_id = p_target_setup_task_id
          AND t.active_flag
          AND t.stage_id IS NOT NULL
    )
      INTO v_target_exists;

    IF NOT v_target_exists THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Target Setup task must be active and have a Stage or Scene scope';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM ref.display AS d
        JOIN ref.display_status AS ds
          ON ds.display_status_id = d.display_status_id
        WHERE d.display_id = p_display_id
          AND upper(ds.display_status_name) = 'ACTIVE'
    )
      INTO v_display_active;

    IF NOT v_display_active THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Only an ACTIVE current Display may receive a Setup-task owner';
    END IF;

    SELECT td.setup_task_id
      INTO v_current_setup_task_id
    FROM ref.setup_task_display AS td
    WHERE td.display_id = p_display_id
    FOR UPDATE;

    IF p_expected_source_setup_task_id IS NULL THEN
        IF v_current_setup_task_id IS NOT NULL THEN
            RAISE EXCEPTION USING
                ERRCODE = '23505',
                MESSAGE = 'Display already has an explicit Setup-task owner; refresh ownership before assigning';
        END IF;
    ELSE
        IF v_current_setup_task_id IS DISTINCT FROM p_expected_source_setup_task_id THEN
            RAISE EXCEPTION USING
                ERRCODE = '23505',
                MESSAGE = 'Display owner changed since it was loaded; refresh ownership before moving';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    /* Assignment establishes Display-material applicability automatically. */
    UPDATE ref.setup_task AS t
       SET requires_display_material = true
     WHERE t.setup_task_id = p_target_setup_task_id
       AND NOT t.requires_display_material;

    IF v_current_setup_task_id IS NULL THEN
        INSERT INTO ref.setup_task_display(
            setup_task_id,
            display_id,
            relationship_type,
            notes
        )
        VALUES (
            p_target_setup_task_id,
            p_display_id,
            'REQUIRED',
            'Task-specific Setup Display owner.'
        );
    ELSE
        UPDATE ref.setup_task_display AS td
           SET setup_task_id = p_target_setup_task_id,
               relationship_type = 'REQUIRED',
               notes = 'Task-specific Setup Display owner.'
         WHERE td.display_id = p_display_id;
    END IF;

    RETURN QUERY
    SELECT
        p_display_id,
        v_current_setup_task_id,
        p_target_setup_task_id,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_display_owner(text,bigint,bigint,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_owner(text,bigint,bigint,bigint) TO fieldwiring_app;

/*
Explicit reusable Kit Box assignment. This deliberately reuses the existing
many-to-many task/container table while reserving relationship_type='KIT' for
container_type_id=2 only. Existing SUPPORT / REQUIRED_CONTAINER rows are never
silently converted.
*/
CREATE OR REPLACE FUNCTION ref.set_setup_task_kit_box_assignment(
    p_email text,
    p_setup_task_id bigint,
    p_container_id integer,
    p_assigned boolean,
    p_notes text
)
RETURNS TABLE (
    setup_task_id bigint,
    container_id integer,
    assigned boolean,
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
    v_task_valid boolean;
    v_container_type_id integer;
    v_existing_relationship text;
    v_assigned boolean := coalesce(p_assigned, false);
    v_notes text := coalesce(nullif(btrim(p_notes), ''), 'Reusable Setup Kit Box assignment.');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id IS NULL OR p_container_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup task and Kit Box container are required';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM ref.setup_task AS t
        WHERE t.setup_task_id = p_setup_task_id
          AND t.active_flag
          AND t.stage_id IS NOT NULL
    )
      INTO v_task_valid;

    IF NOT v_task_valid THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Kit Box assignment requires an active Stage or Scene-scoped Setup task';
    END IF;

    SELECT c.container_type_id
      INTO v_container_type_id
    FROM ref.container AS c
    WHERE c.container_id = p_container_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Container was not found';
    END IF;

    IF v_container_type_id <> 2 THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Only ref.container rows with container_type_id=2 (Kit Box) may receive a KIT assignment';
    END IF;

    SELECT tc.relationship_type
      INTO v_existing_relationship
    FROM ref.setup_task_container_support AS tc
    WHERE tc.setup_task_id = p_setup_task_id
      AND tc.container_id = p_container_id
    FOR UPDATE;

    IF v_existing_relationship IS NOT NULL
       AND v_existing_relationship <> 'KIT' THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'This task/container pair already has a non-KIT support relationship and will not be overwritten';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF v_assigned THEN
        INSERT INTO ref.setup_task_container_support(
            setup_task_id,
            container_id,
            relationship_type,
            notes
        )
        VALUES (
            p_setup_task_id,
            p_container_id,
            'KIT',
            v_notes
        )
        ON CONFLICT (setup_task_id, container_id)
        DO UPDATE SET
            relationship_type = 'KIT',
            notes = EXCLUDED.notes;
    ELSE
        DELETE FROM ref.setup_task_container_support AS tc
        WHERE tc.setup_task_id = p_setup_task_id
          AND tc.container_id = p_container_id
          AND tc.relationship_type = 'KIT';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, p_container_id, v_assigned, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-12-setup-assignment-layer-v0.2.0' AS applied_revision,
    current_user AS applied_by,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_owner(text,bigint,bigint,bigint)',
        'EXECUTE'
    ) AS app_can_set_display_owner,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text)',
        'EXECUTE'
    ) AS app_can_set_kit_box_assignment;
