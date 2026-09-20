/* ============================================================================
MSB Setup Session — #145 Manager Material Completeness Audit foundation
Issue: #145
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-20 V0.1.0

Purpose:
  - add one durable Manager-reviewed shared/non-task disposition for physical
    Kit-typed Containers;
  - preserve existing task -> KIT authority unchanged;
  - keep the Catalog Material Completeness Audit itself read-only;
  - do not create annual Setup state, inventory state, Extra Material source
    authority, or any #206 Pick List/movement semantics.

This migration does not seed Production disposition rows.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.container') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup Container/Kit Manager foundation is required before migration 051';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS ref.setup_kit_assignment_disposition (
    container_id integer PRIMARY KEY
        REFERENCES ref.container(container_id),
    disposition text NOT NULL DEFAULT 'SHARED_NON_TASK',
    active_flag boolean NOT NULL DEFAULT true,
    review_note text,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    reviewed_by_person_id integer NOT NULL
        REFERENCES ref.person(person_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by_person_id integer NOT NULL
        REFERENCES ref.person(person_id),
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by_person_id integer NOT NULL
        REFERENCES ref.person(person_id),

    CONSTRAINT ck_setup_kit_assignment_disposition
        CHECK (disposition = 'SHARED_NON_TASK'),
    CONSTRAINT ck_setup_kit_assignment_disposition_active_note
        CHECK (NOT active_flag OR nullif(btrim(review_note), '') IS NOT NULL)
);

COMMENT ON TABLE ref.setup_kit_assignment_disposition IS
'Setup Manager review disposition for Kit-typed Containers intentionally used as shared/non-task stock. This is not a task assignment, inventory fact, Extra Material source, or annual Setup state.';

COMMENT ON COLUMN ref.setup_kit_assignment_disposition.active_flag IS
'Current disposition flag. Inactive rows retain prior Manager review evidence without clearing an audit exception.';

CREATE INDEX IF NOT EXISTS ix_setup_kit_assignment_disposition_active
    ON ref.setup_kit_assignment_disposition(active_flag, container_id);

CREATE OR REPLACE FUNCTION ref.set_setup_kit_assignment_disposition(
    p_email text,
    p_container_id integer,
    p_reviewed_shared_non_task boolean,
    p_review_note text DEFAULT NULL
)
RETURNS TABLE (
    container_id integer,
    disposition text,
    active_flag boolean,
    review_note text,
    reviewed_at timestamptz,
    reviewed_by_person_id integer,
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
    v_container_type_id integer;
    v_reviewed boolean := coalesce(p_reviewed_shared_non_task, false);
    v_note text := nullif(btrim(p_review_note), '');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_container_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Kit Box container is required';
    END IF;

    SELECT c.container_type_id
      INTO v_container_type_id
    FROM ref.container AS c
    WHERE c.container_id = p_container_id;

    IF v_container_type_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Container was not found';
    END IF;

    IF v_container_type_id <> 2 THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Only container_type_id=2 Kit Boxes may receive a shared/non-task Setup disposition';
    END IF;

    IF v_reviewed AND v_note IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'A Manager review reason is required for shared/non-task Kit disposition';
    END IF;

    IF v_reviewed AND EXISTS (
        SELECT 1
        FROM ref.setup_task_container_support AS tc
        WHERE tc.container_id = p_container_id
          AND tc.relationship_type = 'KIT'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Remove existing reusable task KIT relationships before marking this Container reviewed shared/non-task';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF v_reviewed THEN
        INSERT INTO ref.setup_kit_assignment_disposition(
            container_id,
            disposition,
            active_flag,
            review_note,
            reviewed_at,
            reviewed_by_person_id,
            created_by_person_id,
            updated_by_person_id
        )
        VALUES (
            p_container_id,
            'SHARED_NON_TASK',
            true,
            v_note,
            now(),
            v_person_id,
            v_person_id,
            v_person_id
        )
        ON CONFLICT (container_id)
        DO UPDATE SET
            disposition = 'SHARED_NON_TASK',
            active_flag = true,
            review_note = EXCLUDED.review_note,
            reviewed_at = now(),
            reviewed_by_person_id = v_person_id,
            updated_at = now(),
            updated_by_person_id = v_person_id;
    ELSE
        UPDATE ref.setup_kit_assignment_disposition AS d
           SET active_flag = false,
               review_note = coalesce(v_note, d.review_note),
               updated_at = now(),
               updated_by_person_id = v_person_id
         WHERE d.container_id = p_container_id;
    END IF;

    RETURN QUERY
    SELECT
        d.container_id,
        d.disposition,
        d.active_flag,
        d.review_note,
        d.reviewed_at,
        d.reviewed_by_person_id,
        v_display_name
    FROM ref.setup_kit_assignment_disposition AS d
    WHERE d.container_id = p_container_id;
END;
$function$;

REVOKE ALL ON TABLE ref.setup_kit_assignment_disposition FROM PUBLIC;
REVOKE ALL ON TABLE ref.setup_kit_assignment_disposition FROM fieldwiring_app;
GRANT SELECT ON TABLE ref.setup_kit_assignment_disposition TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.set_setup_kit_assignment_disposition(text,integer,boolean,text)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_kit_assignment_disposition(text,integer,boolean,text)
    TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-20-setup-material-completeness-audit-v0.1.0' AS applied_revision,
    current_user AS applied_by,
    has_table_privilege(
        'fieldwiring_app',
        'ref.setup_kit_assignment_disposition',
        'SELECT'
    ) AS app_can_read_kit_disposition,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_kit_assignment_disposition(text,integer,boolean,text)',
        'EXECUTE'
    ) AS app_can_set_kit_disposition;
