/* MSB Setup #167 — preload normalized known Extra Material evidence.
   REVIEW BEFORE PRODUCTION.

   Boundary:
   - only normalized rows with a current reusable-task or current Container identity
     are structured here;
   - every row remains UNVERIFIED;
   - ambiguous/unmatched staging evidence remains in the #167 verification queues
     and is not guessed into a task, Container, quantity, or specification;
   - this migration does not create a 2026 Setup Session.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Migrations 032-037 Extra Material foundation are required first';
    END IF;

    IF (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) <> 43 THEN
        RAISE EXCEPTION 'Expected normalized 43-family Extra Material catalog before preload';
    END IF;
END
$preflight$;

/*
Task requirements below are the 23 unique task/material/spec groups from the
normalization workbook whose Requirement_Preload_State was PRELOAD_CANDIDATE
with one current reusable-task mapping. Quantities are populated only where the
procedure text gives an explicit count. Missing counts stay NULL, not zero.
*/
WITH seed(
    setup_task_id, material_name, quantity_required, quantity_uom, size_text, evidence_note
) AS (
    VALUES
        (47, 'Fishing Line', NULL, 'FT', NULL, '02-Fred''s Stars.pdf p1: fishline / install fishing wire with carabiners to keep stars from twisting.'),
        (47, 'Eye Bolt', NULL, 'EA', NULL, '02-Fred''s Stars.pdf p1: legacy eye-hook evidence; normalized to Eye Bolt.'),
        (11, 'Clamp', NULL, 'EA', NULL, '07 - Mount Crumpit .pdf pp1-4,7: display/support clamps used on frame/tube connections.'),
        (11, 'Pipe Clamp', NULL, 'EA', NULL, '07 - Mount Crumpit .pdf p3: back supports use pipe clamps.'),
        (76, 'Cribbing / Shim', NULL, 'EA', NULL, '07a - Who Forest Trees Setup Instructions.pdf pp1,3-4: wood shims/cribbing used as necessary.'),
        (76, 'Wood Block / Lumber', NULL, 'EA', '2x4', '07a - Who Forest Trees Setup Instructions.pdf p1: miscellaneous 2x4 support material.'),
        (76, 'Wood Block', NULL, 'EA', '4x4', '07a - Who Forest Trees Setup Instructions.pdf p2: 4x4 post/support evidence.'),
        (76, 'Clamp', NULL, 'EA', NULL, '07a - Who Forest Trees Setup Instructions.pdf pp3-4: crossbar/riser clamp evidence.'),
        (76, 'Chain', NULL, 'EA', NULL, '07a - Who Forest Trees Setup Instructions.pdf p4: normalized chain/security-restraint candidate; operator verification required.'),
        (73, 'Turnbuckle', NULL, 'EA', 'current hook-to-loop variant', '15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1: current turnbuckle type evidence.'),
        (73, 'Ratchet Strap', 3, 'EA', NULL, '15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1: three ratchet straps installed from bottom ring to pole base.'),
        (73, 'Cribbing / Shim', NULL, 'EA', NULL, '15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1: cribbing used to level tree stand.'),
        (73, 'Plywood', 2, 'SHEET', '3/4 in x 4 ft x 8 ft', '15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1: two 3/4 in x 4 ft x 8 ft plywood sheets.'),
        (36, 'Rubber / Floor Mat', 3, 'EA', NULL, '26-1-Magic Igloo Frame Set Up Procedure.pdf pp1,7: three floor mats associated with Magic Igloo setup.'),
        (36, 'D-Ring', NULL, 'EA', '5/16 in', '26-1-Magic Igloo Frame Set Up Procedure.pdf p3: 5/16 in D-Rings on verticals.'),
        (36, 'D-Ring', NULL, 'EA', '1/4 in', '26-1-Magic Igloo Frame Set Up Procedure.pdf p3: 1/4 in D-Rings on horizontals.'),
        (36, 'Ratchet Strap', NULL, 'EA', NULL, '26-1-Magic Igloo Frame Set Up Procedure.pdf p4: orange ratchet strap on each footing; exact count remains to verify.'),
        (37, 'Rubber / Floor Mat', 3, 'EA', NULL, '26-2-Magic Igloo Skin Installation.pdf pp1,4: three floor mats.'),
        (38, 'Rubber / Floor Mat', 3, 'EA', NULL, '26-3-Magic Igloo Lights and Camera Installation.pdf pp1,4: three floor mats.'),
        (1, 'Extension Cord', NULL, 'EA', '12 AWG', '01-Front Arch Setup Procedure.pdf p1: Entrance Arch Kit includes 12 AWG power cords.'),
        (1, 'Foam Noodle', 4, 'EA', NULL, '01-Front Arch Setup Procedure.pdf p1: four foam noodles protect cables securing front-arch harness.'),
        (205, 'Arch Foot Pad', 6, 'EA', NULL, '01-Front Arch Setup Procedure.pdf p1: six marked arch foot pads, three north and three south.'),
        (127, 'Cribbing / Shim', NULL, 'EA', NULL, '13-Polar Express Setup Procedure.pdf p1: cribbing used to level engine pallet; expected with display container.')
),
resolved AS (
    SELECT
        s.setup_task_id,
        m.setup_extra_material_id,
        s.quantity_required,
        s.quantity_uom,
        s.size_text,
        s.evidence_note
    FROM seed s
    JOIN ref.setup_task t
      ON t.setup_task_id = s.setup_task_id
     AND t.active_flag
    JOIN ref.setup_extra_material m
      ON m.material_name = s.material_name
     AND m.active_flag
)
INSERT INTO ref.setup_task_extra_material(
    setup_task_id,
    setup_extra_material_id,
    quantity_required,
    quantity_uom,
    size_text,
    quantity_qualifier,
    verification_state,
    notes,
    active_flag
)
SELECT
    r.setup_task_id,
    r.setup_extra_material_id,
    r.quantity_required,
    r.quantity_uom,
    r.size_text,
    'EXACT',
    'UNVERIFIED',
    'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx. ' || r.evidence_note,
    true
