/*
Issue #167 — Extra Material / Container expected-content / inventory foundation
DISPOSABLE DATABASE VALIDATION ONLY

Run only after migrations 032 -> 037 have been applied to a disposable clone of
current Production. All test data below is rolled back.
*/
\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_crew_email text;
    v_volunteer_email text;
    v_material_id integer;
    v_content_id bigint;
    v_balance numeric;
    v_container_id integer;
    v_before_2026 integer;
    v_error_seen boolean;
BEGIN
    SELECT count(*) INTO v_before_2026
    FROM ops.setup_session
    WHERE season_year = 2026;
    IF v_before_2026 <> 0 THEN
        RAISE EXCEPTION 'Precondition failed: disposable clone already contains a 2026 Setup Session';
    END IF;

    IF (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) <> 43 THEN
        RAISE EXCEPTION 'Expected exactly 43 normalized active Extra Material catalog rows';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_extra_material
        WHERE material_name IN (
            'Y-Post','Fence Post','Tie Strap','PVC Distance Pipe','Screw Anchor',
            'Nylon Cord','Bull Line','Bow Line','Concrete Weight','Eye Hook'
        )
    ) THEN
        RAISE EXCEPTION 'Bad/legacy Extra Material identity reached normalized catalog';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='T-Post')
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Ball Bungee')
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='D-Ring')
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Tripple Tap')
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Arch Foot') THEN
        RAISE EXCEPTION 'Expected normalized catalog identities are missing';
    END IF;

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
              SELECT 1 FROM public.directus_access a
              JOIN public.directus_policies p ON p.id=a.policy
              WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
                AND p.name IN ('Manager','Administrator')
          )
      )
    ORDER BY u.email
    LIMIT 1;

    SELECT lower(u.email)
      INTO v_crew_email
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    WHERE u.status='active'
      AND u.email IS NOT NULL
      AND EXISTS (SELECT 1 FROM ref.person p WHERE p.directus_user_id=u.id)
      AND (
          r.name='Production Crew'
          OR EXISTS (
              SELECT 1 FROM public.directus_access a
              JOIN public.directus_policies p ON p.id=a.policy
              WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
                AND p.name='Production Crew'
          )
      )
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No mapped active Manager/Administrator exists for disposable #167 validation';
    END IF;
    IF v_crew_email IS NULL THEN
        RAISE EXCEPTION 'No mapped active Production Crew user exists for disposable #167 inventory validation';
    END IF;

    /* Negative authorization proof must use a Volunteer-only account. A person
       may legitimately carry a Volunteer role/policy plus Production Crew or
       Manager authority; such a dual-authorized account is expected to pass the
       inventory command and must not be used as the denial test actor. */
    SELECT lower(u.email)
      INTO v_volunteer_email
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    WHERE u.status='active'
      AND u.email IS NOT NULL
      AND EXISTS (SELECT 1 FROM ref.person p WHERE p.directus_user_id=u.id)
      AND (
          r.name='Volunteer'
          OR EXISTS (
              SELECT 1 FROM public.directus_access a
              JOIN public.directus_policies p ON p.id=a.policy
              WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
                AND p.name='Volunteer'
          )
      )
      AND coalesce(r.name,'') NOT IN ('Production Crew','Manager','Administrator')
      AND NOT EXISTS (
          SELECT 1 FROM public.directus_access a
          JOIN public.directus_policies p ON p.id=a.policy
          WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
            AND p.name IN ('Production Crew','Manager','Administrator')
      )
    ORDER BY u.email
    LIMIT 1;

    RAISE NOTICE 'Disposable #167 Manager actor: %', v_manager_email;
    RAISE NOTICE 'Disposable #167 Production Crew actor: %', v_crew_email;
    IF v_volunteer_email IS NULL THEN
        RAISE NOTICE 'Disposable #167 Volunteer-only denial actor: none available; negative Volunteer proof skipped';
    ELSE
        RAISE NOTICE 'Disposable #167 Volunteer-only denial actor: %', v_volunteer_email;
    END IF;

    /* Shared T-post stock exists in current Production as Container 36. Use it
       when available; otherwise use the first current physical Container in the
       disposable clone without changing durable Production assumptions. */
    SELECT c.container_id INTO v_container_id
    FROM ref.container c
    ORDER BY CASE WHEN c.container_id=36 THEN 0 ELSE 1 END, c.container_id
    LIMIT 1;

    SELECT m.setup_extra_material_id INTO v_material_id
    FROM ref.setup_extra_material m
    WHERE m.material_name='T-Post';

    SELECT r.setup_container_extra_material_id
      INTO v_content_id
    FROM ref.set_setup_container_extra_material(
        v_manager_email, NULL, v_container_id, v_material_id,
        10, 'EA', NULL, 6, 'FT', NULL, 'UNVERIFIED',
        'Disposable #167 validation row', true
    ) r;

    IF v_content_id IS NULL THEN
        RAISE EXCEPTION 'Manager could not create disposable Container expected-content row';
    END IF;

    /* Exact duplicate active Container/material/spec rows must fail closed so a
       double-click or repeated import cannot double-count expected stock. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ref.set_setup_container_extra_material(
            v_manager_email, NULL, v_container_id, v_material_id,
            10, 'EA', NULL, 6, 'FT', NULL, 'UNVERIFIED',
            'Duplicate should fail', true
        );
    EXCEPTION WHEN SQLSTATE '23505' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Duplicate active Container material/spec unexpectedly succeeded';
    END IF;

    /* Durable balance is unknown until a physical count exists. */
    SELECT b.on_hand_quantity INTO v_balance
    FROM ops.setup_extra_material_inventory_balance b
    WHERE b.setup_container_extra_material_id=v_content_id;
    IF v_balance IS NOT NULL THEN
        RAISE EXCEPTION 'Uncounted stock must report NULL on-hand, not zero';
    END IF;

    /* Crew may not record a delta before establishing the baseline. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ops.record_setup_extra_material_inventory_event(
            v_crew_email, v_content_id, 'DAMAGE_LOSS', -1, 'Should fail before initial count', NULL
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Damage/loss before initial count unexpectedly succeeded';
    END IF;

    PERFORM * FROM ops.record_setup_extra_material_inventory_event(
        v_crew_email, v_content_id, 'INITIAL_COUNT', 10, 'Disposable initial count', NULL
    );
    PERFORM * FROM ops.record_setup_extra_material_inventory_event(
        v_crew_email, v_content_id, 'DAMAGE_LOSS', -2, 'Disposable frozen-post loss', NULL
    );

    SELECT b.on_hand_quantity INTO v_balance
    FROM ops.setup_extra_material_inventory_balance b
    WHERE b.setup_container_extra_material_id=v_content_id;
    IF v_balance <> 8 THEN
        RAISE EXCEPTION 'Expected on-hand balance 8 after initial 10 and damage -2, got %', v_balance;
    END IF;

    /* INITIAL_COUNT is a one-time opening event. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ops.record_setup_extra_material_inventory_event(
            v_crew_email, v_content_id, 'INITIAL_COUNT', 8, 'Should fail second initial count', NULL
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Second INITIAL_COUNT unexpectedly succeeded';
    END IF;

    /* Inventory cannot go negative. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ops.record_setup_extra_material_inventory_event(
            v_crew_email, v_content_id, 'DAMAGE_LOSS', -9, 'Should fail negative stock', NULL
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Inventory adjustment unexpectedly produced negative stock';
    END IF;

    /* Once history exists, changing the material/spec identity is prohibited. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ref.set_setup_container_extra_material(
            v_manager_email, v_content_id, v_container_id, v_material_id,
            10, 'EA', NULL, 7, 'FT', NULL, 'UNVERIFIED',
            'Should fail inventoried identity change', true
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Inventoried material/spec identity unexpectedly changed';
    END IF;

    /* A Manager may change expected quantity/notes without rewriting stock. */
    PERFORM * FROM ref.set_setup_container_extra_material(
        v_manager_email, v_content_id, v_container_id, v_material_id,
        12, 'EA', NULL, 6, 'FT', NULL, 'NEEDS_REVIEW',
        'Expected quantity corrected independently of physical balance', true
    );
    SELECT b.on_hand_quantity INTO v_balance
    FROM ops.setup_extra_material_inventory_balance b
    WHERE b.setup_container_extra_material_id=v_content_id;
    IF v_balance <> 8 THEN
        RAISE EXCEPTION 'Expected-content correction unexpectedly changed physical inventory';
    END IF;

    /* Nonzero stock cannot be hidden by deactivating expected contents. */
    v_error_seen := false;
    BEGIN
        PERFORM * FROM ref.set_setup_container_extra_material(
            v_manager_email, v_content_id, v_container_id, v_material_id,
            12, 'EA', NULL, 6, 'FT', NULL, 'NEEDS_REVIEW', NULL, false
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_error_seen := true;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Nonzero physical stock was unexpectedly hidden by deactivation';
    END IF;

    /* A Volunteer-only account must not receive durable inventory authority.
       Dual-authorized Volunteer + Production Crew/Manager accounts are correctly
       excluded from this negative test because their elevated authority wins. */
    IF v_volunteer_email IS NOT NULL THEN
        v_error_seen := false;
        BEGIN
            PERFORM * FROM ops.record_setup_extra_material_inventory_event(
                v_volunteer_email, v_content_id, 'COUNT_CORRECTION', 1, 'Volunteer negative authorization proof', NULL
            );
        EXCEPTION WHEN SQLSTATE '42501' THEN
            v_error_seen := true;
        END;
        IF NOT v_error_seen THEN
            RAISE EXCEPTION 'Volunteer-only account unexpectedly received Extra Material inventory authority';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 disposable validation unexpectedly created a 2026 Setup Session';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_extra_material','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_container_extra_material','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Extra Material table DML';
    END IF;
END
$validation$;

SELECT
    'SETUP_167_EXTRA_MATERIAL_FOUNDATION_DISPOSABLE_PASS' AS validation_result,
    (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) AS normalized_catalog_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;

ROLLBACK;
