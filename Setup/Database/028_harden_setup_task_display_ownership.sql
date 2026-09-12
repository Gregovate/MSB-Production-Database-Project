/* ============================================================================
MSB Setup Session — task-specific Display ownership foundation
Issue: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-12 V0.1.0

Purpose:
  Reuse ref.setup_task_display as the explicit ownership layer applied AFTER the
  accepted Stage/real-Scene LOR resolver when one scope contains more than one
  material-bearing reusable Setup task.

Authority boundaries:
  - Existing Stage/real-Scene resolver remains authoritative for the current
    source set of Displays in a Setup scope.
  - LOR/LOR2DB membership is not changed here.
  - ref.display.container_id is not changed here.
  - One current Display may have at most one explicit reusable Setup-task owner.
  - Simple scopes may continue to use the existing implicit single-task resolver
    without materializing rows in ref.setup_task_display.
  - Container/KIT support remains many-to-many in
    ref.setup_task_container_support and is intentionally not made exclusive.
  - Scope/source-set validation remains in the application layer so this
    migration does not duplicate or redesign the accepted LOR resolver.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_duplicate_display_id bigint;
BEGIN
    IF to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.display_status') IS NULL THEN
        RAISE EXCEPTION 'Setup task/display ownership prerequisites are missing';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary is required first';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'requires_display_material'
    ) THEN
        RAISE EXCEPTION 'requires_display_material is required before Display ownership hardening';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;

    SELECT td.display_id
      INTO v_duplicate_display_id
    FROM ref.setup_task_display AS td
    GROUP BY td.display_id
    HAVING count(*) > 1
    ORDER BY td.display_id
    LIMIT 1;

    IF v_duplicate_display_id IS NOT NULL THEN
        RAISE EXCEPTION
            'ref.setup_task_display already contains multiple task rows for display_id %; reconcile before migration 028',
            v_duplicate_display_id;
    END IF;
END
$preflight$;

/*
The existing primary key prevents duplicate task/display pairs but still allows
one Display to appear under several tasks. #141 changes that relationship into
an exclusive explicit owner whenever ownership rows are materialized.
*/
CREATE UNIQUE INDEX IF NOT EXISTS ux_setup_task_display_one_owner
    ON ref.setup_task_display(display_id);

COMMENT ON TABLE ref.setup_task_display IS
'Explicit reusable Setup-task ownership for resolved current Displays when a Stage/real-Scene scope needs task subdivision. The accepted LOR resolver remains the source set; simple single-material-task scopes may remain implicit with no rows.';

COMMENT ON INDEX ref.ux_setup_task_display_one_owner IS
'#141 invariant: one Display may have at most one explicit reusable Setup-task owner.';

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
          AND t.requires_display_material
    )
      INTO v_target_exists;

    IF NOT v_target_exists THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Target Setup task must be active and use Display / Container Material';
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

COMMIT;

SELECT
    '2026-09-12-setup-display-ownership-v0.1.0' AS applied_revision,
    current_user AS applied_by,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_owner(text,bigint,bigint,bigint)',
        'EXECUTE'
    ) AS app_can_set_display_owner;
