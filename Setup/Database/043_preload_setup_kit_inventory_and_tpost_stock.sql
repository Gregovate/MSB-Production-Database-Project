/* MSB Setup #167 — broaden normalized Kit preload, preserve procedure remainders,
   and establish separate T-Post stock Containers.
   REVIEW BEFORE PRODUCTION.

   Operating rule:
   - if a normalized procedure finding has one explicit current Kit source, or
     the procedure Stage has one current Kit candidate, load the normalized
     family into that Kit as UNVERIFIED;
   - T-Posts are NOT loaded as Kit contents. T-Post stock remains separate in
     the confirmed physical stock Containers;
   - anything that does not cleanly match the Extra Material catalog is retained
     as Kit Unverified Items / procedure remainder text for later cleanup;
   - no physical inventory count is created here.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Extra Material/container foundation is required first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='T-Post' AND active_flag) THEN
        RAISE EXCEPTION 'Normalized T-Post catalog family is required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=36)
       OR NOT EXISTS (SELECT 1 FROM ref.container WHERE container_id=118) THEN
        RAISE EXCEPTION 'Confirmed T-Post stock Containers 36 and 118 are required';
    END IF;
END
$preflight$;

/* Correct the earlier narrow preload: procedure evidence that C072 once carried
   extra T-Posts is preserved below as remainder evidence, but current T-Post
   stock is managed separately from Kit inventory. */
UPDATE ref.setup_container_extra_material cem
SET active_flag=false,
    notes=concat_ws(' ', cem.notes,
        '[#167 correction] T-Post stock is managed separately from Kit inventory.')
FROM ref.setup_extra_material m
WHERE cem.setup_extra_material_id=m.setup_extra_material_id
  AND cem.container_id=72
  AND m.material_name='T-Post'
  AND cem.active_flag
  AND cem.notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
  AND NOT EXISTS (
      SELECT 1 FROM ops.setup_extra_material_inventory_event e
      WHERE e.setup_container_extra_material_id=cem.setup_container_extra_material_id
  );

/* Separate T-Post stock Containers. These generic UNVERIFIED rows establish the
   material/source relationship. Physical counting should use verified
   length-specific rows when the stock is split by length. */
WITH tpost AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='T-Post' AND active_flag
),
seed(container_id, size_text, note) AS (
    VALUES
        (36, NULL::text,
         'Confirmed shared T-Post stock Container. Length mix/physical counts remain to be verified; create length-specific rows before detailed counting.'),
        (118, 'special short stock',
         'Confirmed separate stock of T-Posts too small for normal panels. Exact length/count remains to be verified.')
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT s.container_id, t.setup_extra_material_id, NULL, t.default_uom,
       s.size_text, 'UNVERIFIED',
       'Preloaded from #167 physical-source reconciliation. ' || s.note,
       true
FROM seed s CROSS JOIN tpost t
WHERE NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=s.container_id
      AND cem.setup_extra_material_id=t.setup_extra_material_id
      AND cem.quantity_uom=t.default_uom
      AND coalesce(lower(btrim(cem.size_text)), '')=coalesce(lower(btrim(s.size_text)), '')
      AND cem.length_value IS NULL
      AND cem.length_unit IS NULL
      AND cem.color IS NULL
      AND cem.active_flag
);

/* Normalized Kit contents inferred from explicit current-Container evidence or
   the sole current Kit candidate for the known procedure Stage. */
