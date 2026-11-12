/*
Filename: setup_145_material_audit_disposable_validation.sql
Issue: #145

DISPOSABLE CURRENT-PRODUCTION CLONE ONLY.

Purpose:
  Prove the narrowly scoped Manager shared/non-task Kit disposition command
  without creating task assignments, inventory/source facts, or annual Setup
  state. All mutations are rolled back.
*/

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_container_id integer;
    v_assigned_container_id integer;
    v_type_before integer;
    v_kit_rows_before integer;
    v_kit_rows_after integer;
    v_inventory_events_before bigint;
    v_inventory_events_after bigint;
    v_source_rows_before bigint;
    v_source_rows_after bigint;
    v_2026_before integer;
    v_2026_after integer;
    v_assignment_rejected boolean := false;
BEGIN
    IF to_regclass('ref.setup_kit_assignment_disposition') IS NULL THEN
        RAISE EXCEPTION 'Kit assignment disposition table is missing';
    END IF;
    IF to_regprocedure('ref.set_setup_kit_assignment_disposition(text,integer,boolean,text)') IS NULL THEN
        RAISE EXCEPTION 'Kit assignment disposition Manager command is missing';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users AS u
    JOIN ref.person AS p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c ON true
    WHERE u.status = 'active'
      AND coalesce(c.can_manage_setup, false)
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No active mapped Setup Manager is available in the disposable clone';
    END IF;

    SELECT c.container_id, c.container_type_id
      INTO v_container_id, v_type_before
    FROM ref.container AS c
    WHERE c.container_type_id = 2
      AND c.container_id IN (69,123,124,125,128,129)
      AND NOT EXISTS (
          SELECT 1
          FROM ref.setup_task_container_support AS tc
          WHERE tc.container_id = c.container_id
            AND tc.relationship_type = 'KIT'
      )
    ORDER BY c.container_id
    LIMIT 1;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION 'No reviewed shared/non-task candidate Kit Box is available in disposable Production clone';
    END IF;

    SELECT c.container_id
      INTO v_assigned_container_id
    FROM ref.container AS c
    WHERE c.container_type_id = 2
      AND EXISTS (
          SELECT 1
          FROM ref.setup_task_container_support AS tc
          WHERE tc.container_id = c.container_id
            AND tc.relationship_type = 'KIT'
      )
    ORDER BY c.container_id
    LIMIT 1;

    IF v_assigned_container_id IS NULL THEN
        RAISE EXCEPTION 'No assigned Kit Box is available for negative disposition proof';
    END IF;

    SELECT count(*) INTO v_kit_rows_before
    FROM ref.setup_task_container_support
    WHERE relationship_type = 'KIT';

    SELECT count(*) INTO v_inventory_events_before
    FROM ops.setup_extra_material_inventory_event;

    SELECT count(*) INTO v_source_rows_before
    FROM ref.setup_task_extra_material_source;

    SELECT count(*) INTO v_2026_before
    FROM ops.setup_session
    WHERE season_year = 2026;

    PERFORM *
    FROM ref.set_setup_kit_assignment_disposition(
        v_manager_email,
        v_container_id,
        true,
        'Disposable #145 reviewed shared/non-task proof.'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_kit_assignment_disposition AS d
        WHERE d.container_id = v_container_id
          AND d.disposition = 'SHARED_NON_TASK'
          AND d.active_flag
          AND d.reviewed_by_person_id IS NOT NULL
          AND d.reviewed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Reviewed shared/non-task disposition was not persisted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_container_support AS tc
        WHERE tc.container_id = v_container_id
          AND tc.relationship_type = 'KIT'
    ) THEN
        RAISE EXCEPTION 'Disposition command created a fake task -> KIT assignment';
    END IF;

    IF (SELECT c.container_type_id FROM ref.container AS c WHERE c.container_id = v_container_id)
       IS DISTINCT FROM v_type_before THEN
        RAISE EXCEPTION 'Disposition command changed Container type';
    END IF;

    BEGIN
        PERFORM *
        FROM ref.set_setup_kit_assignment_disposition(
            v_manager_email,
            v_assigned_container_id,
            true,
            'Must be rejected while KIT relationship exists.'
        );
    EXCEPTION
        WHEN check_violation THEN
            v_assignment_rejected := true;
    END;

    IF NOT v_assignment_rejected THEN
        RAISE EXCEPTION 'Assigned Kit was incorrectly accepted as reviewed shared/non-task';
    END IF;

    PERFORM *
    FROM ref.set_setup_kit_assignment_disposition(
        v_manager_email,
        v_container_id,
        false,
        'Disposable #145 clear proof.'
    );

    IF EXISTS (
        SELECT 1
        FROM ref.setup_kit_assignment_disposition AS d
        WHERE d.container_id = v_container_id
          AND d.active_flag
    ) THEN
        RAISE EXCEPTION 'Cleared shared/non-task disposition remained active';
    END IF;

    SELECT count(*) INTO v_kit_rows_after
    FROM ref.setup_task_container_support
    WHERE relationship_type = 'KIT';

    SELECT count(*) INTO v_inventory_events_after
    FROM ops.setup_extra_material_inventory_event;

    SELECT count(*) INTO v_source_rows_after
    FROM ref.setup_task_extra_material_source;

    SELECT count(*) INTO v_2026_after
    FROM ops.setup_session
    WHERE season_year = 2026;

    IF v_kit_rows_after <> v_kit_rows_before THEN
        RAISE EXCEPTION 'Disposition validation changed reusable task KIT relationships';
    END IF;
    IF v_inventory_events_after <> v_inventory_events_before THEN
        RAISE EXCEPTION 'Disposition validation changed physical inventory events';
    END IF;
    IF v_source_rows_after <> v_source_rows_before THEN
        RAISE EXCEPTION 'Disposition validation changed Extra Material source authority';
    END IF;
    IF v_2026_after <> v_2026_before THEN
        RAISE EXCEPTION 'Disposition validation created or changed a 2026 Setup Session';
    END IF;

    RAISE NOTICE 'Setup #145 disposition proof passed for Container %; assigned negative proof Container %',
        v_container_id, v_assigned_container_id;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_145_MATERIAL_AUDIT_DISPOSABLE_VALIDATION_PASS' AS result;
