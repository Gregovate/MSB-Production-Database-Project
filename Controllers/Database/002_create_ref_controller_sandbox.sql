/* ============================================================================
Controller Inventory permanent-shaped sandbox
Issue: #110

Purpose:
  Create isolated permanent Controller Inventory objects only after stage-only
  bootstrap/model review has been accepted.

Required stage inputs:
  stage.controller_bootstrap
  stage.controller_model_reference

Model rule:
  - model_code is the short operational code already used in the workbook.
  - manufacturer_model_code stores the vendor designation separately.
  - model_name stores the full manufacturer/product name.
  - Distinct source model codes are not collapsed during bootstrap.

Firmware rule:
  - RECORDED workbook firmware is imported exactly as recorded.
  - RECORDED does not mean powered/field verified.
  - New / ??? / blank remain UNKNOWN.
  - Firmware verification happens during setup and does not block controller
    creation or controller_id assignment.
  - Vendor firmware information is reference metadata only.

Identity rule:
  ref.controller.controller_id starts at 1001.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('stage.controller_bootstrap') IS NULL THEN
        RAISE EXCEPTION 'stage.controller_bootstrap is required before creating Controller Inventory';
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
    manufacturer_model_code text,
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

CREATE TABLE IF NOT EXISTS ref.controller_status (
    controller_status_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    controller_status_name text NOT NULL UNIQUE,
    description text,
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

CREATE TABLE IF NOT EXISTS ref.controller (
    controller_id bigint GENERATED ALWAYS AS IDENTITY
        (START WITH 1001 INCREMENT BY 1) PRIMARY KEY,
    controller_model_id integer NOT NULL,
    controller_status_id integer NOT NULL,
    installed_firmware_version_id integer,
    firmware_verification_state text NOT NULL DEFAULT 'UNKNOWN',
    firmware_verified_at timestamptz,
    firmware_verified_by_person_id integer,
    firmware_verification_note text,
    serial_number text,
    year_deployed integer,
    current_location_code text,
    is_display_attached boolean,
    verification_state text NOT NULL DEFAULT 'ENGINEERING_ACCEPTED',
    notes text,

    label_required boolean NOT NULL DEFAULT true,
    print_label boolean NOT NULL DEFAULT false,
    label_print_count_cached integer NOT NULL DEFAULT 0,
    label_print_last_at_cached timestamptz,
    label_print_last_by_cached_id integer,
    label_template_id integer,

    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_controller_model
        FOREIGN KEY (controller_model_id)
        REFERENCES ref.controller_model(controller_model_id),
    CONSTRAINT fk_controller_status
        FOREIGN KEY (controller_status_id)
        REFERENCES ref.controller_status(controller_status_id),
    CONSTRAINT fk_controller_installed_firmware
        FOREIGN KEY (controller_model_id, installed_firmware_version_id)
        REFERENCES ref.controller_firmware_version(
            controller_model_id, controller_firmware_version_id
        ),
    CONSTRAINT fk_controller_firmware_verified_by
        FOREIGN KEY (firmware_verified_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT fk_controller_current_location
        FOREIGN KEY (current_location_code)
        REFERENCES ref.location(location_code),
    CONSTRAINT fk_controller_label_last_by
        FOREIGN KEY (label_print_last_by_cached_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT fk_controller_label_template
        FOREIGN KEY (label_template_id)
        REFERENCES ref.label_template(label_template_id),
    CONSTRAINT ck_controller_year_deployed CHECK (
        year_deployed IS NULL OR year_deployed BETWEEN 1980 AND 2100
    ),
    CONSTRAINT ck_controller_verification_state CHECK (
        verification_state IN (
            'ENGINEERING_ACCEPTED',
            'FIELD_VERIFICATION_REQUIRED',
            'PHYSICALLY_VERIFIED'
        )
    ),
    CONSTRAINT ck_controller_firmware_verification_state CHECK (
        firmware_verification_state IN (
            'UNKNOWN',
            'RECORDED_UNVERIFIED',
            'VERIFIED'
        )
    ),
    CONSTRAINT ck_controller_label_print_count CHECK (
        label_print_count_cached >= 0
    )
);

CREATE TABLE IF NOT EXISTS ref.controller_display (
    controller_id bigint NOT NULL,
    display_id bigint NOT NULL,
    wiring_source_display_id bigint,
    placement_note text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_controller_display PRIMARY KEY (controller_id, display_id),
    CONSTRAINT fk_controller_display_controller
        FOREIGN KEY (controller_id)
        REFERENCES ref.controller(controller_id),
    CONSTRAINT fk_controller_display_display
        FOREIGN KEY (display_id)
        REFERENCES ref.display(display_id),
    CONSTRAINT fk_controller_display_wiring_source
        FOREIGN KEY (wiring_source_display_id)
        REFERENCES ref.display(display_id)
);

CREATE TABLE IF NOT EXISTS ref.controller_firmware_history (
    controller_firmware_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    controller_id bigint NOT NULL,
    controller_firmware_version_id integer NOT NULL,
    firmware_recorded_at timestamptz NOT NULL DEFAULT now(),
    verification_state text NOT NULL,
    verified_at timestamptz,
    verified_by_person_id integer,
    source_note text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,
    CONSTRAINT fk_controller_firmware_history_controller
        FOREIGN KEY (controller_id)
        REFERENCES ref.controller(controller_id),
    CONSTRAINT fk_controller_firmware_history_version
        FOREIGN KEY (controller_firmware_version_id)
        REFERENCES ref.controller_firmware_version(controller_firmware_version_id),
    CONSTRAINT fk_controller_firmware_history_verified_by
        FOREIGN KEY (verified_by_person_id)
        REFERENCES ref.person(person_id),
    CONSTRAINT ck_controller_firmware_history_state CHECK (
        verification_state IN ('RECORDED_UNVERIFIED','VERIFIED')
    )
);

-- Standard actor triggers.
DROP TRIGGER IF EXISTS trg_controller_model_actor_insert ON ref.controller_model;
CREATE TRIGGER trg_controller_model_actor_insert
BEFORE INSERT ON ref.controller_model
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_model_actor_update ON ref.controller_model;
CREATE TRIGGER trg_controller_model_actor_update
BEFORE UPDATE ON ref.controller_model
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_status_actor_insert ON ref.controller_status;
CREATE TRIGGER trg_controller_status_actor_insert
BEFORE INSERT ON ref.controller_status
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_status_actor_update ON ref.controller_status;
CREATE TRIGGER trg_controller_status_actor_update
BEFORE UPDATE ON ref.controller_status
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_firmware_version_actor_insert ON ref.controller_firmware_version;
CREATE TRIGGER trg_controller_firmware_version_actor_insert
BEFORE INSERT ON ref.controller_firmware_version
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_firmware_version_actor_update ON ref.controller_firmware_version;
CREATE TRIGGER trg_controller_firmware_version_actor_update
BEFORE UPDATE ON ref.controller_firmware_version
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_actor_insert ON ref.controller;
CREATE TRIGGER trg_controller_actor_insert
BEFORE INSERT ON ref.controller
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_actor_update ON ref.controller;
CREATE TRIGGER trg_controller_actor_update
BEFORE UPDATE ON ref.controller
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_display_actor_insert ON ref.controller_display;
CREATE TRIGGER trg_controller_display_actor_insert
BEFORE INSERT ON ref.controller_display
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_display_actor_update ON ref.controller_display;
CREATE TRIGGER trg_controller_display_actor_update
BEFORE UPDATE ON ref.controller_display
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_firmware_history_actor_insert ON ref.controller_firmware_history;
CREATE TRIGGER trg_controller_firmware_history_actor_insert
BEFORE INSERT ON ref.controller_firmware_history
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_firmware_history_actor_update ON ref.controller_firmware_history;
CREATE TRIGGER trg_controller_firmware_history_actor_update
BEFORE UPDATE ON ref.controller_firmware_history
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

INSERT INTO ref.controller_status (controller_status_name, description)
VALUES
    ('DEPLOYED', 'Controller is assigned to the current show inventory; physical location is tracked separately.'),
    ('AVAILABLE', 'Controller exists as unassigned stock.'),
    ('REPAIR', 'Controller is held for repair or troubleshooting.'),
    ('RETIRED', 'Controller identity is retained but the asset is retired.')
ON CONFLICT (controller_status_name) DO NOTHING;

-- One permanent model row per reviewed short operational/source model code.
INSERT INTO ref.controller_model (
    model_code,
    manufacturer,
    manufacturer_model_code,
    model_name,
    firmware_family,
    model_reference_url,
    firmware_reference_url,
    notes
)
SELECT
    r.source_model_evidence,
    r.manufacturer,
    r.manufacturer_model_code,
    r.canonical_model_name,
    r.firmware_family,
    r.reference_url,
    r.firmware_reference_url,
    r.notes
FROM stage.controller_model_reference AS r
ON CONFLICT (model_code) DO UPDATE SET
    manufacturer = EXCLUDED.manufacturer,
    manufacturer_model_code = EXCLUDED.manufacturer_model_code,
    model_name = EXCLUDED.model_name,
    firmware_family = EXCLUDED.firmware_family,
    model_reference_url = EXCLUDED.model_reference_url,
    firmware_reference_url = EXCLUDED.firmware_reference_url,
    notes = EXCLUDED.notes;

-- Vendor-current firmware is guidance for setup. Vendors without a comparable
-- firmware-reference page simply have no current-reference row inserted here.
INSERT INTO ref.controller_firmware_version (
    controller_model_id,
    firmware_version,
    source_note,
    is_current_recommended,
    reference_url
)
SELECT
    m.controller_model_id,
    r.reference_current_firmware,
    'Vendor current firmware reference at Controller Inventory bootstrap',
    true,
    r.firmware_reference_url
FROM stage.controller_model_reference AS r
JOIN ref.controller_model AS m
  ON m.model_code = r.source_model_evidence
WHERE r.reference_current_firmware IS NOT NULL
  AND r.firmware_reference_url IS NOT NULL
ON CONFLICT (controller_model_id, firmware_version) DO UPDATE SET
    is_current_recommended = true,
    reference_url = EXCLUDED.reference_url;

-- Every actually recorded workbook firmware version is retained regardless of
-- whether it appears on a current vendor page. Field verification is later.
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
  ON m.model_code = b.model_evidence
WHERE b.firmware_state_evidence = 'RECORDED'
  AND nullif(btrim(coalesce(b.firmware_evidence, '')), '') IS NOT NULL
ON CONFLICT (controller_model_id, firmware_version) DO UPDATE SET
    source_note = EXCLUDED.source_note,
    is_current_recommended = ref.controller_firmware_version.is_current_recommended
                             OR EXCLUDED.is_current_recommended,
    reference_url = COALESCE(EXCLUDED.reference_url,
                             ref.controller_firmware_version.reference_url);

COMMIT;
