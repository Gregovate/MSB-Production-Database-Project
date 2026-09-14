/*
Issue #184 — disposable browser-review fixture for the durable Kit Inventory
and T-Post stock application.

DISPOSABLE DATABASE ONLY.

This file deliberately creates a small amount of visible review data after
migrations 032 -> 037 have been applied to a disposable current-Production
clone. It is not a Production preload and must never be used as #167
reconstruction data.

The fixture:
- adds no physical inventory-count events;
- creates no task -> KIT relationship;
- creates no real 2026 Setup Session;
- does not depend on procedure-evidence runtime;
- uses existing physical Containers and the existing KIT assignment authority.
*/
\set ON_ERROR_STOP on

DO $fixture$
DECLARE
    v_manager_email text;
    v_tpost_material_id integer;
    v_bungee_material_id integer;
    v_kit_container_id integer;
    v_setup_task_id bigint;
    v_requirement_id bigint;
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_event') IS NULL THEN
        RAISE EXCEPTION '#184 durable Extra Material migrations 032 -> 037 are required first';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION 'Browser fixture refuses to run when a 2026 Setup Session exists';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id = u.role
    WHERE u.status = 'active'
      AND u.email IS NOT NULL
      AND EXISTS (SELECT 1 FROM ref.person p WHERE p.directus_user_id = u.id)
      AND (
          r.name IN ('Manager','Administrator')
          OR EXISTS (
              SELECT 1
              FROM public.directus_access a
              JOIN public.directus_policies p ON p.id = a.policy
              WHERE (a."user" = u.id OR (u.role IS NOT NULL AND a.role = u.role))
                AND p.name IN ('Manager','Administrator')
          )
      )
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No mapped active Manager/Administrator exists for #184 browser fixture';
    END IF;

    SELECT setup_extra_material_id
      INTO v_tpost_material_id
    FROM ref.setup_extra_material
    WHERE material_name = 'T-Post'
      AND active_flag;

    SELECT setup_extra_material_id
      INTO v_bungee_material_id
    FROM ref.setup_extra_material
    WHERE material_name = 'Ball Bungee'
      AND active_flag;

    IF v_tpost_material_id IS NULL OR v_bungee_material_id IS NULL THEN
        RAISE EXCEPTION 'Expected #184 normalized catalog identities are missing';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id = 36)
       OR NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id = 118) THEN
        RAISE EXCEPTION 'Confirmed T-Post source Containers 36 and 118 are required for #184 browser review';
    END IF;

    /* Separate T-Post stock rows. Unknown lengths/counts remain unknown. */
    PERFORM * FROM ref.set_setup_container_extra_material(
        v_manager_email,
        NULL,
        36,
        v_tpost_material_id,
        NULL,
        'EA',
        'Shared mixed T-Post stock',
        NULL,
        NULL,
        NULL,
        'UNVERIFIED',
        'Disposable #184 browser fixture — shared T-Post source; no physical count recorded.',
        true
    );

    PERFORM * FROM ref.set_setup_container_extra_material(
        v_manager_email,
        NULL,
        118,
        v_tpost_material_id,
        NULL,
        'EA',
        'Special short T-Post stock',
        NULL,
        NULL,
        NULL,
        'UNVERIFIED',
        'Disposable #184 browser fixture — special short stock; exact length/count intentionally unknown.',
        true
    );

    /* Use an existing assigned physical Kit Box so the reverse KIT relationship
       shown by #184 is real current data rather than a fixture-created link. */
    SELECT c.container_id, t.setup_task_id
      INTO v_kit_container_id, v_setup_task_id
    FROM ref.container c
    JOIN ref.setup_task_container_support tc
      ON tc.container_id = c.container_id
     AND tc.relationship_type = 'KIT'
    JOIN ref.setup_task t
      ON t.setup_task_id = tc.setup_task_id
     AND t.active_flag
    WHERE c.container_type_id = 2
    ORDER BY c.container_id, t.setup_task_id
    LIMIT 1;

    IF v_kit_container_id IS NULL OR v_setup_task_id IS NULL THEN
        RAISE EXCEPTION 'No current assigned physical Kit Box is available for #184 browser fixture';
    END IF;

    PERFORM * FROM ref.set_setup_container_extra_material(
        v_manager_email,
        NULL,
        v_kit_container_id,
        v_bungee_material_id,
        NULL,
        'EA',
        'Mixed / verify in field',
        NULL,
        NULL,
        NULL,
        'UNVERIFIED',
        'Disposable #184 browser fixture — expected Kit content for operator review only.',
        true
    );

    PERFORM * FROM ref.set_setup_container_unverified_items(
        v_manager_email,
        v_kit_container_id,
        'Disposable #184 browser fixture remainder — verify that Remainders / Unverified Items are visible and editable only with Manager authority.'
    );

    SELECT setup_task_extra_material_id
      INTO v_requirement_id
    FROM ref.set_setup_task_extra_material(
        v_manager_email,
        NULL,
        v_setup_task_id,
        v_bungee_material_id,
        NULL,
        'EA',
        'Mixed / verify in field',
        NULL,
        NULL,
        NULL,
        'CONDITIONAL',
        'UNVERIFIED',
        'Disposable #184 browser fixture — reusable task requirement for UI/source review.',
        true
    );

    PERFORM * FROM ref.set_setup_task_extra_material_source(
        v_manager_email,
        NULL,
        v_requirement_id,
        v_kit_container_id,
        NULL,
        'UNVERIFIED',
        'Disposable #184 browser fixture — source is the already-assigned Kit Box.',
        true
    );

    IF EXISTS (SELECT 1 FROM ops.setup_extra_material_inventory_event) THEN
        RAISE EXCEPTION '#184 browser fixture unexpectedly created physical inventory events';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION '#184 browser fixture unexpectedly created a 2026 Setup Session';
    END IF;

    RAISE NOTICE '#184 browser fixture manager: %', v_manager_email;
    RAISE NOTICE '#184 browser fixture Kit container: %', v_kit_container_id;
    RAISE NOTICE '#184 browser fixture reusable task: %', v_setup_task_id;
END
$fixture$;

SELECT
    'SETUP_184_KIT_INVENTORY_BROWSER_FIXTURE_READY' AS fixture_result,
    (SELECT count(*) FROM ref.setup_container_extra_material WHERE active_flag) AS active_container_material_rows,
    (SELECT count(*) FROM ref.setup_task_extra_material WHERE active_flag) AS active_task_material_rows,
    (SELECT count(*) FROM ref.setup_task_extra_material_source WHERE active_flag) AS active_source_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material_review) AS remainder_rows,
    (SELECT count(*) FROM ops.setup_extra_material_inventory_event) AS physical_inventory_events,
    (SELECT count(*) FROM ops.setup_session WHERE season_year = 2026) AS setup_2026_sessions;
