/* ============================================================================
Controller Inventory model/firmware normalization — STAGE ONLY
Issue: #110

Purpose:
  Preserve workbook model/firmware evidence exactly while adding canonical
  manufacturer model names and separate model-vs-firmware vendor references.

Operating rule:
  - Workbook model labels remain the short operational/source labels.
  - canonical_model_name carries the full manufacturer/product name.
  - Existing firmware values are recorded evidence, not powered verification.
  - Firmware verification does NOT block Controller Inventory creation.
  - RECORDED source values remain RECORDED_UNVERIFIED until field setup.
  - New / ??? / blank remain UNKNOWN until field setup.
  - Vendor current/listed firmware is reference information only.
  - A vendor product/model page is not assumed to be a firmware reference page.

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
    reference_url text,
    firmware_reference_url text,
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

-- Safe for an earlier experimental revision of this table.
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS firmware_reference_url text;
ALTER TABLE stage.controller_model_reference
    ALTER COLUMN reference_url DROP NOT NULL;

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
    reference_url, firmware_reference_url, normalization_state, notes
)
VALUES
    ('32LD-G3', 'Light-O-Rama', 'CTB32LDg3',
     'CTB32LDg3 Generation 3 Controller Board (16 channels)',
     'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Workbook shorthand retained as source evidence; canonical name uses the manufacturer board designation.'),

    ('AlphaPix Flex 48', 'HolidayCoro', 'AlphaPix Evolution Flex 48',
     'AlphaPix Evolution Flex 48-Port Pixel Controller',
     'AlphaPix Evolution', NULL,
     'https://www.holidaycoro.com/48-Output-Pixel-Ready2Run-Assembled-Controller-p/952-8.htm',
     NULL,
     'VENDOR_REFERENCE',
     'HolidayCoro product reference only. No equivalent vendor firmware-reference page is recorded. Two staged controllers have no firmware evidence; verify during setup.'),

    ('CCB100', 'Light-O-Rama', 'CCB100',
     'CCB100 Cosmic Color Bulbs/Pixels Controller (Original RGB smart pixels - 2 ports)',
     'CCB', '1.21',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Existing recorded firmware is retained even if not present on the current vendor download page.'),

    ('CF50D', 'Light-O-Rama', 'CF50D',
     'CF50D Cosmic Color Flood (50 watt RGB/UV smart pixel flood with controller)',
     'CF50D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL),

    ('CMB24D', 'Light-O-Rama', 'CMB24D',
     'CMB24D Pixel Controller Board (24 channels / 8 RGB dumb pixels)',
     'CMB24D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Existing recorded firmware is retained pending powered setup verification.'),

    ('CTB04-G3', 'Light-O-Rama', 'CTB04Dg3',
     'CTB04Dg3 Generation 3 Controller (4 channels)',
     'CTB04Dg3', '1.01',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Workbook shorthand retained as source evidence; canonical name uses the manufacturer designation.'),

    ('CTB32LG3', 'Light-O-Rama', 'CTB32/LOR160x-G3',
     'CTB32 / LOR160x Generation 3 Professional Controller Family (16 channels)',
     'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'FAMILY_ONLY',
     'CTB32LG3 is the firmware family/source shorthand. Exact board/enclosure variant may be refined during setup without changing controller identity.'),

    ('Pixcon16', 'Light-O-Rama', 'PixCon16-MKII',
     'PixCon16 MKII Controller Board (RGB smart pixels - 16 ports)',
     'PixCon16 MKII', '2.0.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'All seven staged rows report firmware 2.0.13. LOR states firmware beginning with 2 identifies the MKII revision.'),

    ('Pixie16', 'Light-O-Rama', 'Pixie16D',
     'Pixie16D Controller Board (RGB smart pixels - 16 ports)',
     'Pixie16D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Source firmware remains recorded-unverified until setup.'),

    ('Pixie2', 'Light-O-Rama', 'Pixie2D',
     'Pixie2D / Cosmic Color Controller II (RGB smart pixels - 2 ports)',
     'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Pixie2 is the short/marketed name; Pixie2D is the board/firmware designation.'),

    ('Pixie2D', 'Light-O-Rama', 'Pixie2D',
     'Pixie2D / Cosmic Color Controller II (RGB smart pixels - 2 ports)',
     'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED',
     'Preserve workbook source label while using the common manufacturer model.'),

    ('Pixie4', 'Light-O-Rama', 'Pixie4D',
     'Pixie4D Controller Board (RGB smart pixels - 4 ports)',
     'Pixie4D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL),

    ('Pixie8', 'Light-O-Rama', 'Pixie8D',
     'Pixie8D Controller Board (RGB smart pixels - 8 ports)',
     'Pixie8D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'REFERENCE_MATCHED', NULL)
ON CONFLICT (source_model_evidence) DO UPDATE SET
    manufacturer = EXCLUDED.manufacturer,
    canonical_model_code = EXCLUDED.canonical_model_code,
    canonical_model_name = EXCLUDED.canonical_model_name,
    firmware_family = EXCLUDED.firmware_family,
    reference_current_firmware = EXCLUDED.reference_current_firmware,
    reference_url = EXCLUDED.reference_url,
    firmware_reference_url = EXCLUDED.firmware_reference_url,
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
    CASE
        WHEN o.firmware_state_evidence = 'RECORDED'
            THEN 'RECORDED_UNVERIFIED'
        ELSE 'UNKNOWN'
    END AS setup_verification_state,
    mr.reference_current_firmware,
    CASE
        WHEN o.firmware_state_evidence <> 'RECORDED'
            THEN 'NOT_APPLICABLE'
        WHEN mr.firmware_reference_url IS NULL
            THEN 'NO_VENDOR_FIRMWARE_REFERENCE_PAGE'
        WHEN mr.reference_current_firmware IS NULL
            THEN 'NO_CURRENT_REFERENCE'
        WHEN o.firmware_evidence = mr.reference_current_firmware
            THEN 'CURRENT_REFERENCE_MATCH'
        WHEN o.model_evidence IN ('32LD-G3','CTB32LG3')
         AND o.firmware_evidence IN ('1.17','1.15','1.13','1.12','1.11','1.08','1.05')
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence = 'CTB04-G3'
         AND o.firmware_evidence = '1.01'
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence = 'CF50D'
         AND o.firmware_evidence = '1.05'
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence = 'CMB24D'
         AND o.firmware_evidence IN ('1.05','1.04','1.02')
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence = 'CCB100'
         AND o.firmware_evidence IN ('1.21','1.19','1.18','1.16','1.15')
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence = 'Pixcon16'
         AND o.firmware_evidence = '2.0.13'
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        WHEN o.model_evidence IN ('Pixie2','Pixie2D','Pixie4','Pixie8','Pixie16')
         AND o.firmware_evidence IN ('1.12','1.11','1.10','1.09','1.08','1.07','1.06','1.05','1.04','1.03')
            THEN 'LISTED_ON_CURRENT_VENDOR_PAGE'
        ELSE 'NOT_LISTED_ON_CURRENT_VENDOR_PAGE'
    END AS vendor_reference_status,
    mr.reference_url AS model_reference_url,
    mr.firmware_reference_url,
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
    mr.reference_url AS model_reference_url,
    mr.firmware_reference_url,
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
    mr.reference_url,
    mr.firmware_reference_url,
    mr.normalization_state,
    mr.notes;
