/* ============================================================================
Controller Inventory model/firmware normalization — STAGE ONLY
Issue: #110

Purpose:
  Treat workbook model values as source evidence and resolve them to real vendor
  model designations/full names before permanent Controller Inventory creation.

Accepted rule:
  - For Light-O-Rama equipment, canonical model codes/names must correspond to
    models actually named on the LOR Controller Firmware Updates page.
  - If workbook shorthand is a firmware family or abbreviation rather than a
    real model, correct it in this mapping layer; do not perpetuate the mistake.
  - Existing firmware values are imported as recorded-unverified evidence.
  - Firmware verification is deferred to field setup and does not block build.
  - New / ??? / blank firmware remains UNKNOWN.
  - HolidayCoro AlphaPix has a product/model reference only; no equivalent
    firmware-reference page is asserted.

This script writes only stage.* and allocates no permanent controller IDs.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS stage.controller_model_reference (
    source_model_evidence text PRIMARY KEY,
    manufacturer text NOT NULL,
    canonical_model_code text NOT NULL,
    canonical_model_name text NOT NULL,
    hardware_revision text,
    firmware_family text,
    reference_current_firmware text,
    model_reference_url text,
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
        normalization_state IN ('EXACT_VENDOR_MODEL','CORRECTED_SOURCE_MODEL','VENDOR_REFERENCE')
    )
);

-- Experimental table may already exist from an earlier branch revision.
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS canonical_model_code text;
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS hardware_revision text;
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS model_reference_url text;
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS firmware_reference_url text;

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
    canonical_model_name, hardware_revision, firmware_family,
    reference_current_firmware, model_reference_url, firmware_reference_url,
    normalization_state, notes
)
VALUES
    ('32LD-G3', 'Light-O-Rama', 'CTB32',
     'CTB32 Generation 3 Controller Board (16 channels)',
     NULL, 'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     '32LD-G3 is workbook shorthand. LOR names the model CTB32 Generation 3 Controller Board; CTB32LDg3 is the circuit-board variant named in the firmware description.'),

    ('AlphaPix Flex 48', 'HolidayCoro', 'AlphaPix Evolution Flex 48',
     'AlphaPix Evolution Flex 48-Port Pixel Controller',
     NULL, 'AlphaPix Evolution', NULL,
     'https://www.holidaycoro.com/48-Output-Pixel-Ready2Run-Assembled-Controller-p/952-8.htm',
     NULL,
     'VENDOR_REFERENCE',
     'HolidayCoro product/model reference only. No equivalent vendor firmware-reference page is recorded; firmware remains unknown until setup.'),

    ('CCB100', 'Light-O-Rama', 'CCB100',
     'CCB100 Cosmic Color Bulbs/Pixels Controller (Original RGB smart pixels-2 ports)',
     NULL, 'CCB', '1.21',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'EXACT_VENDOR_MODEL',
     'Existing recorded firmware is retained even when not shown on the current download list.'),

    ('CF50D', 'Light-O-Rama', 'CF50D',
     'CF50D Cosmic Color Flood (50 watt RGB/UV smart pixel flood with controller)',
     NULL, 'CF50D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'EXACT_VENDOR_MODEL', NULL),

    ('CMB24D', 'Light-O-Rama', 'CMB24D',
     'CMB24D Pixel Controller Board (RGB dumb pixels board - 8 pixels)',
     NULL, 'CMB24D', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'EXACT_VENDOR_MODEL',
     'Recorded firmware remains unverified until setup.'),

    ('CTB04-G3', 'Light-O-Rama', 'CTB04Dg3',
     'CTB04Dg3 Generation 3 Controller (4 channels)',
     NULL, 'CTB04Dg3', '1.01',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'CTB04-G3 is workbook shorthand; corrected to the LOR model designation CTB04Dg3.'),

    ('CTB32LG3', 'Light-O-Rama', 'CTB32',
     'CTB32 Generation 3 Controller Board (16 channels)',
     NULL, 'CTB32LG3', '1.17',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'CTB32LG3 is the firmware family/name, not the model. Corrected to the LOR CTB32 Generation 3 model family.'),

    ('Pixcon16', 'Light-O-Rama', 'PixCon16',
     'PixCon16 Controller Board (RGB smart pixels - 16 ports)',
     'MKII', 'PixCon16 MKII', '2.0.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'Capitalization/model name corrected to LOR. Recorded firmware 2.0.13 identifies these seven boards as MKII per LOR.'),

    ('Pixie16', 'Light-O-Rama', 'Pixie16D',
     'Pixie16D Controller Board (RGB smart pixels - 16 ports)',
     NULL, 'Pixie16D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'Workbook shorthand corrected to LOR model Pixie16D.'),

    ('Pixie2', 'Light-O-Rama', 'Pixie2D',
     'Pixie2D/Cosmic Color Controller II (RGB smart pixels - 2 ports)',
     NULL, 'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'Workbook shorthand corrected to the LOR page model Pixie2D/Cosmic Color Controller II.'),

    ('Pixie2D', 'Light-O-Rama', 'Pixie2D',
     'Pixie2D/Cosmic Color Controller II (RGB smart pixels - 2 ports)',
     NULL, 'Pixie2D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'EXACT_VENDOR_MODEL', NULL),

    ('Pixie4', 'Light-O-Rama', 'Pixie4D',
     'Pixie4D Controller Board (RGB smart pixels - 4 ports)',
     NULL, 'Pixie4D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'Workbook shorthand corrected to LOR model Pixie4D.'),

    ('Pixie8', 'Light-O-Rama', 'Pixie8D',
     'Pixie8D Controller Board (RGB smart pixels - 8 ports)',
     NULL, 'Pixie8D', '1.12',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'CORRECTED_SOURCE_MODEL',
     'Workbook shorthand corrected to LOR model Pixie8D.')
ON CONFLICT (source_model_evidence) DO UPDATE SET
    manufacturer = EXCLUDED.manufacturer,
    canonical_model_code = EXCLUDED.canonical_model_code,
    canonical_model_name = EXCLUDED.canonical_model_name,
    hardware_revision = EXCLUDED.hardware_revision,
    firmware_family = EXCLUDED.firmware_family,
    reference_current_firmware = EXCLUDED.reference_current_firmware,
    model_reference_url = EXCLUDED.model_reference_url,
    firmware_reference_url = EXCLUDED.firmware_reference_url,
    normalization_state = EXCLUDED.normalization_state,
    notes = EXCLUDED.notes;

COMMIT;

CREATE OR REPLACE VIEW stage.v_controller_model_reference_summary AS
SELECT
    r.source_model_evidence,
    r.manufacturer,
    r.canonical_model_code,
    r.canonical_model_name,
    r.hardware_revision,
    r.firmware_family,
    r.reference_current_firmware,
    r.normalization_state,
    count(b.controller_bootstrap_id) AS controllers,
    r.notes
FROM stage.controller_model_reference AS r
LEFT JOIN stage.controller_bootstrap AS b
  ON b.model_evidence = r.source_model_evidence
GROUP BY
    r.source_model_evidence, r.manufacturer, r.canonical_model_code,
    r.canonical_model_name, r.hardware_revision, r.firmware_family,
    r.reference_current_firmware, r.normalization_state, r.notes;

CREATE OR REPLACE VIEW stage.v_controller_firmware_review AS
WITH observed AS (
    SELECT model_evidence, firmware_evidence, firmware_state_evidence,
           count(*) AS controller_count
    FROM stage.controller_bootstrap
    GROUP BY model_evidence, firmware_evidence, firmware_state_evidence
)
SELECT
    o.model_evidence AS source_model_evidence,
    r.manufacturer,
    r.canonical_model_code,
    r.canonical_model_name,
    r.hardware_revision,
    r.firmware_family,
    o.firmware_evidence,
    o.firmware_state_evidence,
    o.controller_count,
    CASE WHEN o.firmware_state_evidence = 'RECORDED'
         THEN 'RECORDED_UNVERIFIED' ELSE 'UNKNOWN' END AS setup_verification_state,
    r.reference_current_firmware,
    CASE
        WHEN o.firmware_state_evidence <> 'RECORDED' THEN 'NOT_APPLICABLE'
        WHEN r.firmware_reference_url IS NULL THEN 'NO_VENDOR_FIRMWARE_REFERENCE_PAGE'
        WHEN o.firmware_evidence = r.reference_current_firmware THEN 'CURRENT_REFERENCE_MATCH'
        ELSE 'RECORDED_VALUE_PRESERVED'
    END AS vendor_reference_status,
    r.model_reference_url,
    r.firmware_reference_url,
    r.normalization_state,
    r.notes
FROM observed AS o
LEFT JOIN stage.controller_model_reference AS r
  ON r.source_model_evidence = o.model_evidence;
