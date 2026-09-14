/*
Issue #167 — one-time normalized inventory preload validation
DISPOSABLE DATABASE VALIDATION ONLY

Run after migrations 032 -> 038 and 043 on a disposable current-Production clone.
Known normalized facts may enter as UNVERIFIED. Remainders remain reviewable.
T-Post stock is deliberately separate from Kit Box contents.
*/
\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_task_rows integer;
    v_original_container_rows integer;
    v_procedure_kit_rows integer;
    v_remainder_kits integer;
BEGIN
    SELECT count(*) INTO v_task_rows
    FROM ref.setup_task_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    SELECT count(*) INTO v_original_container_rows
    FROM ref.setup_container_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    SELECT count(*) INTO v_procedure_kit_rows
    FROM ref.setup_container_extra_material
    WHERE active_flag
      AND notes LIKE 'Procedure-derived Kit preload v6.%';

    SELECT count(*) INTO v_remainder_kits
    FROM ref.setup_container_extra_material_review
    WHERE unverified_items_text LIKE '%[#167 PROCEDURE REMAINDERS v6]%';

    IF v_task_rows <> 23 THEN
        RAISE EXCEPTION 'Expected 23 normalized task preload rows, got %', v_task_rows;
    END IF;

    /* Migration 038 initially loaded ten Container rows. Migration 043
       intentionally deactivates the historical C072 T-Post Kit row because
       current T-Post inventory is shared stock outside Kit Boxes. */
    IF v_original_container_rows < 9 THEN
        RAISE EXCEPTION 'Expected at least 9 still-active original Container preload rows, got %', v_original_container_rows;
    END IF;
    IF v_procedure_kit_rows < 60 THEN
        RAISE EXCEPTION 'Expected at least 60 broadened normalized Kit preload rows, got %', v_procedure_kit_rows;
    END IF;
    IF v_remainder_kits < 18 THEN
        RAISE EXCEPTION 'Expected at least 18 Kits with procedure remainders, got %', v_remainder_kits;
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material
        WHERE notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
          AND verification_state <> 'UNVERIFIED'
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material
        WHERE active_flag
          AND (
              notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
              OR notes LIKE 'Procedure-derived Kit preload v6.%'
              OR notes LIKE 'Preloaded from #167 physical-source reconciliation.%'
          )
          AND verification_state <> 'UNVERIFIED'
    ) THEN
        RAISE EXCEPTION 'One-time inventory preload unexpectedly marked evidence as accepted';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=73
          AND m.material_name='Ratchet Strap'
          AND tm.quantity_required=3
          AND tm.verification_state='UNVERIFIED'
          AND tm.active_flag
    ) THEN
        RAISE EXCEPTION 'Church RGB Tree Ratchet Strap preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=1
          AND m.material_name='Foam Noodle'
          AND tm.quantity_required=4
          AND tm.verification_state='UNVERIFIED'
          AND tm.active_flag
    ) THEN
        RAISE EXCEPTION 'Front Arch Foam Noodle preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=60
          AND m.material_name='Post Base'
          AND cem.expected_quantity=8
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Elf Choir Kit Post Base preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=60
          AND m.material_name='Ball Bungee'
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Elf Choir Kit Ball Bungee preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=76
          AND m.material_name='Arch Foot'
          AND cem.expected_quantity=32
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Racing Arches Kit Arch Foot preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=59
          AND m.material_name='Foam Noodle'
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Front Entrance Kit normalized preload proof is missing';
    END IF;

    /* T-Post current stock is separate from Kit Boxes. Historical procedure
       evidence that C072 once carried extra posts remains in Remainders only. */
    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=72
          AND m.material_name='T-Post'
          AND cem.active_flag
          AND cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
    ) THEN
        RAISE EXCEPTION 'Historical C072 T-Post procedure row incorrectly remains active Kit inventory';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=36
          AND m.material_name='T-Post'
          AND cem.active_flag
    ) OR NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=118
          AND m.material_name='T-Post'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Separate T-Post stock Containers 36/118 are not both configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material_review
        WHERE container_id=72
          AND unverified_items_text LIKE '%C072 carried extra T-Posts%'
    ) THEN
        RAISE EXCEPTION 'C072 historical T-Post procedure claim was not preserved as a remainder';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
           OR cem.notes LIKE 'Procedure-derived Kit preload v6.%'
           OR cem.notes LIKE 'Preloaded from #167 physical-source reconciliation.%'
    ) THEN
        RAISE EXCEPTION 'One-time preload unexpectedly created physical inventory history';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 preload unexpectedly created a 2026 Setup Session';
    END IF;
END
$validation$;

SELECT
    'SETUP_167_ONE_TIME_INVENTORY_PRELOAD_DISPOSABLE_PASS' AS validation_result,
    (SELECT count(*) FROM ref.setup_task_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%') AS task_preload_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag AND notes LIKE 'Procedure-derived Kit preload v6.%') AS procedure_loaded_kit_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material_review
     WHERE unverified_items_text LIKE '%[#167 PROCEDURE REMAINDERS v6]%') AS kits_with_remainders,
    (SELECT count(*)
     FROM ref.setup_container_extra_material cem
     JOIN ref.setup_extra_material m USING (setup_extra_material_id)
     WHERE cem.active_flag AND m.material_name='T-Post'
       AND cem.container_id IN (36,118)) AS separate_tpost_stock_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;
