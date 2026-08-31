/* ============================================================================
Controller Inventory model/firmware normalization — STAGE ONLY
Issue: #110

Purpose:
  Preserve workbook model/firmware evidence exactly while adding a separate
  manufacturer-reference layer for canonical model naming and firmware review.

This script:
  - writes only stage.* objects;
  - creates no ref.controller* objects;
  - does not change stage.controller_bootstrap source evidence;
  - allocates no permanent controller IDs.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS stage.controller_model_reference (
    source_model_evidence text PRIMARY KEY,
    manufacturer text NOT NULL,
    canonical_model_code text NOT NULL,
    canonical_model_name text NOT NULL,
    firmware_family text,
    reference_current_firmware text,
    reference_url text NOT NULL,
    normalization_state text NOT NULL,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,
    CONSTRAINT ck_controller_model_reference_state CHECK (
        normalization_state IN ('REFERENCE_MATCHED','FAMILY_ONLY','VENDOR_REFERENCE')
    )
);

DROP TRIGGER IF EXISTS trg_controller_model_reference_actor_insert
    ON stage.controller_model_reference;
CREATE TRIGGER trg_controller_model_reference_actor_insert
BEFORE INSERT ON stage.controller_model_reference
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_controller_model_reference_actor_update
    ON stage.controller_model_reference;
CREATE TRIGGER trg_controller_model_reference_actor_update
BEFORE UPDATE ON stage.controller_model_reference
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

INSERT INTO stage.controller_model_reference (
    source_model_evidence, manufacturer, canonical_model_code,
    canonical_model_name, firmware_family, reference_current_firmware,
    reference_url, normalization_state, notes
)
VALUES
    ('32LD-G3', 'Light-O-Rama', 'CTB32LDg3',
     'CTB32LDg3 Generation 3 commercial controller board',
     'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Workbook shorthand normalized to manufacturer board designation.'),

    ('AlphaPix Flex 48', 'HolidayCoro', 'AlphaPix Evolution Flex 48',
     'AlphaPix Evolution Flex 48-Port Pixel Controller',
     'AlphaPix Evolution', NULL,
     'https://www.holidaycoro.com/alphapix',
     'VENDOR_REFERENCE',
     'Two staged rows have no recorded firmware; do not infer a version.'),

    ('CCB100', 'Light-O-Rama', 'CCB100',
     'CCB100 Cosmic Color Bulbs/Pixels Controller',
     'CCB', '1.21',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Original RGB smart-pixel controller, two ports.'),

    ('CF50D', 'Light-O-Rama', 'CF50D',
     'CF50D Cosmic Color Flood 50 Watt RGB/UV Controller',
     'CF50D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL),

    ('CMB24D', 'Light-O-Rama', 'CMB24D',
     'CMB24D 24-Channel RGB Dumb Pixel Controller Board',
     'CMB24D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL),

    ('CTB04-G3', 'Light-O-Rama', 'CTB04Dg3',
     'CTB04Dg3 Generation 3 Four-Channel Controller',
     'CTB04Dg3', '1.01',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Workbook shorthand normalized to manufacturer designation.'),

    ('CTB32LG3', 'Light-O-Rama', 'CTB32/LOR160x-G3',
     'CTB32 / LOR160x Generation 3 Controller Family',
     'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'FAMILY_ONLY',
     'CTB32LG3 is the firmware family; exact physical product may be CTB32LDg3 board or LOR160x enclosure.'),

    ('Pixcon16', 'Light-O-Rama', 'PixCon16-MKII',
     'PixCon16 MKII 16-Port Smart Pixel Controller Board',
     'PixCon16 MKII', '2.0.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'All seven staged rows report firmware 2.0.13; LOR identifies 2.x firmware as MKII.'),

    ('Pixie16', 'Light-O-Rama', 'Pixie16',
     'Pixie16D Smart Pixel Controller Board (16 ports)',
     'Pixie16D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Source label preserved; manufacturer firmware/board designation uses Pixie16D.'),

    ('Pixie2', 'Light-O-Rama', 'Pixie2',
     'Pixie2 / Cosmic Color Controller II (2 ports)',
     'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Pixie2 is the marketed product name; Pixie2D is the board/firmware designation.'),

    ('Pixie2D', 'Light-O-Rama', 'Pixie2',
     'Pixie2 / Cosmic Color Controller II (2 ports)',
     'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Preserve source label; do not infer first/second generation board revision.'),

    ('Pixie4', 'Light-O-Rama', 'Pixie4',
     'Pixie4D Smart Pixel Controller Board (4 ports)',
     'Pixie4D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL),

    ('Pixie8', 'Light-O-Rama', 'Pixie8',
     'Pixie8D Smart Pixel Controller Board (8 ports)',
     'Pixie8D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL)
ON CONFLICT (source_model_evidence) DO UPDATE SET
    manufacturer = EXCLUDED.manufacturer,
    canonical_model_code = EXCLUDED.canonical_model_code,
    canonical_model_name = EXCLUDED.canonical_model_name,
    firmware_family = EXCLUDED.firmware_family,
    reference_current_firmware = EXCLUDED.reference_current_firmware,
    reference_url = EXCLUDED.reference_url,
    normalization_state = EXCLUDED.normalization_state,
    notes = EXCLUDED.notes;

COMMIT;

CREATE OR REPLACE VIEW stage.v_controller_firmware_review AS
WITH observed AS (
    SELECT
        model_evidence,
        firmware_evidence,
        firmware_state_evidence,
        count(*) AS controller_count
    FROM stage.controller_bootstrap
    GROUP BY model_evidence, firmware_evidence, firmware_state_evidence
)
SELECT
    o.model_evidence AS source_model_evidence,
    mr.manufacturer,
    mr.canonical_model_code,
    mr.canonical_model_name,
    mr.firmware_family,
    o.firmware_evidence,
    o.firmware_state_evidence,
    o.controller_count,
    mr.reference_current_firmware,
    CASE
        WHEN o.firmware_state_evidence <> 'RECORDED'
            THEN 'UNKNOWN_OR_VERIFY'

        WHEN o.model_evidence IN ('32LD-G3','CTB32LG3')
         AND o.firmware_evidence IN ('1.17','1.15','1.13','1.12','1.11','1.08','1.05')
            THEN CASE WHEN o.firmware_evidence = mr.reference_current_firmware
                      THEN 'OFFICIAL_CURRENT' ELSE 'OFFICIAL_LISTED' END

        WHEN o.model_evidence = 'CTB04-G3'
         AND o.firmware_evidence = '1.01'
            THEN 'OFFICIAL_CURRENT'

        WHEN o.model_evidence = 'CF50D'
         AND o.firmware_evidence = '1.05'
            THEN 'OFFICIAL_CURRENT'

        WHEN o.model_evidence = 'CMB24D'
         AND o.firmware_evidence IN ('1.05','1.04','1.02')
            THEN CASE WHEN o.firmware_evidence = '1.05'
                      THEN 'OFFICIAL_CURRENT' ELSE 'OFFICIAL_LISTED' END

        WHEN o.model_evidence = 'CCB100'
         AND o.firmware_evidence IN ('1.21','1.19','1.18','1.16','1.15')
            THEN CASE WHEN o.firmware_evidence = '1.21'
                      THEN 'OFFICIAL_CURRENT' ELSE 'OFFICIAL_LISTED' END

        WHEN o.model_evidence = 'Pixcon16'
         AND o.firmware_evidence = '2.0.13'
            THEN 'OFFICIAL_CURRENT'

        WHEN o.model_evidence IN ('Pixie2','Pixie2D','Pixie4','Pixie8','Pixie16')
         AND o.firmware_evidence IN ('1.12','1.11','1.10','1.09','1.08','1.07','1.06','1.05','1.04','1.03')
            THEN CASE WHEN o.firmware_evidence = '1.12'
                      THEN 'OFFICIAL_CURRENT' ELSE 'OFFICIAL_LISTED' END

        WHEN (o.model_evidence = 'CMB24D' AND o.firmware_evidence = '1.10')
          OR (o.model_evidence IN ('Pixie2','Pixie16') AND o.firmware_evidence = '1.17')
            THEN 'REFERENCE_MISMATCH_REVIEW'

        ELSE 'SOURCE_RECORDED_NOT_ON_CURRENT_REFERENCE'
    END AS reference_status,
    mr.reference_url,
    mr.normalization_state,
    mr.notes
FROM observed AS o
LEFT JOIN stage.controller_model_reference AS mr
  ON mr.source_model_evidence = o.model_evidence;

CREATE OR REPLACE VIEW stage.v_controller_model_reference_summary AS
SELECT
    mr.source_model_evidence,
    mr.manufacturer,
    mr.canonical_model_code,
    mr.canonical_model_name,
    mr.firmware_family,
    mr.reference_current_firmware,
    mr.normalization_state,
    count(b.controller_bootstrap_id) AS controllers,
    mr.notes
FROM stage.controller_model_reference AS mr
LEFT JOIN stage.controller_bootstrap AS b
  ON b.model_evidence = mr.source_model_evidence
GROUP BY
    mr.source_model_evidence,
    mr.manufacturer,
    mr.canonical_model_code,
    mr.canonical_model_name,
    mr.firmware_family,
    mr.reference_current_firmware,
    mr.normalization_state,
    mr.notes;
