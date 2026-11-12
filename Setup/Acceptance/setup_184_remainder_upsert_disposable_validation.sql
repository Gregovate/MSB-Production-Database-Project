/*
Issue #184 — focused disposable validation for durable Kit Remainders.

This specifically protects the governed one-row-per-Container Remainder upsert
from the PL/pgSQL bare-column ON CONFLICT ambiguity previously seen in #152.
All test data is rolled back.
*/
\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_container_id integer;
BEGIN
    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    WHERE u.status='active'
      AND u.email IS NOT NULL
      AND EXISTS (SELECT 1 FROM ref.person p WHERE p.directus_user_id=u.id)
      AND (
          r.name IN ('Manager','Administrator')
          OR EXISTS (
              SELECT 1
              FROM public.directus_access a
              JOIN public.directus_policies p ON p.id=a.policy
              WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
                AND p.name IN ('Manager','Administrator')
          )
      )
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No mapped active Manager/Administrator exists for #184 Remainder validation';
    END IF;

    SELECT c.container_id
      INTO v_container_id
    FROM ref.container c
    ORDER BY c.container_id
    LIMIT 1;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION 'No current Container exists for #184 Remainder validation';
    END IF;

    PERFORM * FROM ref.set_setup_container_unverified_items(
        v_manager_email,
        v_container_id,
        'Disposable #184 Remainder validation row'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material_review r
        WHERE r.container_id=v_container_id
          AND r.unverified_items_text='Disposable #184 Remainder validation row'
    ) THEN
        RAISE EXCEPTION '#184 Remainder upsert did not persist expected review row';
    END IF;

    PERFORM * FROM ref.set_setup_container_unverified_items(
        v_manager_email,
        v_container_id,
        NULL
    );

    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material_review r
        WHERE r.container_id=v_container_id
    ) THEN
        RAISE EXCEPTION '#184 Remainder clear did not remove disposable review row';
    END IF;
END
$validation$;

SELECT
    'SETUP_184_REMAINDER_UPSERT_DISPOSABLE_PASS' AS validation_result,
    pg_get_functiondef(
        'ref.set_setup_container_unverified_items(text,integer,text)'::regprocedure
    ) LIKE '%ON CONFLICT ON CONSTRAINT setup_container_extra_material_review_pkey%'
        AS named_constraint_fix_present,
    pg_get_functiondef(
        'ref.set_setup_container_unverified_items(text,integer,text)'::regprocedure
    ) LIKE '%ON CONFLICT (container_id)%'
        AS ambiguous_bare_columns_present;

ROLLBACK;
