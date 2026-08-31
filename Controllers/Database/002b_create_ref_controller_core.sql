/* ============================================================================
Controller Inventory physical-controller core
Issue: #110

Run only after:
  002_create_ref_controller_sandbox.sql has created/reviewed the permanent
  model and firmware catalogs.

This script creates the empty physical-controller tables but inserts no
controller rows and allocates no controller IDs.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.controller_model') IS NULL
       OR to_regclass('ref.controller_firmware_version') IS NULL THEN
        RAISE EXCEPTION 'Permanent Controller model/firmware catalog is required first';
    END IF;
END
$preflight$;

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

CREATE TABLE IF NOT EXISTS ref.controller (
    controller_id bigint GENERATED ALWAYS AS IDENTITY
        (START WITH 1001 INCREMENT BY 1) PRIMARY KEY,
    controller_model_id integer NOT NULL,
    controller_status_id integer NOT NULL,
    hardware_revision text,
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
        firmware_verification_state IN ('UNKNOWN','RECORDED_UNVERIFIED','VERIFIED')
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
DROP TRIGGER IF EXISTS trg_controller_status_actor_insert ON ref.controller_status;
CREATE TRIGGER trg_controller_status_actor_insert
BEFORE INSERT ON ref.controller_status
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_status_actor_update ON ref.controller_status;
CREATE TRIGGER trg_controller_status_actor_update
BEFORE UPDATE ON ref.controller_status
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

DROP TRIGGER IF EXISTS trg_controller_firmware_history_actor_insert
    ON ref.controller_firmware_history;
CREATE TRIGGER trg_controller_firmware_history_actor_insert
BEFORE INSERT ON ref.controller_firmware_history
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();
DROP TRIGGER IF EXISTS trg_controller_firmware_history_actor_update
    ON ref.controller_firmware_history;
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

COMMIT;

SELECT
    to_regclass('ref.controller') AS controller_table,
    count(*) AS controller_rows
FROM ref.controller
GROUP BY to_regclass('ref.controller');
