/* ============================================================================
MSB Setup Session — relational core
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-06 V0.1.0

Purpose:
  Establish the reusable Setup task catalog, annual Setup Session state,
  work-day planning, and Setup-specific Container/Display movement state needed
  by the browser-native Setup application.

Authority boundaries:
  - ref.display -> ref.container -> ref.storage_location remains current/master
    Production Database truth. This migration creates no Container assignment
    history and no seasonal Container snapshot.
  - ref.setup_task is reusable Setup knowledge that survives seasons.
  - ops.setup_* objects are annual planning/execution/movement truth.
  - movement state never rewrites ref.display.container_id or
    ref.container.location_code.
  - a Display whose annual position_mode is WITH_CONTAINER follows the current
    Setup position of its current master Container relationship.
  - a Display whose annual position_mode is DETACHED no longer follows later
    Container movement until explicitly reattached/corrected.

Audit:
  Existing ref.set_actor_on_insert() / ref.set_actor_on_update() remain the
  actor/audit authority.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.season') IS NULL
       OR to_regclass('ref.stage') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Required permanent Setup dependencies are missing';
    END IF;

    IF to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit functions are required';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   REUSABLE SETUP KNOWLEDGE
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ref.setup_task (
    setup_task_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_name text NOT NULL,
    stage_id integer,
    task_action_type text NOT NULL DEFAULT 'WORK',
    display_order integer NOT NULL DEFAULT 100,
    active_flag boolean NOT NULL DEFAULT true,
    normal_crew_min integer,
    normal_crew_max integer,
    expected_duration_minutes integer,
    completion_point text,
    readiness_note text,
    weather_note text,
    reusable_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_task_stage
        FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id),
    CONSTRAINT fk_setup_task_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_action_type CHECK (
        task_action_type IN ('WORK', 'UNLOAD_CONTAINER', 'SUPPORT')
    ),
    CONSTRAINT ck_setup_task_display_order CHECK (display_order >= 0),
    CONSTRAINT ck_setup_task_crew_min CHECK (
        normal_crew_min IS NULL OR normal_crew_min >= 0
    ),
    CONSTRAINT ck_setup_task_crew_max CHECK (
        normal_crew_max IS NULL OR normal_crew_max >= 0
    ),
    CONSTRAINT ck_setup_task_crew_range CHECK (
        normal_crew_min IS NULL
        OR normal_crew_max IS NULL
        OR normal_crew_max >= normal_crew_min
    ),
    CONSTRAINT ck_setup_task_duration CHECK (
        expected_duration_minutes IS NULL OR expected_duration_minutes > 0
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_task_stage_order
    ON ref.setup_task(stage_id, display_order, setup_task_id);
CREATE INDEX IF NOT EXISTS ix_setup_task_active
    ON ref.setup_task(active_flag, display_order, setup_task_id);

CREATE TABLE IF NOT EXISTS ref.setup_task_dependency (
    setup_task_id bigint NOT NULL,
    prerequisite_setup_task_id bigint NOT NULL,
    dependency_note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_task_dependency
        PRIMARY KEY (setup_task_id, prerequisite_setup_task_id),
    CONSTRAINT fk_setup_task_dependency_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_dependency_prerequisite
        FOREIGN KEY (prerequisite_setup_task_id)
        REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_dependency_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_dependency_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_dependency_not_self CHECK (
        setup_task_id <> prerequisite_setup_task_id
    )
);

CREATE TABLE IF NOT EXISTS ref.setup_task_display (
    setup_task_id bigint NOT NULL,
    display_id bigint NOT NULL,
    relationship_type text NOT NULL DEFAULT 'REQUIRED',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_task_display PRIMARY KEY (setup_task_id, display_id),
    CONSTRAINT fk_setup_task_display_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_display_display
        FOREIGN KEY (display_id) REFERENCES ref.display(display_id),
    CONSTRAINT fk_setup_task_display_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_display_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_display_relationship CHECK (
        relationship_type IN ('REQUIRED', 'OPTIONAL')
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_task_display_display
    ON ref.setup_task_display(display_id, setup_task_id);

CREATE TABLE IF NOT EXISTS ref.setup_task_container_support (
    setup_task_id bigint NOT NULL,
    container_id integer NOT NULL,
    relationship_type text NOT NULL DEFAULT 'SUPPORT',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_task_container_support
        PRIMARY KEY (setup_task_id, container_id),
    CONSTRAINT fk_setup_task_container_support_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_container_support_container
        FOREIGN KEY (container_id) REFERENCES ref.container(container_id),
    CONSTRAINT fk_setup_task_container_support_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_container_support_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_container_support_relationship CHECK (
        relationship_type IN ('SUPPORT', 'REQUIRED_CONTAINER')
    )
);

CREATE TABLE IF NOT EXISTS ref.setup_task_captain (
    setup_task_id bigint NOT NULL,
    person_id integer NOT NULL,
    captain_role text NOT NULL DEFAULT 'CAPTAIN',
    sort_order integer NOT NULL DEFAULT 100,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_task_captain PRIMARY KEY (setup_task_id, person_id),
    CONSTRAINT fk_setup_task_captain_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_captain_person
        FOREIGN KEY (person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_captain_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_captain_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_captain_role CHECK (
        captain_role IN ('CAPTAIN', 'ALTERNATE', 'ADVISOR')
    )
);

CREATE TABLE IF NOT EXISTS ref.setup_resource (
    setup_resource_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    resource_name text NOT NULL UNIQUE,
    resource_type text NOT NULL DEFAULT 'EQUIPMENT',
    active_flag boolean NOT NULL DEFAULT true,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_resource_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_resource_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_resource_type CHECK (
        resource_type IN ('EQUIPMENT', 'VEHICLE', 'TRAILER', 'TOOL', 'OTHER')
    )
);

CREATE TABLE IF NOT EXISTS ref.setup_task_resource (
    setup_task_id bigint NOT NULL,
    setup_resource_id integer NOT NULL,
    quantity_required integer NOT NULL DEFAULT 1,
    requirement_type text NOT NULL DEFAULT 'REQUIRED',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_task_resource
        PRIMARY KEY (setup_task_id, setup_resource_id),
    CONSTRAINT fk_setup_task_resource_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_task_resource_resource
        FOREIGN KEY (setup_resource_id)
        REFERENCES ref.setup_resource(setup_resource_id),
    CONSTRAINT fk_setup_task_resource_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_resource_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_resource_quantity CHECK (quantity_required > 0),
    CONSTRAINT ck_setup_task_resource_requirement CHECK (
        requirement_type IN ('REQUIRED', 'PREFERRED')
    )
);

/* --------------------------------------------------------------------------
   ANNUAL SETUP SESSION / EXECUTION
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ops.setup_session (
    setup_session_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    season_year integer NOT NULL,
    session_status text NOT NULL DEFAULT 'PLANNING',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT uq_setup_session_season UNIQUE (season_year),
    CONSTRAINT fk_setup_session_season
        FOREIGN KEY (season_year) REFERENCES ref.season(season_year),
    CONSTRAINT fk_setup_session_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_session_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_session_status CHECK (
        session_status IN (
            'HISTORICAL_VERIFICATION',
            'PLANNING',
            'ACTIVE',
            'COMPLETE'
        )
    )
);

CREATE TABLE IF NOT EXISTS ops.setup_session_task (
    setup_session_task_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    setup_task_id bigint NOT NULL,
    included_flag boolean NOT NULL DEFAULT true,
    verification_state text NOT NULL DEFAULT 'UNVERIFIED',
    execution_status text NOT NULL DEFAULT 'NOT_READY',
    planned_date date,
    actual_started_at timestamptz,
    actual_completed_at timestamptz,
    actual_crew_count integer,
    actual_duration_minutes integer,
    plan_change_reason text,
    annual_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT uq_setup_session_task UNIQUE (setup_session_id, setup_task_id),
    CONSTRAINT fk_setup_session_task_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_session_task_task
        FOREIGN KEY (setup_task_id) REFERENCES ref.setup_task(setup_task_id),
    CONSTRAINT fk_setup_session_task_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_session_task_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_session_task_verification CHECK (
        verification_state IN ('UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION')
    ),
    CONSTRAINT ck_setup_session_task_execution CHECK (
        execution_status IN (
            'NOT_READY', 'READY', 'PLANNED', 'IN_PROGRESS',
            'COMPLETE', 'DEFERRED'
        )
    ),
    CONSTRAINT ck_setup_session_task_actual_crew CHECK (
        actual_crew_count IS NULL OR actual_crew_count >= 0
    ),
    CONSTRAINT ck_setup_session_task_actual_duration CHECK (
        actual_duration_minutes IS NULL OR actual_duration_minutes >= 0
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_session_task_status
    ON ops.setup_session_task(setup_session_id, execution_status, planned_date);
CREATE INDEX IF NOT EXISTS ix_setup_session_task_verification
    ON ops.setup_session_task(setup_session_id, verification_state);

CREATE TABLE IF NOT EXISTS ops.setup_work_day (
    setup_work_day_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    work_date date NOT NULL,
    day_status text NOT NULL DEFAULT 'PLANNED',
    weather_note text,
    volunteer_note text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT uq_setup_work_day UNIQUE (setup_session_id, work_date),
    CONSTRAINT fk_setup_work_day_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_work_day_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_work_day_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_work_day_status CHECK (
        day_status IN ('PLANNED', 'ACTIVE', 'COMPLETE', 'CANCELLED')
    )
);

CREATE TABLE IF NOT EXISTS ops.setup_work_day_task (
    setup_work_day_id bigint NOT NULL,
    setup_session_task_id bigint NOT NULL,
    sort_order integer NOT NULL DEFAULT 100,
    planned_crew_count integer,
    actual_crew_count integer,
    started_at timestamptz,
    completed_at timestamptz,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_work_day_task
        PRIMARY KEY (setup_work_day_id, setup_session_task_id),
    CONSTRAINT fk_setup_work_day_task_day
        FOREIGN KEY (setup_work_day_id)
        REFERENCES ops.setup_work_day(setup_work_day_id),
    CONSTRAINT fk_setup_work_day_task_session_task
        FOREIGN KEY (setup_session_task_id)
        REFERENCES ops.setup_session_task(setup_session_task_id),
    CONSTRAINT fk_setup_work_day_task_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_work_day_task_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_work_day_task_planned_crew CHECK (
        planned_crew_count IS NULL OR planned_crew_count >= 0
    ),
    CONSTRAINT ck_setup_work_day_task_actual_crew CHECK (
        actual_crew_count IS NULL OR actual_crew_count >= 0
    )
);

/* --------------------------------------------------------------------------
   SETUP-SPECIFIC MOVEMENT / CURRENT ANNUAL POSITION
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ops.setup_container_state (
    setup_session_id bigint NOT NULL,
    container_id integer NOT NULL,
    current_stage_id integer,
    current_location_note text,
    last_movement_event_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_container_state
        PRIMARY KEY (setup_session_id, container_id),
    CONSTRAINT fk_setup_container_state_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_container_state_container
        FOREIGN KEY (container_id) REFERENCES ref.container(container_id),
    CONSTRAINT fk_setup_container_state_stage
        FOREIGN KEY (current_stage_id) REFERENCES ref.stage(stage_id),
    CONSTRAINT fk_setup_container_state_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_container_state_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id)
);

CREATE TABLE IF NOT EXISTS ops.setup_display_state (
    setup_session_id bigint NOT NULL,
    display_id bigint NOT NULL,
    position_mode text NOT NULL DEFAULT 'WITH_CONTAINER',
    current_stage_id integer,
    current_location_note text,
    verified_present_at timestamptz,
    verified_present_by_person_id integer,
    last_movement_event_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_display_state
        PRIMARY KEY (setup_session_id, display_id),
    CONSTRAINT fk_setup_display_state_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_display_state_display
        FOREIGN KEY (display_id) REFERENCES ref.display(display_id),
    CONSTRAINT fk_setup_display_state_stage
        FOREIGN KEY (current_stage_id) REFERENCES ref.stage(stage_id),
    CONSTRAINT fk_setup_display_state_verified_by
        FOREIGN KEY (verified_present_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_display_state_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_display_state_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_display_state_mode CHECK (
        position_mode IN ('WITH_CONTAINER', 'DETACHED')
    ),
    CONSTRAINT ck_setup_display_state_detached_location CHECK (
        position_mode <> 'DETACHED'
        OR current_stage_id IS NOT NULL
        OR nullif(btrim(current_location_note), '') IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_display_state_mode
    ON ops.setup_display_state(setup_session_id, position_mode, current_stage_id);

CREATE TABLE IF NOT EXISTS ops.setup_movement_event (
    setup_movement_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL,
    event_type text NOT NULL,
    setup_session_task_id bigint,
    container_id integer,
    destination_stage_id integer,
    destination_location_note text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_movement_event_session
        FOREIGN KEY (setup_session_id)
        REFERENCES ops.setup_session(setup_session_id),
    CONSTRAINT fk_setup_movement_event_session_task
        FOREIGN KEY (setup_session_task_id)
        REFERENCES ops.setup_session_task(setup_session_task_id),
    CONSTRAINT fk_setup_movement_event_container
        FOREIGN KEY (container_id) REFERENCES ref.container(container_id),
    CONSTRAINT fk_setup_movement_event_destination_stage
        FOREIGN KEY (destination_stage_id) REFERENCES ref.stage(stage_id),
    CONSTRAINT fk_setup_movement_event_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_movement_event_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_movement_event_type CHECK (
        event_type IN (
            'CONTAINER_MOVE',
            'TASK_UNLOAD',
            'DISPLAY_MOVE',
            'DISPLAY_REATTACH',
            'TASK_COMPLETION_RECONCILE'
        )
    ),
    CONSTRAINT ck_setup_movement_event_destination CHECK (
        destination_stage_id IS NOT NULL
        OR nullif(btrim(destination_location_note), '') IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_movement_event_session_time
    ON ops.setup_movement_event(setup_session_id, occurred_at, setup_movement_event_id);
CREATE INDEX IF NOT EXISTS ix_setup_movement_event_container
    ON ops.setup_movement_event(setup_session_id, container_id, occurred_at);

CREATE TABLE IF NOT EXISTS ops.setup_movement_event_display (
    setup_movement_event_id bigint NOT NULL,
    display_id bigint NOT NULL,
    movement_effect text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_movement_event_display
        PRIMARY KEY (setup_movement_event_id, display_id),
    CONSTRAINT fk_setup_movement_event_display_event
        FOREIGN KEY (setup_movement_event_id)
        REFERENCES ops.setup_movement_event(setup_movement_event_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_setup_movement_event_display_display
        FOREIGN KEY (display_id) REFERENCES ref.display(display_id),
    CONSTRAINT fk_setup_movement_event_display_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_movement_event_display_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_movement_event_display_effect CHECK (
        movement_effect IN ('UNLOADED', 'MOVED', 'REATTACHED', 'VERIFIED_PRESENT')
    )
);

/* Late FKs to event identity avoid create-order cycles. */
ALTER TABLE ops.setup_container_state
    DROP CONSTRAINT IF EXISTS fk_setup_container_state_last_event;
