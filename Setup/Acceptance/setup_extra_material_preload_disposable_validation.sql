/*
Issue #167 — normalized known-evidence preload validation
DISPOSABLE DATABASE VALIDATION ONLY

Run after migrations 032 -> 038 on a disposable current-Production clone.
The preload is intentionally UNVERIFIED; unmatched/ambiguous staging evidence
remains in the #167 verification queues instead of being guessed into schema.
*/
\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_task_rows integer;
    v_container_rows integer;
BEGIN
    SELECT count(*) INTO v_task_rows
    FROM ref.setup_task_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    SELECT count(*) INTO v_container_rows
    FROM ref.setup_container_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    IF v_task_rows <> 23 THEN
        RAISE EXCEPTION 'Expected 23 normalized task preload rows, got %', v_task_rows;
    END IF;
    IF v_container_rows <> 10 THEN
        RAISE EXCEPTION 'Expected 10 normalized Container preload rows, got %', v_container_rows;
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material
        WHERE notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
          AND verification_state <> 'UNVERIFIED'
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material
        WHERE notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
          AND verification_state <> 'UNVERIFIED'
    ) THEN
        RAISE EXCEPTION 'Preloaded procedure evidence was unexpectedly marked accepted';
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
        FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=205
          AND m.material_name='Arch Foot Pad'
          AND tm.quantity_required=6
          AND tm.verification_state='UNVERIFIED'
          AND tm.active_flag
    ) THEN
        RAISE EXCEPTION 'Front Arch Foot Pad preload proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=72
          AND m.material_name='T-Post'
          AND cem.expected_quantity=50
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Volunteer Path Kit T-Post preload proof is missing';
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
        WHERE cem.container_id=60
          AND m.material_name='Post Base'
          AND cem.expected_quantity=8
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Elf Choir Kit Post Base preload proof is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
    ) THEN
        RAISE EXCEPTION 'Expected-content preload unexpectedly created physical inventory history';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 normalized preload unexpectedly created a 2026 Setup Session';
    END IF;
END
$validation$;

SELECT
    'SETUP_167_NORMALIZED_PRELOAD_DISPOSABLE_PASS' AS validation_result,
    (SELECT count(*) FROM ref.setup_task_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%') AS task_preload_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%') AS container_preload_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;
