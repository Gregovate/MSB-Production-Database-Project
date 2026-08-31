/* ============================================================================
Controller Inventory bootstrap staging
Issue: #110

Purpose:
  Use the existing stage schema as a disposable reconstruction/manipulation
  layer before any permanent ref.controller identity is allocated.

Rules:
  - The current workbook represents deployed controllers only.
  - stage.* rows are evidence, not permanent controller identity.
  - No controller_id is generated here.
  - Permanent Display relationships are reviewed against ref.display.display_id.
  - year_deployed is first-known deployment/use evidence, not manufacture year.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS stage.controller_bootstrap (
    controller_bootstrap_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_file text NOT NULL,
    source_row_num integer NOT NULL,
    display_name_evidence text NOT NULL,
    network_evidence text,
    uid_evidence text,
    model_evidence text NOT NULL,
    firmware_evidence text,
    firmware_state_evidence text NOT NULL DEFAULT 'UNKNOWN_OR_VERIFY',
    controller_type_evidence text,
    stage_scene_evidence text,
    park_location_evidence text,
    for_what_evidence text,

    controller_model_id integer,
    year_deployed integer,
    year_deployed_source text,
    review_state text NOT NULL DEFAULT 'REVIEW_REQUIRED',
    bootstrap_order integer,
    proposed_controller_id integer GENERATED ALWAYS AS (
        CASE WHEN bootstrap_order IS NULL THEN NULL ELSE 1000 + bootstrap_order END
    ) STORED,
    review_notes text,

    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT uq_controller_bootstrap_source UNIQUE (source_file, source_row_num),
    CONSTRAINT ck_controller_bootstrap_review_state CHECK (
        review_state IN ('REVIEW_REQUIRED', 'READY', 'SKIPPED')
    ),
    CONSTRAINT ck_controller_bootstrap_firmware_state CHECK (
        firmware_state_evidence IN ('RECORDED', 'UNKNOWN_OR_VERIFY')
    ),
    CONSTRAINT ck_controller_bootstrap_year CHECK (
        year_deployed IS NULL OR year_deployed BETWEEN 1980 AND 2100
    ),
    CONSTRAINT ck_controller_bootstrap_order CHECK (
        bootstrap_order IS NULL OR bootstrap_order > 0
    ),
    CONSTRAINT uq_controller_bootstrap_order UNIQUE (bootstrap_order),
    CONSTRAINT uq_controller_bootstrap_proposed_id UNIQUE (proposed_controller_id)
);

CREATE TABLE IF NOT EXISTS stage.controller_bootstrap_display (
    controller_bootstrap_id bigint NOT NULL,
    display_id bigint NOT NULL,
    relationship_type text NOT NULL DEFAULT 'SERVES',
    relationship_note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_controller_bootstrap_display
        PRIMARY KEY (controller_bootstrap_id, display_id, relationship_type),
    CONSTRAINT fk_controller_bootstrap_display_candidate
        FOREIGN KEY (controller_bootstrap_id)
        REFERENCES stage.controller_bootstrap(controller_bootstrap_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_controller_bootstrap_display_display
        FOREIGN KEY (display_id)
        REFERENCES ref.display(display_id),
    CONSTRAINT ck_controller_bootstrap_display_type CHECK (
        relationship_type IN ('SERVES', 'WIRING_SOURCE')
    )
);

CREATE INDEX IF NOT EXISTS ix_controller_bootstrap_review_state
    ON stage.controller_bootstrap(review_state);
CREATE INDEX IF NOT EXISTS ix_controller_bootstrap_display_id
    ON stage.controller_bootstrap_display(display_id);

DROP TRIGGER IF EXISTS trg_controller_bootstrap_actor_insert
    ON stage.controller_bootstrap;
CREATE TRIGGER trg_controller_bootstrap_actor_insert
BEFORE INSERT ON stage.controller_bootstrap
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_controller_bootstrap_actor_update
    ON stage.controller_bootstrap;
CREATE TRIGGER trg_controller_bootstrap_actor_update
BEFORE UPDATE ON stage.controller_bootstrap
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

DROP TRIGGER IF EXISTS trg_controller_bootstrap_display_actor_insert
    ON stage.controller_bootstrap_display;
CREATE TRIGGER trg_controller_bootstrap_display_actor_insert
BEFORE INSERT ON stage.controller_bootstrap_display
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_controller_bootstrap_display_actor_update
    ON stage.controller_bootstrap_display;
CREATE TRIGGER trg_controller_bootstrap_display_actor_update
BEFORE UPDATE ON stage.controller_bootstrap_display
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

COMMIT;
