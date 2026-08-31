/* ============================================================================
Controller Inventory permanent model/firmware catalog
Issue: #110

Purpose:
  Create the permanent Controller model and firmware lookup tables from the
  reviewed stage.controller_model_reference mapping before any physical
  controller_id is allocated.

Model rule:
  - Workbook model text is source evidence only.
  - Permanent ref.controller_model.model_code is the corrected vendor model code.
  - model_name is the full vendor model/product name.
  - Hardware revision is NOT a model-level fact; it belongs to the individual
    physical controller and is created later by 002b.

Firmware rule:
  - Every workbook value classified RECORDED is retained exactly as recorded.
  - RECORDED means recorded-unverified, not powered/field verified.
  - New / ??? / blank are not firmware catalog versions.
  - Vendor current firmware is optional reference guidance only.

This script creates no ref.controller table and allocates no controller IDs.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('stage.controller_bootstrap') IS NULL THEN
        RAISE EXCEPTION 'stage.controller_bootstrap is required before creating Controller catalog';
    END IF;
    IF to_regclass('stage.controller_model_reference') IS NULL THEN
        RAISE EXCEPTION 'stage.controller_model_reference is required; run 003b first';
    END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS ref.controller_model (
    controller_model_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_code text NOT NULL UNIQUE,
    manufacturer text NOT NULL,
    model_name text NOT NULL,
    firmware_family text,
    device_family text,
    model_reference_url text,
    firmware_reference_url text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer
);

CREATE TABLE IF NOT EXISTS ref.controller_firmware_version (
    controller_firmware_version_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    controller_model_id integer NOT NULL,
    firmware_version text NOT NULL,
    source_note text,
    is_current_recommended boolean NOT NULL DEFAULT false,
    reference_url text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,
    CONSTRAINT fk_controller_firmware_version_model
        FOREIGN KEY (controller_model_id)
        REFERENCES ref.controller_model(controller_model_id),
    CONSTRAINT uq_controller_firmware_model_version
        UNIQUE (controller_model_id, firmware_version),
    CONSTRAINT uq_controller_firmware_model_id_pair
        UNIQUE (controller_model_id, controller_firmware_version_id)
);

DROP TRIGGER IF EXISTS trg_controller_model_actor_insert ON ref.controller_model;
CREATE TRIGGER trg_controller_model_actor_insert
BEFORE INSERT ON ref.controller_model
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_controller_model_actor_update ON ref.controller_model;
CREATE TRIGGER trg_controller_model_actor_update
BEFORE UPDATE ON ref.controller_model
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_firmware_version_actor_insert
    ON ref.controller_firmware_version;
CREATE TRIGGER trg_controller_firmware_version_actor_insert
BEFORE INSERT ON ref.controller_firmware_version
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_controller_firmware_version_actor_update
    ON ref.controller_firmware_version;
CREATE TRIGGER trg_controller_firmware_version_actor_update
BEFORE UPDATE ON ref.controller_firmware_version
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

-- One permanent row per corrected real vendor model. Multiple workbook aliases
-- may intentionally resolve to one model (e.g. 32LD-G3 and CTB32LG3 -> CTB32).
INSERT INTO ref.controller_model (
    model_code,
    manufacturer,
    model_name,
    firmware_family,
    model_reference_url,
    firmware_reference_url,
    notes
)
SELECT DISTINCT ON (r.canonical_model_code)
    r.canonical_model_code,
    r.manufacturer,
    r.canonical_model_name,
    r.firmware_family,
    r.model_reference_url,
    r.firmware_reference_url,
    CASE
        WHEN count(*) OVER (PARTITION BY r.canonical_model_code) > 1
            THEN 'Multiple bootstrap source labels normalize to this vendor model; source labels remain in stage provenance.'
        ELSE r.notes
    END
FROM stage.controller_model_reference AS r
ORDER BY r.canonical_model_code, r.source_model_evidence
ON CONFLICT (model_code) DO UPDATE SET
    manufacturer = EXCLUDED.manufacturer,
    model_name = EXCLUDED.model_name,
    firmware_family = EXCLUDED.firmware_family,
    model_reference_url = EXCLUDED.model_reference_url,
    firmware_reference_url = EXCLUDED.firmware_reference_url,
    notes = EXCLUDED.notes;

-- Vendor-current firmware is optional setup guidance. AlphaPix has no comparable
-- firmware-reference page recorded and therefore contributes no current row.
INSERT INTO ref.controller_firmware_version (
    controller_model_id,
    firmware_version,
    source_note,
    is_current_recommended,
    reference_url
)
SELECT DISTINCT
    m.controller_model_id,
    r.reference_current_firmware,
    'Vendor current firmware reference at Controller Inventory bootstrap',
    true,
    r.firmware_reference_url
FROM stage.controller_model_reference AS r
JOIN ref.controller_model AS m
  ON m.model_code = r.canonical_model_code
WHERE r.reference_current_firmware IS NOT NULL
  AND r.firmware_reference_url IS NOT NULL
ON CONFLICT (controller_model_id, firmware_version) DO UPDATE SET
    is_current_recommended = true,
    reference_url = EXCLUDED.reference_url;

-- Retain every firmware version actually recorded in the 177-controller source,
-- even when not listed on the vendor's current page. Field verification is later.
INSERT INTO ref.controller_firmware_version (
    controller_model_id,
    firmware_version,
    source_note,
    is_current_recommended,
    reference_url
)
SELECT DISTINCT
    m.controller_model_id,
    btrim(b.firmware_evidence),
    'Controller Inventory & Testing 2026(7) recorded evidence; field verification pending setup',
    (r.reference_current_firmware IS NOT NULL
     AND btrim(b.firmware_evidence) = r.reference_current_firmware),
    r.firmware_reference_url
FROM stage.controller_bootstrap AS b
JOIN stage.controller_model_reference AS r
  ON r.source_model_evidence = b.model_evidence
JOIN ref.controller_model AS m
  ON m.model_code = r.canonical_model_code
WHERE b.firmware_state_evidence = 'RECORDED'
  AND nullif(btrim(coalesce(b.firmware_evidence, '')), '') IS NOT NULL
ON CONFLICT (controller_model_id, firmware_version) DO UPDATE SET
    source_note = EXCLUDED.source_note,
    is_current_recommended = ref.controller_firmware_version.is_current_recommended
                             OR EXCLUDED.is_current_recommended,
    reference_url = COALESCE(EXCLUDED.reference_url,
                             ref.controller_firmware_version.reference_url);

COMMIT;

SELECT
    count(*) AS permanent_controller_models
FROM ref.controller_model;

SELECT
    m.model_code,
    m.model_name,
    count(fv.controller_firmware_version_id) AS firmware_versions
FROM ref.controller_model AS m
LEFT JOIN ref.controller_firmware_version AS fv
  ON fv.controller_model_id = m.controller_model_id
GROUP BY m.controller_model_id, m.model_code, m.model_name
ORDER BY m.model_code;
