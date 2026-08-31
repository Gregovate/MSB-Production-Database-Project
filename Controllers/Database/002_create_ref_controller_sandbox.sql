/* ============================================================================
Controller Inventory permanent-shaped sandbox
Issue: #110

Purpose:
  Create the isolated Controller Inventory objects in ref.*. Existing production
  objects are FK targets only; no existing production table depends on these
  objects while the subsystem remains experimental/resettable.

Identity rule:
  ref.controller.controller_id starts at 1001.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS ref.controller_model (
    controller_model_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_code text NOT NULL UNIQUE,
    manufacturer text,
    model_name text,
    device_family text,
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
    is_current_recommended boolean,
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
    serial_number text,
    year_deployed integer,
    current_location_code text,
    is_display_attached boolean NOT NULL DEFAULT false,
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
    verified_at timestamptz NOT NULL DEFAULT now(),
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
        REFERENCES ref.controller_firmware_version(controller_firmware_version_id)
);

INSERT INTO ref.controller_status (controller_status_name, description)
VALUES
    ('DEPLOYED', 'Controller is part of the current deployed show inventory.'),
    ('AVAILABLE', 'Controller exists as unassigned stock.'),
    ('REPAIR', 'Controller is held for repair or troubleshooting.'),
    ('RETIRED', 'Controller identity is retained but the asset is retired.')
ON CONFLICT (controller_status_name) DO NOTHING;

-- Seed only the model codes known from the current controller workbook.
-- Manufacturer/family detail remains nullable until separately verified.
INSERT INTO ref.controller_model (model_code, model_name)
VALUES
    ('32LD-G3', '32LD-G3'),
    ('AlphaPix Flex 48', 'AlphaPix Flex 48'),
    ('CCB100', 'CCB100'),
    ('CF50D', 'CF50D'),
    ('CMB24D', 'CMB24D'),
    ('CTB04-G3', 'CTB04-G3'),
    ('CTB32LG3', 'CTB32LG3'),
    ('Pixcon16', 'Pixcon16'),
    ('Pixie16', 'Pixie16'),
    ('Pixie2', 'Pixie2'),
    ('Pixie2D', 'Pixie2D'),
    ('Pixie4', 'Pixie4'),
    ('Pixie8', 'Pixie8')
ON CONFLICT (model_code) DO NOTHING;

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

COMMIT;
