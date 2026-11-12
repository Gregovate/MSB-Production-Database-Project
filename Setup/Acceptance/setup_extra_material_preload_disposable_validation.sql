/*
Issue #167 — one-time normalized inventory/T-Post preload validation
DISPOSABLE DATABASE VALIDATION ONLY

Run after migrations 032 -> 038 and 043 -> 048 on a disposable current-Production clone.
Known normalized facts may enter as UNVERIFIED/NEEDS_REVIEW. Unknowns remain reviewable.
Shared T-Post stock is separate by default; explicit current-procedure Kit/Container
T-Post contents are retained when the physical source is supported.
*/
\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_task_rows integer;
    v_original_container_rows integer;
    v_procedure_kit_rows integer;
    v_remainder_kits integer;
    v_assigned_uncovered integer;
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

    /* 038 initially loaded ten Container rows. 043 intentionally deactivates the
       historical C072 T-Post row because current general T-Post stock moved to
       explicit sources. */
    IF v_original_container_rows < 9 THEN
        RAISE EXCEPTION 'Expected at least 9 still-active original Container preload rows, got %', v_original_container_rows;
    END IF;
    IF v_procedure_kit_rows < 60 THEN
        RAISE EXCEPTION 'Expected at least 60 still-active broadened normalized Kit preload rows, got %', v_procedure_kit_rows;
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
              OR notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%'
              OR notes LIKE '[#167 SHARED SPACER STOCK]%'
              OR notes LIKE '[#167 TPOST STOCK SPLIT]%'
          )
          AND verification_state <> 'UNVERIFIED'
    ) THEN
        RAISE EXCEPTION 'One-time inventory preload unexpectedly marked unreviewed evidence as accepted';
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
        WHERE cem.container_id=76
          AND m.material_name='Arch Foot'
          AND cem.expected_quantity=32
          AND cem.verification_state='UNVERIFIED'
          AND cem.active_flag
    ) THEN
        RAISE EXCEPTION 'Racing Arches Kit Arch Foot preload proof is missing';
    END IF;

    /* Assignment-driven cleanup: current C63 is Fred Stars, not Welcome Area. */
    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=63
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer'
          AND cem.notes LIKE 'Procedure-derived Kit preload v6.%03-Welcome Area-WA%'
    ) THEN
        RAISE EXCEPTION 'Stale Welcome Area spacer evidence remains on current Fred Stars Kit 63';
    END IF;

    /* Every currently assigned Kit must expose either normalized Extra Material,
       a durable review record, or current physical Display contents. */
    SELECT count(*) INTO v_assigned_uncovered
    FROM ref.container c
    WHERE c.container_type_id=2
      AND EXISTS (
          SELECT 1 FROM ref.setup_task_container_support tc
          WHERE tc.container_id=c.container_id AND tc.relationship_type='KIT'
      )
      AND NOT EXISTS (
          SELECT 1 FROM ref.setup_container_extra_material cem
          WHERE cem.container_id=c.container_id AND cem.active_flag
      )
      AND NOT EXISTS (
          SELECT 1 FROM ref.setup_container_extra_material_review r
          WHERE r.container_id=c.container_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM ref.display d
          LEFT JOIN ref.display_status ds ON ds.display_status_id=d.display_status_id
          WHERE d.container_id=c.container_id
            AND upper(coalesce(ds.display_status_name,'')) <> 'RECYCLED'
      );
    IF v_assigned_uncovered <> 0 THEN
        RAISE EXCEPTION 'Assigned Kit inventory coverage still has % uncovered Kit(s)', v_assigned_uncovered;
    END IF;

    /* Shared standard spacer stock is explicit and miscellaneous stock remains reviewable. */
    IF (SELECT count(*)
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id IN (123,124,125,128)
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer') <> 4 THEN
        RAISE EXCEPTION 'Shared standard-spacer stock rows are incomplete';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material_review
        WHERE container_id=129
          AND unverified_items_text LIKE '%[#167 SHARED SPACER STOCK]%'
    ) THEN
        RAISE EXCEPTION 'Misc Size Spacer Container 129 review state is missing';
    END IF;

    /* Historical C072 T-Post claim remains history only. */
    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=72
          AND m.material_name='T-Post'
          AND cem.active_flag
          AND cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
    ) THEN
        RAISE EXCEPTION 'Historical C072 T-Post procedure row incorrectly remains active inventory';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material_review
        WHERE container_id=72
          AND unverified_items_text LIKE '%C072 carried extra T-Posts%'
    ) THEN
        RAISE EXCEPTION 'C072 historical T-Post procedure claim was not preserved as a remainder';
    END IF;

    /* Container 36 is now countable by meaningful normal-panel lengths. */
    IF (SELECT count(*)
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=36
          AND m.material_name='T-Post'
          AND cem.active_flag
          AND cem.length_unit='FT'
          AND cem.length_value IN (5,6,7,8)) <> 4 THEN
        RAISE EXCEPTION 'Container 36 does not have exactly four active 5/6/7/8-ft T-Post stock rows';
    END IF;
    IF EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=36
          AND cem.active_flag
          AND m.material_name='T-Post'
          AND cem.length_value IS NULL
          AND cem.length_unit IS NULL
          AND coalesce(btrim(cem.size_text),'')=''
    ) THEN
        RAISE EXCEPTION 'Generic Container 36 T-Post row remains active after length split';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=118
          AND cem.active_flag
          AND m.material_name='T-Post'
          AND cem.size_text='special short stock'
    ) THEN
        RAISE EXCEPTION 'Separate shortened T-Post stock Container 118 is not configured';
    END IF;

    /* Explicit current-procedure physical exceptions. */
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=58 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.verification_state='NEEDS_REVIEW'
    ) THEN
        RAISE EXCEPTION 'Candyland Kit T-Post content/review row is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=105 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=2 AND cem.length_value=6 AND cem.length_unit='FT'
    ) THEN
        RAISE EXCEPTION 'Traditional Christmas Kit C105 2 x 6-ft T-Post row is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=145 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=3
    ) THEN
        RAISE EXCEPTION 'Church Kit C145 three-post inventory row is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=146 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=4 AND cem.length_value=5 AND cem.length_unit='FT'
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=146 AND cem.active_flag AND m.material_name='T-Post'
          AND cem.expected_quantity=9 AND cem.length_value=6 AND cem.length_unit='FT'
    ) THEN
        RAISE EXCEPTION 'Santa Station C146 5/6-ft T-Post contents are incomplete';
    END IF;

    /* Requirement proof cases added in 048. */
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=195 AND tm.active_flag AND m.material_name='T-Post'
          AND tm.quantity_required=20 AND tm.length_value=5 AND tm.length_unit='FT'
    ) THEN
        RAISE EXCEPTION 'HWY42 20 x 5-ft T-Post task requirement is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.setup_task_id=73 AND tm.active_flag AND m.material_name='T-Post'
          AND tm.quantity_required=2 AND tm.quantity_qualifier='MINIMUM'
          AND tm.verification_state='NEEDS_REVIEW'
    ) THEN
        RAISE EXCEPTION 'Church minimum two-post task requirement is missing';
    END IF;
    IF (SELECT count(*) FROM ref.setup_task_extra_material tm
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE tm.active_flag AND m.material_name='T-Post'
          AND tm.notes LIKE '[TPOST_FINAL_RECON_2026_09_14]%') <> 14 THEN
        RAISE EXCEPTION 'Expected 14 final T-Post requirement rows from migration 048';
    END IF;

    /* Reconstruction must never create physical inventory counts. */
    IF EXISTS (
        SELECT 1
        FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
           OR cem.notes LIKE 'Procedure-derived Kit preload v6.%'
           OR cem.notes LIKE 'Preloaded from #167 physical-source reconciliation.%'
           OR cem.notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%'
           OR cem.notes LIKE '[#167 SHARED SPACER STOCK]%'
           OR cem.notes LIKE '[#167 TPOST STOCK SPLIT]%'
           OR cem.notes LIKE '[#167 EXPLICIT TPOST CONTENT]%'
    ) THEN
        RAISE EXCEPTION 'One-time reconstruction unexpectedly created physical inventory history';
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
    (SELECT count(*) FROM ref.setup_container_extra_material_review
     WHERE unverified_items_text LIKE '%[#167 ASSIGNED KIT COVERAGE]%') AS assigned_kits_with_inventory_review,
    (SELECT count(*) FROM ref.setup_container_extra_material cem
     JOIN ref.setup_extra_material m USING (setup_extra_material_id)
     WHERE cem.active_flag AND m.material_name='T-Post') AS active_tpost_inventory_rows,
    (SELECT count(*) FROM ref.setup_task_extra_material tm
     JOIN ref.setup_extra_material m USING (setup_extra_material_id)
     WHERE tm.active_flag AND m.material_name='T-Post') AS active_tpost_requirement_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_session_rows;
