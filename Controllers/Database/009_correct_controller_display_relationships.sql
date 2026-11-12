/* ============================================================================
Controller Inventory permanent relationship corrections
Issue: #110

Purpose:
  Correct reviewed physical Controller-to-Display relationships after the
  initial 177-controller bootstrap promotion.

Authoritative operator corrections:
  - Church RGB Candy Canes are two Pixie4D controllers, each serving four
    physical Displays, while intentionally sharing Aux-N / UID 21-24.
  - Candyland RGB Candy Canes are three Pixie4D controllers, each serving four
    physical Displays, while intentionally sharing Aux-A / UID 21-24.
  - Glistening Grove duplicate physical copies retain their own Display and
    Controller identity but use the -01 Display as the LOR wiring source.
  - Controller 1176 is the separate 2026 FE Open/Close Matrix. It must not be
    attached to legacy Display 38 (FE-OpenCloseSign). It remains unassigned
    until the Matrix is added through the normal Preview/LOR workflow.

This script modifies only ref.controller_display. It does not alter Controller
identity, firmware, LOR topology, ref.display, or bootstrap stage evidence.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_missing integer;
BEGIN
    SELECT count(*) INTO v_missing
    FROM (VALUES
        (1096),(1097),(1098),(1099),(1100),(1101),(1102),(1103),
        (1104),(1105),(1106),(1107),(1108),(1109),(1110),(1111),
        (1134),(1135),(1136),(1141),(1142),
        (1154),(1155),(1156),(1157),(1158),(1159),(1160),(1161),(1176)
    ) AS x(controller_id)
    LEFT JOIN ref.controller AS c USING (controller_id)
    WHERE c.controller_id IS NULL;

    IF v_missing <> 0 THEN
        RAISE EXCEPTION 'Controller relationship correction: % required controller IDs are missing', v_missing;
    END IF;

    SELECT count(*) INTO v_missing
    FROM (VALUES
        (38,'FE-OpenCloseSign'),
        (309,'CH-RGBCandyCane-01'),(326,'CH-RGBCandyCane-02'),
        (331,'CH-RGBCandyCane-03'),(322,'CH-RGBCandyCane-04'),
        (328,'CH-RGBCandyCane-05'),(333,'CH-RGBCandyCane-06'),
        (325,'CH-RGBCandyCane-07'),(320,'CH-RGBCandyCane-08'),
        (116,'CL-RGBCandyCane-01'),(73,'CL-RGBCandyCane-02'),
        (92,'CL-RGBCandyCane-03'),(84,'CL-RGBCandyCane-04'),
        (80,'CL-RGBCandyCane-05'),(98,'CL-RGBCandyCane-06'),
        (78,'CL-RGBCandyCane-07'),(76,'CL-RGBCandyCane-08'),
        (106,'CL-RGBCandyCane-09'),(94,'CL-RGBCandyCane-10'),
        (89,'CL-RGBCandyCane-11'),(105,'CL-RGBCandyCane-12'),
        (630,'GG-Elden-20-01'),(620,'GG-Elden-20-02'),
        (640,'GG-Elden-20-03'),(627,'GG-Elden-20-04'),
        (632,'GG-Felix-22-01'),(636,'GG-Felix-22-02'),
        (623,'GG-Felix-22-03'),(633,'GG-Felix-22-04'),
        (631,'GG-Ralphie-24-01'),(626,'GG-Ralphie-24-02'),
        (625,'GG-Ralphie-24-03'),(639,'GG-Ralphie-24-04'),
        (628,'GG-Zuzu-26-01'),(638,'GG-Zuzu-26-02'),
        (634,'GG-Zuzu-26-03'),(643,'GG-Zuzu-26-04'),
        (629,'GG-EldenV2-30-01'),(644,'GG-EldenV2-30-02'),
        (624,'GG-FelixV2-32-01'),(635,'GG-FelixV2-32-02'),
        (637,'GG-RalphieV2-34-01'),(641,'GG-RalphieV2-34-02'),
        (642,'GG-ZuzuV2-36-01'),(645,'GG-ZuzuV2-36-02')
    ) AS x(display_id, display_name)
    LEFT JOIN ref.display AS d
      ON d.display_id = x.display_id
     AND d.display_name = x.display_name
    WHERE d.display_id IS NULL;

    IF v_missing <> 0 THEN
        RAISE EXCEPTION 'Controller relationship correction: % required Display identities/names do not match', v_missing;
    END IF;
END
$preflight$;

-- 1. Unassign the 2026 Matrix controller from the legacy 2018 LED sign.
DELETE FROM ref.controller_display
WHERE controller_id = 1176
  AND display_id = 38;

-- 2. Church RGB Candy Canes: two Pixie4D controllers, four Displays each.
DELETE FROM ref.controller_display
WHERE controller_id IN (1141,1142);

INSERT INTO ref.controller_display (controller_id, display_id)
VALUES
    (1141,309),(1141,326),(1141,331),(1141,322),
    (1142,328),(1142,333),(1142,325),(1142,320);

-- 3. Candyland RGB Candy Canes: three Pixie4D controllers, four Displays each.
DELETE FROM ref.controller_display
WHERE controller_id IN (1134,1135,1136);

INSERT INTO ref.controller_display (controller_id, display_id)
VALUES
    (1134,116),(1134,73),(1134,92),(1134,84),
    (1135,80),(1135,98),(1135,78),(1135,76),
    (1136,106),(1136,94),(1136,89),(1136,105);

-- 4. Ensure the primary GG copies use their own LOR wiring.
UPDATE ref.controller_display
SET wiring_source_display_id = NULL
WHERE controller_id IN (1096,1100,1104,1108,1154,1156,1158,1160);

-- 5. GG duplicate copies use the corresponding -01 Display as wiring source.
UPDATE ref.controller_display
SET wiring_source_display_id = CASE controller_id
    WHEN 1097 THEN 630
    WHEN 1098 THEN 630
    WHEN 1099 THEN 630
    WHEN 1101 THEN 632
    WHEN 1102 THEN 632
    WHEN 1103 THEN 632
    WHEN 1105 THEN 631
    WHEN 1106 THEN 631
    WHEN 1107 THEN 631
    WHEN 1109 THEN 628
    WHEN 1110 THEN 628
    WHEN 1111 THEN 628
    WHEN 1155 THEN 629
    WHEN 1157 THEN 624
    WHEN 1159 THEN 637
    WHEN 1161 THEN 642
END
WHERE controller_id IN (
    1097,1098,1099,
    1101,1102,1103,
    1105,1106,1107,
    1109,1110,1111,
    1155,1157,1159,1161
);

DO $assertions$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ref.controller_display
    WHERE controller_id = 1176;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Controller 1176 must remain unassigned until the Matrix exists in the Preview/LOR workflow; found % relationships', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.controller_display
    WHERE controller_id = 1141;
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'Controller 1141 expected 4 Church Candy Cane Displays; found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.controller_display
    WHERE controller_id = 1142;
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'Controller 1142 expected 4 Church Candy Cane Displays; found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.controller_display
    WHERE controller_id IN (1134,1135,1136);
    IF v_count <> 12 THEN
        RAISE EXCEPTION 'Candyland Pixie4D controllers expected 12 Display relationships; found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.controller_display
    WHERE controller_id IN (
        1097,1098,1099,
        1101,1102,1103,
        1105,1106,1107,
        1109,1110,1111,
        1155,1157,1159,1161
    )
      AND wiring_source_display_id IS NOT NULL;
    IF v_count <> 16 THEN
        RAISE EXCEPTION 'Expected 16 GG duplicate-copy wiring-source relationships; found %', v_count;
    END IF;
END
$assertions$;

COMMIT;

SELECT
    cd.controller_id,
    d.display_name,
    cd.wiring_source_display_id,
    ws.display_name AS wiring_source_display
FROM ref.controller_display AS cd
JOIN ref.display AS d ON d.display_id = cd.display_id
LEFT JOIN ref.display AS ws ON ws.display_id = cd.wiring_source_display_id
WHERE cd.controller_id IN (
    1096,1097,1098,1099,1100,1101,1102,1103,
    1104,1105,1106,1107,1108,1109,1110,1111,
    1134,1135,1136,1141,1142,
    1154,1155,1156,1157,1158,1159,1160,1161,1176
)
ORDER BY cd.controller_id, d.display_name;
