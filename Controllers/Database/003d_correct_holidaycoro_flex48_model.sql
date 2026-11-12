/* ============================================================================
Controller Inventory HolidayCoro Flex 48 model correction
Issue: #110

Purpose:
  Correct the two staged HolidayCoro Flex 48 controllers before permanent
  controller_id allocation.

Why:
  HolidayCoro's assembled 48-port Flex controller can be supplied with more than
  one CPU family (AlphaPix Evolution or HinksPix Pro). The workbook source label
  "AlphaPix Flex 48" is therefore insufficient evidence to promote the CPU as
  AlphaPix Evolution.

Rule:
  - Keep the physical assembled product identified now.
  - Do not guess the firmware-bearing CPU/model.
  - Installed firmware remains UNKNOWN until setup verification.
  - Exact CPU/revision may be recorded later without changing controller_id.

This script changes catalog/reference data only. It creates no controller rows
and allocates no controller IDs.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('stage.controller_model_reference') IS NULL THEN
        RAISE EXCEPTION 'stage.controller_model_reference is required';
    END IF;
    IF to_regclass('ref.controller_model') IS NULL THEN
        RAISE EXCEPTION 'ref.controller_model is required';
    END IF;
    IF to_regclass('ref.controller') IS NOT NULL
       AND EXISTS (SELECT 1 FROM ref.controller) THEN
        RAISE EXCEPTION 'Flex 48 catalog correction must run before physical Controller promotion';
    END IF;
END
$preflight$;

UPDATE stage.controller_model_reference
SET canonical_model_code = 'HolidayCoro Flex 48',
    canonical_model_name = 'Flex 48-Port Pixel Controller',
    hardware_revision = NULL,
    firmware_family = NULL,
    reference_current_firmware = NULL,
    normalization_state = 'VENDOR_REFERENCE',
    notes = 'HolidayCoro assembled Flex 48 product. CPU/firmware-bearing model is not proven by workbook shorthand; identify AlphaPix Evolution vs HinksPix Pro CPU during setup before firmware selection.'
WHERE source_model_evidence = 'AlphaPix Flex 48';

UPDATE ref.controller_model
SET model_code = 'HolidayCoro Flex 48',
    model_name = 'Flex 48-Port Pixel Controller',
    firmware_family = NULL,
    device_family = 'E131_PIXEL_CONTROLLER',
    display_assignment_capable = true,
    notes = 'HolidayCoro assembled Flex 48 product. CPU/firmware-bearing model remains field-verifiable during setup; do not infer AlphaPix Evolution vs HinksPix Pro from workbook shorthand.'
WHERE model_code = 'AlphaPix Evolution Flex 48';

-- There must be no firmware catalog rows tied to this generic assembled-product
-- model until the installed CPU/model is identified.
DELETE FROM ref.controller_firmware_version AS fv
USING ref.controller_model AS m
WHERE fv.controller_model_id = m.controller_model_id
  AND m.model_code = 'HolidayCoro Flex 48';

COMMIT;

SELECT
    r.source_model_evidence,
    r.canonical_model_code,
    r.canonical_model_name,
    r.firmware_family,
    r.reference_current_firmware
FROM stage.controller_model_reference AS r
WHERE r.source_model_evidence = 'AlphaPix Flex 48';

SELECT
    controller_model_id,
    model_code,
    model_name,
    firmware_family,
    device_family,
    display_assignment_capable
FROM ref.controller_model
WHERE model_code = 'HolidayCoro Flex 48';
