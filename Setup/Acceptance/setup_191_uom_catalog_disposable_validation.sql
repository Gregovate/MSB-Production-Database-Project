/*
Issue #191 — disposable validation for governed Setup UOM catalog.

Runs only after migration 049 on a disposable current-Production clone.
All behavioral test writes are rolled back.
*/
\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_material_id integer;
    v_rejected boolean;
BEGIN
    IF to_regclass('ref.setup_uom') IS NULL THEN
        RAISE EXCEPTION '#191 UOM catalog table is missing';
    END IF;

    IF (SELECT count(*) FROM ref.setup_uom WHERE uom_code IN ('EA','FT','IN','SHEET') AND active_flag) <> 4 THEN
        RAISE EXCEPTION '#191 starter UOM set EA/FT/IN/SHEET is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_extra_material m
        LEFT JOIN ref.setup_uom u ON u.uom_code=m.default_uom
        WHERE u.uom_code IS NULL
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material tm
        LEFT JOIN ref.setup_uom u ON u.uom_code=tm.quantity_uom
        WHERE u.uom_code IS NULL
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cm
        LEFT JOIN ref.setup_uom u ON u.uom_code=cm.quantity_uom
        WHERE u.uom_code IS NULL
    ) THEN
        RAISE EXCEPTION '#191 migration left an orphaned current UOM reference';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname='fk_setup_extra_material_default_uom' AND contype='f' AND convalidated
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname='fk_setup_task_extra_material_quantity_uom' AND contype='f' AND convalidated
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname='fk_setup_container_extra_material_quantity_uom' AND contype='f' AND convalidated
    ) THEN
        RAISE EXCEPTION '#191 expected UOM foreign keys are missing or unvalidated';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_uom','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_uom','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_uom','DELETE') THEN
        RAISE EXCEPTION '#191 leaked broad UOM table write privilege to fieldwiring_app';
    END IF;

    IF NOT has_table_privilege('fieldwiring_app','ref.setup_uom','SELECT')
       OR NOT has_function_privilege('fieldwiring_app','ref.create_setup_uom(text,text,text,text)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.update_setup_uom(text,text,text,text,boolean,integer)','EXECUTE') THEN
        RAISE EXCEPTION '#191 required governed UOM read/command privileges are missing';
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
        RAISE EXCEPTION 'No mapped active Manager/Administrator exists for #191 validation';
    END IF;

    PERFORM * FROM ref.create_setup_uom(
        v_manager_email,
        'ZZUOMTEST',
        'Disposable UOM Test',
        'Rollback-only #191 validation'
    );

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_uom
        WHERE uom_code='ZZUOMTEST' AND active_flag
    ) THEN
        RAISE EXCEPTION '#191 governed UOM create command did not persist test row';
    END IF;

    v_rejected := false;
    BEGIN
        PERFORM * FROM ref.create_setup_extra_material(
            v_manager_email,
            'Disposable Invalid UOM Material',
            'REUSABLE',
            'ZZNOTREAL',
            'Rollback-only #191 validation'
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION '#191 unknown UOM was accepted by Extra Material command';
    END IF;

    SELECT x.setup_extra_material_id
      INTO v_material_id
    FROM ref.create_setup_extra_material(
        v_manager_email,
        'Disposable Governed UOM Material',
        'REUSABLE',
        'ZZUOMTEST',
        'Rollback-only #191 validation'
    ) x;

    v_rejected := false;
    BEGIN
        PERFORM * FROM ref.update_setup_uom(
            v_manager_email,
            'ZZUOMTEST',
            'Disposable UOM Test',
            'Rollback-only #191 validation',
            false,
            100
        );
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION '#191 allowed deactivation of UOM still referenced by active material';
    END IF;

    PERFORM * FROM ref.update_setup_extra_material(
        v_manager_email,
        v_material_id,
        'Disposable Governed UOM Material',
        'REUSABLE',
        'ZZUOMTEST',
        'Rollback-only #191 validation',
        false,
        100
    );

    PERFORM * FROM ref.update_setup_uom(
        v_manager_email,
        'ZZUOMTEST',
        'Disposable UOM Test',
        'Rollback-only #191 validation',
        false,
        100
    );

    IF EXISTS (
        SELECT 1 FROM ref.setup_uom
        WHERE uom_code='ZZUOMTEST' AND active_flag
    ) THEN
        RAISE EXCEPTION '#191 UOM remained active after all active references were removed';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#191 validation unexpectedly created a 2026 Setup Session';
    END IF;
END
$validation$;

SELECT
    'SETUP_191_UOM_CATALOG_DISPOSABLE_PASS' AS validation_result,
    (SELECT count(*) FROM ref.setup_uom) AS uom_catalog_rows,
    (SELECT string_agg(uom_code, ',' ORDER BY uom_code)
       FROM ref.setup_uom
      WHERE uom_code IN ('EA','FT','IN','SHEET')) AS starter_uoms,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;

ROLLBACK;