FROM resolved r
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.setup_task_extra_material tm
    WHERE tm.setup_task_id = r.setup_task_id
      AND tm.setup_extra_material_id = r.setup_extra_material_id
      AND tm.quantity_uom = r.quantity_uom
      AND coalesce(lower(btrim(tm.size_text)), '') =
          coalesce(lower(btrim(r.size_text)), '')
      AND tm.length_value IS NULL
      AND tm.length_unit IS NULL
      AND tm.color IS NULL
      AND tm.active_flag
);

/*
Container expected contents below are only explicit current-Container evidence
or a confirmed current Kit assignment with explicit legacy contents. Expected
quantity is populated only where the source states a count. These are expected
contents, not physical counts; no inventory ledger event is created here.
*/
WITH seed(
    container_id, material_name, expected_quantity, quantity_uom, size_text, evidence_note
) AS (
    VALUES
        (72, 'T-Post', 50, 'EA', NULL, 'Volunteer Path procedure: Container C072 explicitly contains 50 extra T-Posts; dimensions remain unverified.'),
        (72, 'Spare / Replacement Bulb', NULL, 'EA', NULL, 'Volunteer Path procedure: Container C072 explicitly contains one tub of extra bulbs; bulb count remains unverified.'),
        (78, 'Rubber / Floor Mat', 1, 'EA', NULL, 'Stars procedure: Container C078 explicitly contains 1 rubber mat.'),
        (58, 'Extension Cord', 2, 'EA', '12 AWG', 'Candyland procedure: Container C058 explicitly lists two 12 AWG yellow power cords; other cord variants remain for verification.'),
        (58, 'Plywood', NULL, 'EA', 'painted black one side', 'Candyland procedure: Container C058 explicitly contains plywood painted black on one side; quantity remains unverified.'),
        (76, 'Arch Foot', 32, 'EA', NULL, 'Racing Arches procedure: Container C076 explicitly contains 32 Arch Base Posts; normalized to Arch Foot.'),
        (76, 'Rubber / Floor Mat', 3, 'EA', NULL, 'Racing Arches procedure: Container C076 explicitly contains 3 rubber mats.'),
        (60, 'Ball Bungee', NULL, 'EA', NULL, 'Elf Choir procedure: Elf Choir Kit contains ball bungees; quantity/size remain unverified.'),
        (60, 'Post Base', 8, 'EA', NULL, 'Elf Choir procedure: Elf Choir Kit contains 8 bases for posts.'),
        (35, 'Rubber / Floor Mat', 3, 'EA', NULL, 'Magic Igloo procedures: three floor mats are stored on/with the Magic Igloo Kit.')
),
resolved AS (
    SELECT
        s.container_id,
        m.setup_extra_material_id,
        s.expected_quantity,
        s.quantity_uom,
        s.size_text,
        s.evidence_note
    FROM seed s
    JOIN ref.container c
      ON c.container_id = s.container_id
    JOIN ref.setup_extra_material m
      ON m.material_name = s.material_name
     AND m.active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id,
    setup_extra_material_id,
    expected_quantity,
    quantity_uom,
    size_text,
    verification_state,
    notes,
    active_flag
)
SELECT
    r.container_id,
    r.setup_extra_material_id,
    r.expected_quantity,
    r.quantity_uom,
    r.size_text,
    'UNVERIFIED',
    'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx. ' || r.evidence_note,
    true
FROM resolved r
WHERE NOT EXISTS (
    SELECT 1
    FROM ref.setup_container_extra_material cem
    WHERE cem.container_id = r.container_id
      AND cem.setup_extra_material_id = r.setup_extra_material_id
      AND cem.quantity_uom = r.quantity_uom
      AND coalesce(lower(btrim(cem.size_text)), '') =
          coalesce(lower(btrim(r.size_text)), '')
      AND cem.length_value IS NULL
      AND cem.length_unit IS NULL
      AND cem.color IS NULL
      AND cem.active_flag
);

DO $proof$
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
        RAISE EXCEPTION 'Normalized preload unexpectedly marked extracted evidence as accepted';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION '#167 normalized preload unexpectedly created a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

SELECT
    (SELECT count(*)
     FROM ref.setup_task_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%')
        AS normalized_task_preload_rows,
    (SELECT count(*)
     FROM ref.setup_container_extra_material
     WHERE active_flag
       AND notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%')
        AS normalized_container_preload_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year = 2026)
        AS setup_2026_session_rows;