ALTER TABLE ops.setup_container_state
    ADD CONSTRAINT fk_setup_container_state_last_event
    FOREIGN KEY (last_movement_event_id)
    REFERENCES ops.setup_movement_event(setup_movement_event_id);

ALTER TABLE ops.setup_display_state
    DROP CONSTRAINT IF EXISTS fk_setup_display_state_last_event;
ALTER TABLE ops.setup_display_state
    ADD CONSTRAINT fk_setup_display_state_last_event
    FOREIGN KEY (last_movement_event_id)
    REFERENCES ops.setup_movement_event(setup_movement_event_id);

/* --------------------------------------------------------------------------
   STANDARD ACTOR TRIGGERS
   -------------------------------------------------------------------------- */

DO $triggers$
DECLARE
    v_row record;
BEGIN
    FOR v_row IN
        SELECT * FROM (VALUES
            ('ref','setup_task'),
            ('ref','setup_task_dependency'),
            ('ref','setup_task_display'),
            ('ref','setup_task_container_support'),
            ('ref','setup_task_captain'),
            ('ref','setup_resource'),
            ('ref','setup_task_resource'),
            ('ops','setup_session'),
            ('ops','setup_session_task'),
            ('ops','setup_work_day'),
            ('ops','setup_work_day_task'),
            ('ops','setup_container_state'),
            ('ops','setup_display_state'),
            ('ops','setup_movement_event'),
            ('ops','setup_movement_event_display')
        ) AS t(schema_name, table_name)
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON %I.%I',
            'trg_' || v_row.table_name || '_actor_insert',
            v_row.schema_name,
            v_row.table_name
        );
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert()',
            'trg_' || v_row.table_name || '_actor_insert',
            v_row.schema_name,
            v_row.table_name
        );

        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON %I.%I',
            'trg_' || v_row.table_name || '_actor_update',
            v_row.schema_name,
            v_row.table_name
        );
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update()',
            'trg_' || v_row.table_name || '_actor_update',
            v_row.schema_name,
            v_row.table_name
        );
    END LOOP;
END
$triggers$;

COMMENT ON TABLE ref.setup_task IS
'Reusable practical Setup work catalog. Task identity survives renames; annual state belongs in ops.setup_session_task.';
COMMENT ON TABLE ops.setup_session IS
'One annual Setup Session per ref.season. 2025 may be historical verification; later seasons use live planning/execution.';
COMMENT ON TABLE ops.setup_display_state IS
'Annual Setup position state. WITH_CONTAINER follows the Display current master ref.display.container_id; DETACHED stops following later Container moves.';
COMMENT ON TABLE ops.setup_movement_event IS
'Observed/corrective Setup-only movement evidence. Does not create generic Container history or rewrite permanent Container/Display assignments.';

COMMIT;
