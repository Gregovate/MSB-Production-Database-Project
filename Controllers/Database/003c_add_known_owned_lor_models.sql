/* ============================================================================
Controller Inventory known-owned LOR model catalog additions — STAGE ONLY
Issue: #110

Purpose:
  Add manufacturer-authoritative Light-O-Rama model rows for hardware MSB has
  purchased but which is not represented by the 177 deployed-controller
  bootstrap workbook.

Rules:
  - This is model/catalog evidence only. It creates no physical controller rows.
  - Installed firmware for these physical devices remains unknown until setup.
  - Vendor-current firmware is reference guidance only.
  - RFV4 and RFV5 are separate canonical models because LOR publishes distinct
    firmware for each revision even though the page groups them under RFV4/5 ELL.
  - Display-assignment capability distinguishes output controllers from managed
    show-control infrastructure such as Directors, ELLs, bridges and adapters.

This script writes only stage.* and allocates no controller IDs.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('stage.controller_model_reference') IS NULL THEN
        RAISE EXCEPTION 'stage.controller_model_reference is required; run 003b first';
    END IF;
END
$preflight$;

ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS device_family text;
ALTER TABLE stage.controller_model_reference
    ADD COLUMN IF NOT EXISTS display_assignment_capable boolean;

-- Classify the models already represented by the 177 deployed-controller source.
UPDATE stage.controller_model_reference
SET device_family = CASE canonical_model_code
        WHEN 'CTB04Dg3' THEN 'AC_CONTROLLER'
        WHEN 'CTB32' THEN 'AC_CONTROLLER'
        WHEN 'CMB24D' THEN 'DUMB_RGB_CONTROLLER'
        WHEN 'CCB100' THEN 'PIXEL_CONTROLLER'
        WHEN 'CF50D' THEN 'INTEGRATED_RGB_FIXTURE_CONTROLLER'
        WHEN 'Pixie2D' THEN 'PIXEL_CONTROLLER'
        WHEN 'Pixie4D' THEN 'PIXEL_CONTROLLER'
        WHEN 'Pixie8D' THEN 'PIXEL_CONTROLLER'
        WHEN 'Pixie16D' THEN 'PIXEL_CONTROLLER'
        WHEN 'PixCon16' THEN 'E131_PIXEL_CONTROLLER'
        WHEN 'AlphaPix Evolution Flex 48' THEN 'E131_PIXEL_CONTROLLER'
        ELSE device_family
    END,
    display_assignment_capable = CASE canonical_model_code
        WHEN 'CTB04Dg3' THEN true
        WHEN 'CTB32' THEN true
        WHEN 'CMB24D' THEN true
        WHEN 'CCB100' THEN true
        WHEN 'CF50D' THEN true
        WHEN 'Pixie2D' THEN true
        WHEN 'Pixie4D' THEN true
        WHEN 'Pixie8D' THEN true
        WHEN 'Pixie16D' THEN true
        WHEN 'PixCon16' THEN true
        WHEN 'AlphaPix Evolution Flex 48' THEN true
        ELSE display_assignment_capable
    END;

INSERT INTO stage.controller_model_reference (
    source_model_evidence, manufacturer, canonical_model_code,
    canonical_model_name, hardware_revision, firmware_family,
    reference_current_firmware, model_reference_url, firmware_reference_url,
    normalization_state, notes, device_family, display_assignment_capable
)
VALUES
    ('N4-G4-MP3', 'Light-O-Rama', 'N4-G4-MP3',
     'N4-G4-MP3 Director Generation 4',
     NULL, 'N4-MP3g4', '6.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('N2-G4-MP3', 'Light-O-Rama', 'N2-G4-MP3',
     'N2-G4-MP3 Director Generation 4',
     NULL, 'N2-MP3g4', '6.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('N1uMP3g4', 'Light-O-Rama', 'N1uMP3g4',
     'N1uMP3g4 miniDirector Generation 4',
     NULL, 'N1uMP3g4', '6.13',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('uMP3g3', 'Light-O-Rama', 'uMP3g3',
     'uMP3g3 miniDirector Generation 3',
     NULL, 'uMP3g3', '5.36',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('G3-MP3', 'Light-O-Rama', 'G3-MP3',
     'G3-MP3 Director Generation 3',
     NULL, 'G3-MP3', '5.38',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('RFV4', 'Light-O-Rama', 'RFV4',
     'RFV4 Easy Light Linker (ELL)',
     NULL, 'RFV4', '2.10',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'LOR groups RFV4/5 under one ELL heading, but RFV4 has distinct firmware. MSB purchase evidence identifies the RFV4/5 family; exact physical revision/count remains to be inventoried.',
     'WIRELESS_LINK', false),

    ('RFV5', 'Light-O-Rama', 'RFV5',
     'RFV5 Easy Light Linker (ELL)',
     NULL, 'RFV5', '2.11',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'LOR groups RFV4/5 under one ELL heading, but RFV5 has distinct firmware. MSB purchase evidence identifies the RFV4/5 family; exact physical revision/count remains to be inventoried.',
     'WIRELESS_LINK', false),

    ('iDMX1000', 'Light-O-Rama', 'iDMX1000',
     'iDMX1000 DMX Bridge',
     NULL, 'iDMX1000', '1.50',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DMX_BRIDGE', false),

    ('InputPup', 'Light-O-Rama', 'InputPup',
     'InputPup External Trigger Controller Board',
     NULL, 'InputPup', '1.01',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'INPUT_CONTROLLER', false),

    ('PixieLink', 'Light-O-Rama', 'PixieLink',
     'PixieLink (sACN/Art-Net Adapter for Light-O-Rama controllers)',
     NULL, 'PixieLink', '1.04',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'NETWORK_ADAPTER', false),

    ('ServoDog', 'Light-O-Rama', 'ServoDog',
     'ServoDog Servo Board',
     NULL, 'ServoDog', '1.05',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'SERVO_CONTROLLER', true),

    ('DC-MP3', 'Light-O-Rama', 'DC-MP3',
     'DC-MP3 Director (Original)',
     NULL, 'DC MP3', '4.20',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false),

    ('mDC MP3', 'Light-O-Rama', 'mDC MP3',
     'mDC MP3 miniDirector (Original)',
     NULL, 'mDC MP3', '4.22',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'https://store.lightorama.com/pages/controller-firmware-updates',
     'VENDOR_REFERENCE',
     'MSB purchase-list evidence supplied during Controller Inventory bootstrap; physical device inventory and installed firmware to be verified later.',
     'DIRECTOR', false)
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
    notes = EXCLUDED.notes,
    device_family = EXCLUDED.device_family,
    display_assignment_capable = EXCLUDED.display_assignment_capable;

COMMIT;

CREATE OR REPLACE VIEW stage.v_controller_model_reference_summary AS
SELECT
    r.source_model_evidence,
    r.manufacturer,
    r.canonical_model_code,
    r.canonical_model_name,
    r.hardware_revision,
    r.firmware_family,
    r.device_family,
    r.display_assignment_capable,
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
    r.device_family, r.display_assignment_capable,
    r.reference_current_firmware, r.normalization_state, r.notes;