WITH seed(container_id, material_name, size_text, evidence_note) AS (
    VALUES
        (58, 'Cribbing / Shim', NULL, 'Procedure preload v6; Stage 17; sole current Stage Kit candidate; sources: 17-Candyland-CL Setup Procedure.pdf p1; 17-Candyland-CL Setup Procedure.pdf p5; 17-Candyland-CL Setup Procedure.pdf p6'),
        (58, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 17; explicit current Container evidence; sources: 17-Candyland-CL Setup Procedure.pdf p1'),
        (58, 'Eye Bolt', NULL, 'Procedure preload v6; Stage 17; sole current Stage Kit candidate; sources: 17-Candyland-CL Setup Procedure.pdf p5'),
        (58, 'Marking Paint', 'WHITE', 'Procedure preload v6; Stage 17; sole current Stage Kit candidate; sources: 17-Candyland-CL Setup Procedure.pdf p1'),
        (58, 'Plywood', 'painted black one side', 'Procedure preload v6; Stage 17; explicit current Container evidence; sources: 17-Candyland-CL Setup Procedure.pdf p1'),
        (58, 'Utility Flag', 'layout/tagging', 'Procedure preload v6; Stage 17; sole current Stage Kit candidate; sources: 17-Candyland-CL Setup Procedure.pdf p1'),
        (59, 'Arch Foot Pad', 'Front Arch marked foot pad', 'Procedure preload v6; Stage 01; sole current Stage Kit candidate; sources: 01-Front Arch Setup Procedure(1).pdf p1; 01-Front Entrance Panels Setup Procedure(1).pdf p1'),
        (59, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 01; sole current Stage Kit candidate; sources: 01-Front Arch Setup Procedure(1).pdf p1; 01-Front Entrance Panels Setup Procedure(1).pdf p1'),
        (59, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 01; sole current Stage Kit candidate; sources: 01-Front Arch Setup Procedure(1).pdf p1; 01-Front Entrance Panels Setup Procedure(1).pdf p1'),
        (59, 'Foam Noodle', 'cable safety protector', 'Procedure preload v6; Stage 01; sole current Stage Kit candidate; sources: 01-Front Arch Setup Procedure(1).pdf p1; 01-Front Entrance Panels Setup Procedure(1).pdf p1'),
        (60, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 08; sole current Stage Kit candidate; sources: 08-Elf Choir-EC(1).pdf p1'),
        (60, 'Post Base', 'unspecified', 'Procedure preload v6; Stage 08; sole current Stage Kit candidate; sources: 08-Elf Choir-EC(1).pdf p1'),
        (63, 'Eye Bolt', NULL, 'Procedure preload v6; Stage 02; sole current Stage Kit candidate; sources: 02-Fred''s Stars.pdf p1'),
        (63, 'Fishing Line', 'unspecified', 'Procedure preload v6; Stage 02; sole current Stage Kit candidate; sources: 02-Fred''s Stars.pdf p1'),
        (63, 'Standard Panel Spacer', NULL, 'Procedure preload v6; Stage 03; explicit current Container evidence; sources: 03-Welcome Area-WA Setup.pdf p1'),
        (65, 'Clamp', 'display/support-specific', 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p1'),
        (65, 'Cribbing / Shim', NULL, 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p2; 19-Santa''s Workshop-SW Setup Procedure.pdf p4'),
        (65, 'Electrical Tape', NULL, 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p1'),
        (65, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p2'),
        (65, 'Pipe Clamp', 'unspecified', 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p1'),
        (65, 'Wood Block / Lumber', '2x4', 'Procedure preload v6; Stage 19; sole current Stage Kit candidate; sources: 19-Santa''s Workshop-SW Setup Procedure.pdf p2; 19-Santa''s Workshop-SW Setup Procedure.pdf p4'),
        (66, 'Cribbing / Shim', NULL, 'Procedure preload v6; Stage 06; sole current Stage Kit candidate; sources: 06-Post Office-PO.pdf p1; 06-Post Office-PO.pdf p2; 06-Post Office-PO.pdf p8; 06-Post Office-PO.pdf p9'),
        (66, 'Electrical Tape', NULL, 'Procedure preload v6; Stage 06; sole current Stage Kit candidate; sources: 06-Post Office-PO.pdf p12'),
        (66, 'Eye Bolt', NULL, 'Procedure preload v6; Stage 06; sole current Stage Kit candidate; sources: 06-Post Office-PO.pdf p2; 06-Post Office-PO.pdf p3; 06-Post Office-PO.pdf p7; 06-Post Office-PO.pdf p8'),
        (66, 'Tripple Tap', NULL, 'Procedure preload v6; Stage 06; sole current Stage Kit candidate; sources: 06-Post Office-PO.pdf p1'),
        (66, 'Wood Block / Lumber', '2x4', 'Procedure preload v6; Stage 06; sole current Stage Kit candidate; sources: 06-Post Office-PO.pdf p1; 06-Post Office-PO.pdf p8; 06-Post Office-PO.pdf p9'),
        (68, 'Arch Bracket', 'Food Collection support', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p2'),
        (68, 'Extension Cord', '100 ft', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p1'),
        (68, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p1; 04-Food Collection-FC.pdf p2'),
        (68, 'Ratchet Strap', 'unspecified', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p6'),
        (68, 'Tripple Tap', NULL, 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p2; 04-Food Collection-FC.pdf p8'),
        (68, 'Wedge', 'display support', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p6'),
        (68, 'Wood Blocking / Footpad', '2x6', 'Procedure preload v6; Stage 04; sole current Stage Kit candidate; sources: 04-Food Collection-FC.pdf p2'),
        (70, 'Duct Tape', 'white/yellow temporary layout', 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p12'),
        (70, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p1'),
        (70, 'Marking Paint', 'WHITE', 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p3; 11 -Sledders-SL Setup Procedure.pdf p4'),
        (70, 'Rubber / Floor Mat', 'cord protection / standing', 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p2'),
        (70, 'Tripple Tap', NULL, 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p2'),
        (70, 'Velcro Cord Fastener', NULL, 'Procedure preload v6; Stage 11; sole current Stage Kit candidate; sources: 11 -Sledders-SL Setup Procedure.pdf p2'),
        (71, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 00; sole current Stage Kit candidate; sources: 00-HWY 42 Signs(1).pdf p2'),
        (71, 'Tripple Tap', NULL, 'Procedure preload v6; Stage 00; sole current Stage Kit candidate; sources: 00-HWY 42 Signs(1).pdf p1'),
        (72, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 02; sole current Stage Kit candidate; sources: 02-Front Entrance Signs & Claymations & Volunteer Path.pdf p1; 02-Front Entrance Signs & Claymations & Volunteer Path.pdf p6'),
        (72, 'Cribbing / Shim', NULL, 'Procedure preload v6; Stage 02; sole current Stage Kit candidate; sources: 02-Front Entrance Signs & Claymations & Volunteer Path.pdf p6'),
        (72, 'D-Ring', NULL, 'Procedure preload v6; Stage 02; sole current Stage Kit candidate; sources: 02-Front Entrance Signs & Claymations & Volunteer Path.pdf p4'),
        (72, 'Spare / Replacement Bulb', 'unspecified', 'Procedure preload v6; Stage 02; explicit current Container evidence; sources: 02-Front Entrance Signs & Claymations & Volunteer Path.pdf p7'),
        (76, 'Arch Foot', NULL, 'Procedure preload v6; Stage 24; explicit current Container evidence; sources: 24-Racing Arches-RA Setup Procedure.pdf p1; 24-Racing Arches-RA Setup Procedure.pdf p2'),
        (76, 'D-Ring', NULL, 'Procedure preload v6; Stage 24; sole current Stage Kit candidate; sources: 24-Racing Arches-RA Setup Procedure.pdf p1; 24-Racing Arches-RA Setup Procedure.pdf p2'),
        (76, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 24; sole current Stage Kit candidate; sources: 24-Racing Arches-RA Setup Procedure.pdf p1; 24-Racing Arches-RA Setup Procedure.pdf p2'),
        (76, 'Marking Paint', 'WHITE', 'Procedure preload v6; Stage 24; sole current Stage Kit candidate; sources: 24-Racing Arches-RA Setup Procedure.pdf p1'),
        (76, 'Rubber / Floor Mat', 'cord protection / standing', 'Procedure preload v6; Stage 24; explicit current Container evidence; sources: 24-Racing Arches-RA Setup Procedure.pdf p1; 24-Racing Arches-RA Setup Procedure.pdf p2'),
        (76, 'WD-40', 'lubricant', 'Procedure preload v6; Stage 24; sole current Stage Kit candidate; sources: 24-Racing Arches-RA Setup Procedure.pdf p3'),
        (76, 'Wood Block', '4x4', 'Procedure preload v6; Stage 24; sole current Stage Kit candidate; sources: 24-Racing Arches-RA Setup Procedure.pdf p1; 24-Racing Arches-RA Setup Procedure.pdf p2'),
        (77, 'T-Post', NULL, 'Procedure preload v6; Stage 23; sole current Stage Kit candidate; sources: 23-Traditional Christmas-TC Setup Procedure (1).pdf p1'),
        (78, 'Eye Bolt', NULL, 'Procedure preload v6; Stage 10; sole current Stage Kit candidate; sources: 10-Stars-ST Setup Procedure.pdf p1; 10-Stars-ST Setup Procedure.pdf p3'),
        (78, 'Rubber / Floor Mat', 'cord protection / standing', 'Procedure preload v6; Stage 10; explicit current Container evidence; sources: 10-Stars-ST Setup Procedure.pdf p1'),
        (79, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p1'),
        (79, 'Clamp', 'display/support-specific', 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p3'),
        (79, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p1'),
        (79, 'Marking Paint', 'WHITE', 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p1'),
        (79, 'Rubber / Floor Mat', 'cord protection / standing', 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p2'),
        (79, 'Standard Panel Spacer', NULL, 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p1'),
        (79, 'Wood Block', '4x4', 'Procedure preload v6; Stage 13; sole current Stage Kit candidate; sources: 13-Winter Wonderland-WW Setup Procedure.pdf p2'),
        (103, 'Cardboard Separator', 'pallet separator', 'Procedure preload v6; Stage 18; sole current Stage Kit candidate; sources: 18-Dancing Forest-DF Setup Procedure.pdf p1; 18-Dancing Forest-DF Setup Procedure.pdf p2'),
        (103, 'Electrical Tape', NULL, 'Procedure preload v6; Stage 18; sole current Stage Kit candidate; sources: 18-Dancing Forest-DF Setup Procedure.pdf p1'),
        (103, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 18; sole current Stage Kit candidate; sources: 18-Dancing Forest-DF Setup Procedure.pdf p1'),
        (103, 'Utility Flag', 'layout/tagging', 'Procedure preload v6; Stage 18; sole current Stage Kit candidate; sources: 18-Dancing Forest-DF Setup Procedure.pdf p1; 18-Dancing Forest-DF Setup Procedure.pdf p2'),
        (104, 'Ball Bungee', NULL, 'Procedure preload v6; Stage 09; sole current Stage Kit candidate; sources: 09-Global Warming-GW.pdf p2'),
        (104, 'D-Ring', NULL, 'Procedure preload v6; Stage 09; sole current Stage Kit candidate; sources: 09-Global Warming-GW.pdf p5'),
        (104, 'Extension Cord', '12 AWG', 'Procedure preload v6; Stage 09; sole current Stage Kit candidate; sources: 09-Global Warming-GW.pdf p2'),
        (104, 'Tripple Tap', NULL, 'Procedure preload v6; Stage 09; sole current Stage Kit candidate; sources: 09-Global Warming-GW.pdf p5'),
        (145, 'Cribbing / Shim', NULL, 'Procedure preload v6; Stage 15; sole current Stage Kit candidate; sources: 15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1'),
        (145, 'Plywood', '3/4 in x 4 ft x 8 ft', 'Procedure preload v6; Stage 15; sole current Stage Kit candidate; sources: 15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1'),
        (145, 'Ratchet Strap', 'unspecified', 'Procedure preload v6; Stage 15; sole current Stage Kit candidate; sources: 15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1'),
        (145, 'Turnbuckle', 'current hook-to-loop variant', 'Procedure preload v6; Stage 15; sole current Stage Kit candidate; sources: 15-ChurchRGB Tree & Candy Canes Setup Procedure.pdf p1')
),
resolved AS (
    SELECT s.container_id, m.setup_extra_material_id, m.default_uom,
           s.size_text, s.evidence_note
    FROM seed s
    JOIN ref.container c ON c.container_id=s.container_id
    JOIN ref.setup_extra_material m
      ON m.material_name=s.material_name
     AND m.active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT r.container_id, r.setup_extra_material_id, NULL, r.default_uom,
       r.size_text, 'UNVERIFIED',
       'Procedure-derived Kit preload v6. ' || r.evidence_note,
       true
FROM resolved r
WHERE r.setup_extra_material_id <> (
    SELECT setup_extra_material_id FROM ref.setup_extra_material WHERE material_name='T-Post'
)
  AND NOT EXISTS (
    SELECT 1
    FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=r.container_id
      AND cem.setup_extra_material_id=r.setup_extra_material_id
      AND cem.quantity_uom=r.default_uom
      AND coalesce(lower(btrim(cem.size_text)), '')=coalesce(lower(btrim(r.size_text)), '')
      AND cem.length_value IS NULL
      AND cem.length_unit IS NULL
      AND cem.color IS NULL
      AND cem.active_flag
);

/* Procedure remainders: valuable Kit information that is not a clean Extra
   Material row yet (held variants, Kit-specific pieces, other-system items,
   vague legacy phrases, and T-Post references now handled by separate stock).
   Remainders are intentionally concise; the full written procedures remain the
   fall-back authority during cleanup. */
WITH seed(container_id, remainder_text) AS (
    VALUES
        (58, '[#167 PROCEDURE REMAINDERS v6]\n- Extension Cord variants need verification.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (59, '[#167 PROCEDURE REMAINDERS v6]\n- Zip Tie type/size needs verification.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.'),
        (60, '[#167 PROCEDURE REMAINDERS v6]\n- Custom/display-specific spacers remain Kit evidence, not a general Extra Material row.\n- Extension Cord variants need verification.\n- Rebar Stake variant needs verification.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (63, '[#167 PROCEDURE REMAINDERS v6]\n- Extension Cord variant needs verification.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (65, '[#167 PROCEDURE REMAINDERS v6]\n- Zip Tie variants need verification.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Carabiner evidence remains outside the current normalized catalog.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (66, '[#167 PROCEDURE REMAINDERS v6]\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Zip Tie variants need verification.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Carabiner evidence remains outside the current normalized catalog.'),
        (68, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.\n- PVC distance pipe remains unresolved procedure evidence only.\n- Rebar Stake variant needs verification.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Zip Tie variants need verification.'),
        (70, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Marking Paint evidence needs color/use verification.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Custom/display-specific spacers remain Kit evidence, not a general Extra Material row.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (71, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.\n- Custom/display-specific spacers remain Kit evidence, not a general Extra Material row.'),
        (72, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Marking Paint evidence needs color/use verification.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Zip Tie variant needs verification.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Procedure says C072 carried extra T-Posts; preserve that history here while current T-Post stock is managed separately.'),
        (76, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Racing Arch foot/leveling spacer remains Kit-specific evidence.'),
        (77, '[#167 PROCEDURE REMAINDERS v6]\n- Rebar Stake variant needs verification.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (78, '[#167 PROCEDURE REMAINDERS v6]\n- Bull Line is procedure evidence owned by the harness/wiring boundary.\n- Generic Extension Cord evidence still needs variant cleanup.'),
        (79, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.\n- Custom/display-specific spacers remain Kit evidence, not a general Extra Material row.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (103, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.\n- Zip Tie variant needs verification.\n- Carabiner evidence remains outside the current normalized catalog.\n- Bow/Bull Line is procedure evidence owned by the harness/wiring boundary.'),
        (104, '[#167 PROCEDURE REMAINDERS v6]\n- Rebar Stake variant needs verification.\n- Generic Marking Paint evidence needs color/use verification.\n- Custom/display-specific spacer evidence remains Kit-specific.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.'),
        (105, '[#167 PROCEDURE REMAINDERS v6]\n- Generic Extension Cord evidence still needs variant cleanup.'),
        (145, '[#167 PROCEDURE REMAINDERS v6]\n- Zip Tie variant needs verification.\n- Generic Extension Cord evidence still needs variant cleanup.\n- Procedure T-Post references are preserved, but current T-Post stock is managed separately.')
)
INSERT INTO ref.setup_container_extra_material_review(
    container_id, unverified_items_text
)
SELECT s.container_id, replace(s.remainder_text, '\\n', E'\n')
FROM seed s
ON CONFLICT (container_id) DO UPDATE
SET unverified_items_text =
    CASE
      WHEN position('[#167 PROCEDURE REMAINDERS v6]' in
                    ref.setup_container_extra_material_review.unverified_items_text) > 0
      THEN ref.setup_container_extra_material_review.unverified_items_text
      ELSE ref.setup_container_extra_material_review.unverified_items_text
           || E'\n\n' || EXCLUDED.unverified_items_text
    END;

/* Acceptance proofs: useful normalized Kit inventory exists, T-Post stock is
   separate, and no preload manufactures physical inventory. */
DO $proof$
DECLARE
    v_loaded integer;
BEGIN
    SELECT count(*) INTO v_loaded
    FROM ref.setup_container_extra_material
    WHERE active_flag
      AND notes LIKE 'Procedure-derived Kit preload v6.%';

    IF v_loaded < 60 THEN
        RAISE EXCEPTION 'Expected at least 60 normalized Kit-content preload rows, got %', v_loaded;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.active_flag
          AND m.material_name='T-Post'
          AND cem.container_id NOT IN (36,118)
          AND cem.notes LIKE 'Procedure-derived Kit preload v6.%'
    ) THEN
        RAISE EXCEPTION 'Procedure preload incorrectly placed T-Post stock inside a Kit';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=36 AND cem.active_flag AND m.material_name='T-Post'
    ) OR NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=118 AND cem.active_flag AND m.material_name='T-Post'
    ) THEN
        RAISE EXCEPTION 'Separate T-Post stock source rows are missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE 'Procedure-derived Kit preload v6.%'
           OR cem.notes LIKE 'Preloaded from #167 physical-source reconciliation.%'
    ) THEN
        RAISE EXCEPTION 'Procedure/source preload unexpectedly created physical inventory history';
    END IF;
END
$proof$;

COMMIT;

SELECT
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag AND notes LIKE 'Procedure-derived Kit preload v6.%')
       AS procedure_loaded_kit_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material_review
     WHERE unverified_items_text LIKE '%[#167 PROCEDURE REMAINDERS v6]%')
       AS kits_with_remainders,
    (SELECT count(*)
     FROM ref.setup_container_extra_material cem
     JOIN ref.setup_extra_material m USING (setup_extra_material_id)
     WHERE cem.active_flag AND m.material_name='T-Post'
       AND cem.container_id IN (36,118))
       AS separate_tpost_stock_rows;
