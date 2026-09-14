/*
Issue #167 — normalized known-evidence preload + queryable evidence validation
DISPOSABLE DATABASE VALIDATION ONLY

Run after migrations 032 -> 041 on a disposable current-Production clone.
The operational preload is intentionally UNVERIFIED. The broader evidence index
is queryable even where task/Container ownership remains unresolved.
*/
\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_task_rows integer;
    v_container_rows integer;
    v_evidence_rows integer;
BEGIN
    SELECT count(*) INTO v_task_rows
    FROM ref.setup_task_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    SELECT count(*) INTO v_container_rows
    FROM ref.setup_container_extra_material
    WHERE active_flag
      AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%';

    SELECT count(*) INTO v_evidence_rows
    FROM ref.setup_extra_material_evidence_source
    WHERE source_batch='MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx';

    IF v_task_rows <> 23 THEN
        RAISE EXCEPTION 'Expected 23 normalized task preload rows, got %', v_task_rows;
    END IF;
    IF v_container_rows <> 10 THEN
        RAISE EXCEPTION 'Expected 10 normalized Container preload rows, got %', v_container_rows;
    END IF;
    IF v_evidence_rows <> 35 THEN
        RAISE EXCEPTION 'Expected 35 queryable source-document evidence rows, got %', v_evidence_rows;
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

    /* The evidence index must preserve useful findings even before final
       assignment. These proofs intentionally include both candidate-Container
       and unresolved examples. */
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material_evidence_source e
        WHERE e.source_file='08-Elf Choir-EC(1).pdf'
          AND 60=ANY(e.current_stage_kit_candidate_ids)
          AND 'Post Base'=ANY(e.material_families)
          AND 'Rebar Stake'=ANY(e.material_families)
    ) THEN
        RAISE EXCEPTION 'Elf Choir broader evidence index proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material_evidence_source e
        WHERE e.source_file='02-Mega Tree (1).pdf'
          AND 'Wooden Support Base'=ANY(e.material_families)
          AND 41=ANY(e.suggested_setup_task_ids)
          AND e.current_stage_kit_candidate_ids IS NULL
    ) THEN
        RAISE EXCEPTION 'Mega Tree unresolved-but-queryable evidence proof is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material_evidence_source e
        WHERE e.source_file='26-Santa''s Station-QV Setup Procedure.pdf'
          AND 80=ANY(e.current_stage_kit_candidate_ids)
          AND 'Concrete Block'=ANY(e.material_families)
          AND e.verification_needed
    ) THEN
        RAISE EXCEPTION 'Santa Station candidate-Container evidence proof is missing';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_extra_material_evidence_source','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_extra_material_evidence_source','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_extra_material_evidence_source','DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has evidence-index write authority';
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
    'SETUP_167_NORMALIZED_PRELOAD_AND_EVIDENCE_DISPOSABLE_PASS' AS validation_result,
    (SELECT count(*) FROM ref.setup_task_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%') AS task_preload_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%') AS container_preload_rows,
    (SELECT count(*) FROM ref.setup_extra_material_evidence_source
     WHERE source_batch='MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx') AS evidence_source_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;
