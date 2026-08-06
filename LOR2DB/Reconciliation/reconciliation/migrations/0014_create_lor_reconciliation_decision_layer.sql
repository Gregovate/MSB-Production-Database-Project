/* ============================================================================
Object group: Persistent LOR reconciliation operator-decision layer
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
Filename:     0014_create_lor_reconciliation_decision_layer.sql

Purpose:
  Persist one captured V7 ingest, its evaluated display candidates, derived
  logical groups, and append-only operator decisions. This is the durable
  backend contract for the future Directus reconciliation review screen.

Safety boundary:
  - Installs ops control objects and persists reconciliation working state.
  - Does not call P1, P2, P3, or P4.
  - Does not insert, update, or delete ref data.
  - Does not alter or delete lor_snap data.
  - Does not contain an import-run number, display name, or stage-specific rule.

Prerequisites:
  - 0011_create_lor_display_reconciliation_preflight_v7.sql
  - 0013_expose_current_raw_prop_identity.sql
  - ref.display.lor_prop_id contains the current raw_prop_id contract.

Revision history:
  2026-08-02  GAL / OpenAI  Initial persistent run, display-candidate,
                           logical-group, append-only action, reassociation
                           assignment, and operator-review implementation.
============================================================================ */

BEGIN;

/* Preserve the obsolete pre-run action table as historical evidence. */
DO $migration$
BEGIN
    IF to_regclass('ops.lor_reconciliation_action') IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_schema = 'ops'
             AND table_name = 'lor_reconciliation_action'
             AND column_name = 'lor_reconciliation_run_id'
       ) THEN
        IF to_regclass('ops.lor_reconciliation_action_legacy') IS NOT NULL THEN
            RAISE EXCEPTION
                'Both current and legacy lor_reconciliation_action tables exist; migration cannot choose safely.';
        END IF;

        ALTER TABLE ops.lor_reconciliation_action
            RENAME TO lor_reconciliation_action_legacy;

        /* Table rename does not rename its identity sequence or indexes. */
        IF to_regclass('ops.lor_reconciliation_action_lor_reconciliation_action_id_seq')
           IS NOT NULL THEN
            ALTER SEQUENCE
                ops.lor_reconciliation_action_lor_reconciliation_action_id_seq
                RENAME TO lor_reconciliation_action_legacy_id_seq;
        END IF;

        IF to_regclass('ops.lor_reconciliation_action_pkey') IS NOT NULL THEN
            ALTER INDEX ops.lor_reconciliation_action_pkey
                RENAME TO lor_reconciliation_action_legacy_pkey;
        END IF;

        IF to_regclass('ops.ux_lor_reconciliation_action_run_decision')
           IS NOT NULL THEN
            ALTER INDEX ops.ux_lor_reconciliation_action_run_decision
                RENAME TO ux_lor_reconciliation_action_legacy_run_decision;
        END IF;

        COMMENT ON TABLE ops.lor_reconciliation_action_legacy IS
        'Historical pre-persistent-run LOR decisions. Retained unchanged for audit; new decisions use ops.lor_reconciliation_action.';
    END IF;
END;
$migration$;

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_run (
    lor_reconciliation_run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    import_run_id bigint NOT NULL,
    status text NOT NULL DEFAULT 'STARTING',
    started_at timestamptz NOT NULL DEFAULT now(),
    started_by text NOT NULL DEFAULT current_user,
    started_by_application text,
    paused_at timestamptz,
    resumed_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,
    failed_at timestamptz,
    structural_failure_count integer NOT NULL DEFAULT 0,
    blocked_count integer NOT NULL DEFAULT 0,
    deferred_count integer NOT NULL DEFAULT 0,
    unresolved_count integer NOT NULL DEFAULT 0,
    validation_state text NOT NULL DEFAULT 'NOT_RUN',
    report_path text,
    report_url text,
    report_published_at timestamptz,
    cancellation_reason text,
    failure_message text,
    CONSTRAINT ux_lor_reconciliation_run_import UNIQUE (import_run_id),
    CONSTRAINT ck_lor_reconciliation_run_status CHECK (status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING', 'COMPLETED',
        'COMPLETED_WITH_EXCEPTIONS', 'CANCELLED', 'FAILED'
    )),
    CONSTRAINT ck_lor_reconciliation_run_validation CHECK (validation_state IN (
        'NOT_RUN', 'PENDING', 'PASSED', 'FAILED'
    )),
    CONSTRAINT ck_lor_reconciliation_run_counts CHECK (
        structural_failure_count >= 0
        AND blocked_count >= 0
        AND deferred_count >= 0
        AND unresolved_count >= 0
    ),
    CONSTRAINT ck_lor_reconciliation_run_cancellation CHECK (
        status <> 'CANCELLED'
        OR (
            cancelled_at IS NOT NULL
            AND nullif(btrim(cancellation_reason), '') IS NOT NULL
        )
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_lor_reconciliation_one_open_run
    ON ops.lor_reconciliation_run ((true))
    WHERE status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING'
    );

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_run_status
    ON ops.lor_reconciliation_run (status, started_at DESC);

COMMENT ON TABLE ops.lor_reconciliation_run IS
'One durable reconciliation attempt. import_run_id is captured once at start and reused by all later phases.';

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_group (
    lor_reconciliation_group_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    entity_type text NOT NULL,
    logical_group_key text NOT NULL,
    group_kind text NOT NULL,
    member_count integer NOT NULL,
    requires_atomic_decision boolean NOT NULL DEFAULT false,
    decision_required boolean NOT NULL DEFAULT false,
    allowed_action_types text[] NOT NULL DEFAULT ARRAY[]::text[],
    operator_message text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_lor_reconciliation_group_run
        FOREIGN KEY (lor_reconciliation_run_id)
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    CONSTRAINT ux_lor_reconciliation_group_key
        UNIQUE (lor_reconciliation_run_id, entity_type, logical_group_key),
    CONSTRAINT ck_lor_reconciliation_group_entity CHECK (entity_type IN (
        'STAGE', 'DISPLAY', 'SCENE', 'SCENE_DISPLAY'
    )),
    CONSTRAINT ck_lor_reconciliation_group_kind CHECK (group_kind IN (
        'SINGLE_CANDIDATE', 'IDENTITY_COMPONENT'
    )),
    CONSTRAINT ck_lor_reconciliation_group_members CHECK (member_count > 0),
    CONSTRAINT ck_lor_reconciliation_group_atomic CHECK (
        NOT requires_atomic_decision OR member_count > 1
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_group_review
    ON ops.lor_reconciliation_group
        (lor_reconciliation_run_id, decision_required, entity_type);

COMMENT ON TABLE ops.lor_reconciliation_group IS
'Data-derived inseparable candidate groups. Operator actions target a group so one identity component cannot be partially resolved.';

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_display_candidate (
    lor_reconciliation_display_candidate_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    source_prop_id text,
    lor_prop_id text,
    display_id bigint,
    uuid_display_id bigint,
    name_display_id bigint,
    classification_code text NOT NULL,
    candidate_class text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean NOT NULL,
    is_blocking boolean NOT NULL,
    allowed_action_types text[] NOT NULL DEFAULT ARRAY[]::text[],
    changed_fields text[] NOT NULL DEFAULT ARRAY[]::text[],
    current_display_name text,
    proposed_display_name text,
    current_stage_id integer,
    proposed_stage_id integer,
    current_string_type text,
    proposed_string_type text,
    current_display_status_id integer,
    preview_id text,
    preview_name text,
    proposed_stage_key text,
    location_summary text,
    operator_message text,
    source_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_lor_reconciliation_display_candidate_run
        FOREIGN KEY (lor_reconciliation_run_id)
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    CONSTRAINT fk_lor_reconciliation_display_candidate_group
        FOREIGN KEY (lor_reconciliation_group_id)
        REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id),
    CONSTRAINT fk_lor_reconciliation_display_candidate_display
        FOREIGN KEY (display_id) REFERENCES ref.display(display_id),
    CONSTRAINT ux_lor_reconciliation_display_candidate
        UNIQUE (lor_reconciliation_run_id, candidate_key),
    CONSTRAINT ck_lor_reconciliation_display_candidate_class CHECK (
        candidate_class IN ('PHYSICAL_DISPLAY', 'EXCLUDED_NONPHYSICAL')
    ),
    CONSTRAINT ck_lor_reconciliation_display_candidate_state CHECK (
        initial_resolution_state IN (
            'AUTO_APPROVED', 'DECISION_REQUIRED', 'BLOCKED', 'EXCLUDED'
        )
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_display_candidate_group
    ON ops.lor_reconciliation_display_candidate (lor_reconciliation_group_id);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_display_candidate_review
    ON ops.lor_reconciliation_display_candidate
        (lor_reconciliation_run_id, decision_required, is_blocking);

COMMENT ON TABLE ops.lor_reconciliation_display_candidate IS
'Frozen display evaluation for one captured ingest. source_prop_id is the exact scoped snapshot row; lor_prop_id is the raw UUID proposed for ref.display.';

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_action (
    lor_reconciliation_action_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint,
    import_run_id bigint NOT NULL,
    action_type text NOT NULL,
    reason text NOT NULL,
    action_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    acted_at timestamptz NOT NULL DEFAULT now(),
    acted_by text NOT NULL DEFAULT current_user,
    acted_by_application text,
    CONSTRAINT fk_lor_reconciliation_action_run
        FOREIGN KEY (lor_reconciliation_run_id)
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    CONSTRAINT fk_lor_reconciliation_action_group
        FOREIGN KEY (lor_reconciliation_group_id)
        REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id),
    CONSTRAINT ck_lor_reconciliation_action_reason
        CHECK (nullif(btrim(reason), '') IS NOT NULL),
    CONSTRAINT ck_lor_reconciliation_action_type CHECK (action_type IN (
        'RENAME_DISPLAY', 'UPDATE_LOR_LINK', 'REASSOCIATE_DISPLAY',
        'ADD_NEW_DISPLAY', 'SET_RETIRED', 'SET_RECYCLED',
        'RESTORE_TO_LOR_REQUIRED', 'CORRECT_SOURCE_REQUIRED',
        'EXCLUDE_NONPHYSICAL', 'DEFER', 'CANCEL_RECONCILIATION'
    )),
    CONSTRAINT ck_lor_reconciliation_action_scope CHECK (
        (action_type = 'CANCEL_RECONCILIATION' AND lor_reconciliation_group_id IS NULL)
        OR
        (action_type <> 'CANCEL_RECONCILIATION' AND lor_reconciliation_group_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_action_group_latest
    ON ops.lor_reconciliation_action
        (lor_reconciliation_group_id, acted_at DESC, lor_reconciliation_action_id DESC);

COMMENT ON TABLE ops.lor_reconciliation_action IS
'Append-only operator decisions. The latest action for a group is effective; prior actions remain immutable audit history.';

CREATE OR REPLACE FUNCTION ops.trg_lor_reconciliation_detail_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    RAISE EXCEPTION
        '%.% is immutable; insert a new audit row or superseding action instead',
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
END;
$function$;

DROP TRIGGER IF EXISTS trg_lor_reconciliation_action_immutable
    ON ops.lor_reconciliation_action;
CREATE TRIGGER trg_lor_reconciliation_action_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_action
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_action_assignment (
    lor_reconciliation_action_assignment_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_action_id bigint NOT NULL,
    lor_reconciliation_display_candidate_id bigint NOT NULL,
    target_display_id bigint NOT NULL,
    CONSTRAINT fk_lor_reconciliation_assignment_action
        FOREIGN KEY (lor_reconciliation_action_id)
        REFERENCES ops.lor_reconciliation_action(lor_reconciliation_action_id),
    CONSTRAINT fk_lor_reconciliation_assignment_candidate
        FOREIGN KEY (lor_reconciliation_display_candidate_id)
        REFERENCES ops.lor_reconciliation_display_candidate(
            lor_reconciliation_display_candidate_id
        ),
    CONSTRAINT fk_lor_reconciliation_assignment_display
        FOREIGN KEY (target_display_id) REFERENCES ref.display(display_id),
    CONSTRAINT ux_lor_reconciliation_assignment_candidate
        UNIQUE (
            lor_reconciliation_action_id,
            lor_reconciliation_display_candidate_id
        ),
    CONSTRAINT ux_lor_reconciliation_assignment_target
        UNIQUE (lor_reconciliation_action_id, target_display_id)
);

COMMENT ON TABLE ops.lor_reconciliation_action_assignment IS
'Complete candidate-to-permanent-display mapping required by an atomic REASSOCIATE_DISPLAY action.';

DROP TRIGGER IF EXISTS trg_lor_reconciliation_action_assignment_immutable
    ON ops.lor_reconciliation_action_assignment;
CREATE TRIGGER trg_lor_reconciliation_action_assignment_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_action_assignment
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_result (
    lor_reconciliation_result_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    entity_type text NOT NULL,
    entity_key text NOT NULL,
    result_class text NOT NULL,
    reason_code text NOT NULL,
    operator_message text NOT NULL,
    committed boolean NOT NULL DEFAULT false,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_lor_reconciliation_result_run
        FOREIGN KEY (lor_reconciliation_run_id)
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    CONSTRAINT ck_lor_reconciliation_result_class CHECK (result_class IN (
        'ADDED', 'UPDATED', 'REASSOCIATED', 'STATUS_CHANGED', 'BLOCKED',
        'DEFERRED', 'UNRESOLVED', 'VALIDATION', 'CANCELLED', 'FAILED',
        'REPORT_PUBLISHED'
    ))
);

COMMENT ON TABLE ops.lor_reconciliation_result IS
'Append-only actual outcomes. Proposed changes are never recorded as committed production results.';

DROP TRIGGER IF EXISTS trg_lor_reconciliation_group_immutable
    ON ops.lor_reconciliation_group;
CREATE TRIGGER trg_lor_reconciliation_group_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_group
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

DROP TRIGGER IF EXISTS trg_lor_reconciliation_display_candidate_immutable
    ON ops.lor_reconciliation_display_candidate;
CREATE TRIGGER trg_lor_reconciliation_display_candidate_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_display_candidate
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

DROP TRIGGER IF EXISTS trg_lor_reconciliation_result_immutable
    ON ops.lor_reconciliation_result;
CREATE TRIGGER trg_lor_reconciliation_result_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_result
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

/* Build and freeze the current display evaluation exactly once. */
CREATE OR REPLACE FUNCTION ops.f_start_lor_display_reconciliation(
    p_started_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_run_id bigint;
    v_decision_count integer;
    v_blocked_count integer;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

    SELECT cr.import_run_id
      INTO v_import_run_id
    FROM lor_snap.v_current_run AS cr;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'No completed LOR snapshot is available';
    END IF;

    SELECT r.lor_reconciliation_run_id
      INTO v_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.import_run_id = v_import_run_id;

    IF v_run_id IS NOT NULL THEN
        RETURN v_run_id;
    END IF;

    INSERT INTO ops.lor_reconciliation_run (
        import_run_id, status, started_by_application
    ) VALUES (
        v_import_run_id, 'PREFLIGHT', nullif(btrim(p_started_by_application), '')
    )
    RETURNING lor_reconciliation_run_id INTO v_run_id;

    BEGIN

    /*
      The temporary working rows exist only inside this atomic builder. The
      durable candidate and group tables are the sole downstream authority.
    */
    CREATE TEMP TABLE pg_temp._lor_display_candidate_build ON COMMIT DROP AS
    WITH RECURSIVE reconciliation AS (
        SELECT v.*
        FROM ops.v_lor_display_reconciliation AS v
        WHERE v.import_run_id = v_import_run_id
    ),
    projected AS (
        SELECT
            r.import_run_id,
            r.source_prop_id,
            d.stage_id AS current_stage_id,
            st.stage_id AS proposed_stage_id,
            d.string_type AS current_string_type,
            raw.string_type AS proposed_string_type,
            ARRAY_REMOVE(ARRAY[
                CASE WHEN r.display_id IS NULL THEN 'new_display' END,
                CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                    THEN 'display_name' END,
                CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                    THEN 'lor_prop_id' END,
                CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id
                    THEN 'stage_id' END,
                CASE WHEN d.string_type IS DISTINCT FROM raw.string_type
                    THEN 'string_type' END
            ]::text[], NULL) AS changed_fields
        FROM reconciliation AS r
        JOIN lor_snap.props AS raw
          ON raw.import_run_id = r.import_run_id
         AND raw.prop_id = r.source_prop_id
         AND raw.raw_prop_id = r.lor_prop_id
        LEFT JOIN ref.display AS d ON d.display_id = r.display_id
        LEFT JOIN ref.stage AS st
          ON st.stage_key = lower(btrim(r.preview_stage_id))
        WHERE nullif(btrim(raw.lor_comment), '') IS NOT NULL
    ),
    identity_edges AS (
        SELECT DISTINCT
            least(r.uuid_display_id, r.name_display_id) AS display_id_a,
            greatest(r.uuid_display_id, r.name_display_id) AS display_id_b
        FROM reconciliation AS r
        WHERE r.uuid_display_id IS NOT NULL
          AND r.name_display_id IS NOT NULL
          AND r.uuid_display_id <> r.name_display_id
    ),
    identity_nodes AS (
        SELECT display_id_a AS display_id FROM identity_edges
        UNION
        SELECT display_id_b AS display_id FROM identity_edges
    ),
    identity_reach AS (
        SELECT n.display_id AS root_display_id, n.display_id
        FROM identity_nodes AS n
        UNION
        SELECT
            ir.root_display_id,
            CASE WHEN ie.display_id_a = ir.display_id
                THEN ie.display_id_b ELSE ie.display_id_a END
        FROM identity_reach AS ir
        JOIN identity_edges AS ie
          ON ie.display_id_a = ir.display_id
          OR ie.display_id_b = ir.display_id
    ),
    identity_components AS (
        SELECT display_id, min(root_display_id) AS component_id
        FROM identity_reach
        GROUP BY display_id
    ),
    classified AS (
        SELECT
            r.*,
            p.current_stage_id,
            p.proposed_stage_id,
            p.current_string_type,
            p.proposed_string_type,
            coalesce(p.changed_fields, ARRAY[]::text[]) AS changed_fields,
            ic.component_id,
            CASE
                WHEN ic.component_id IS NOT NULL
                    THEN format('DISPLAY_IDENTITY:%s', ic.component_id)
                WHEN r.display_id IS NOT NULL
                    THEN format('DISPLAY:%s', r.display_id)
                ELSE format('LOR_PROP:%s', r.lor_prop_id)
            END AS logical_group_key
        FROM reconciliation AS r
        LEFT JOIN projected AS p
          ON p.import_run_id = r.import_run_id
         AND p.source_prop_id = r.source_prop_id
        LEFT JOIN identity_components AS ic ON ic.display_id = r.display_id
    ),
    grouped AS (
        SELECT
            c.*,
            count(*) OVER (PARTITION BY c.logical_group_key)::integer
                AS group_member_count,
            bool_or(c.classification_code = 'NAME_AND_UUID_CHANGED') OVER (
                PARTITION BY c.logical_group_key
            ) AS atomic_identity_group
        FROM classified AS c
    )
    SELECT
        g.*,
        CASE
            WHEN g.source_prop_id IS NOT NULL
                THEN format('PROP:%s', g.source_prop_id)
            ELSE format('MISSING_DISPLAY:%s', g.display_id)
        END AS candidate_key,
        CASE WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL'
            THEN 'EXCLUDED_NONPHYSICAL' ELSE 'PHYSICAL_DISPLAY' END
            AS candidate_class,
        CASE
            WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL' THEN 'EXCLUDED'
            WHEN g.atomic_identity_group THEN 'DECISION_REQUIRED'
            WHEN g.classification_code = 'EXACT_MATCH' THEN 'AUTO_APPROVED'
            WHEN g.classification_code IN (
                'NAME_CHANGED_SAME_UUID', 'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE', 'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN 'DECISION_REQUIRED'
            ELSE 'BLOCKED'
        END AS initial_resolution_state,
        CASE
            WHEN g.atomic_identity_group THEN true
            WHEN g.classification_code IN (
                'EXACT_MATCH', 'EXCLUDED_NONPHYSICAL'
            ) THEN false
            WHEN g.classification_code IN (
                'NAME_CHANGED_SAME_UUID', 'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE', 'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN true
            ELSE true
        END AS persistent_decision_required,
        CASE
            WHEN g.atomic_identity_group THEN ARRAY[
                'REASSOCIATE_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER'
            ]::text[]
            WHEN g.classification_code = 'EXACT_MATCH'
             AND cardinality(g.changed_fields) > 0
                THEN ARRAY['DEFER']::text[]
            WHEN g.classification_code = 'NAME_CHANGED_SAME_UUID'
                THEN ARRAY['RENAME_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'UUID_CHANGED_SAME_NAME'
                THEN ARRAY['UPDATE_LOR_LINK', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'NEW_DISPLAY_CANDIDATE'
                THEN ARRAY['ADD_NEW_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
                THEN ARRAY[
                    'SET_RETIRED', 'SET_RECYCLED',
                    'RESTORE_TO_LOR_REQUIRED', 'DEFER'
                ]::text[]
            WHEN g.classification_code = 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
                THEN ARRAY['CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL'
                THEN ARRAY[]::text[]
            ELSE ARRAY['CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
        END AS persistent_allowed_actions
    FROM grouped AS g;

    INSERT INTO ops.lor_reconciliation_group (
        lor_reconciliation_run_id,
        import_run_id,
        entity_type,
        logical_group_key,
        group_kind,
        member_count,
        requires_atomic_decision,
        decision_required,
        allowed_action_types,
        operator_message
    )
    SELECT
        v_run_id,
        v_import_run_id,
        'DISPLAY',
        b.logical_group_key,
        CASE WHEN bool_or(b.atomic_identity_group)
            THEN 'IDENTITY_COMPONENT' ELSE 'SINGLE_CANDIDATE' END,
        count(*)::integer,
        bool_or(b.atomic_identity_group),
        bool_or(b.persistent_decision_required),
        CASE
            WHEN bool_or(b.atomic_identity_group) THEN
                ARRAY['REASSOCIATE_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            ELSE (
                SELECT b_one.persistent_allowed_actions
                FROM pg_temp._lor_display_candidate_build AS b_one
                WHERE b_one.logical_group_key = b.logical_group_key
                ORDER BY b_one.candidate_key
                LIMIT 1
            )
        END,
        CASE
            WHEN bool_or(b.atomic_identity_group) THEN format(
                'Resolve or defer all %s members of this identity dependency group atomically.',
                count(*)
            )
            ELSE max(b.operator_message)
        END
    FROM pg_temp._lor_display_candidate_build AS b
    GROUP BY b.logical_group_key;

    INSERT INTO ops.lor_reconciliation_display_candidate (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        candidate_key,
        source_prop_id,
        lor_prop_id,
        display_id,
        uuid_display_id,
        name_display_id,
        classification_code,
        candidate_class,
        initial_resolution_state,
        decision_required,
        is_blocking,
        allowed_action_types,
        changed_fields,
        current_display_name,
        proposed_display_name,
        current_stage_id,
        proposed_stage_id,
        current_string_type,
        proposed_string_type,
        current_display_status_id,
        preview_id,
        preview_name,
        proposed_stage_key,
        location_summary,
        operator_message,
        source_evidence
    )
    SELECT
        v_run_id,
        rg.lor_reconciliation_group_id,
        v_import_run_id,
        b.candidate_key,
        b.source_prop_id,
        b.lor_prop_id,
        b.display_id,
        b.uuid_display_id,
        b.name_display_id,
        b.classification_code,
        b.candidate_class,
        b.initial_resolution_state,
        b.persistent_decision_required,
        b.initial_resolution_state IN ('DECISION_REQUIRED', 'BLOCKED'),
        b.persistent_allowed_actions,
        b.changed_fields,
        b.production_display_name,
        b.lor_display_name,
        b.current_stage_id,
        b.proposed_stage_id,
        b.current_string_type,
        b.proposed_string_type,
        b.display_status_id,
        b.preview_id,
        b.preview_name,
        b.preview_stage_id,
        b.location_summary,
        CASE WHEN b.atomic_identity_group THEN format(
            'This candidate is one of %s members in %s. Record one complete group decision.',
            b.group_member_count,
            b.logical_group_key
        ) ELSE b.operator_message END,
        jsonb_build_object(
            'lor_uuid_row_count', b.lor_uuid_row_count,
            'lor_uuid_name_count', b.lor_uuid_name_count,
            'lor_name_uuid_count', b.lor_name_uuid_count,
            'production_uuid_count', b.production_uuid_count,
            'production_name_count', b.production_name_count,
            'occurrence_count', b.occurrence_count
        )
    FROM pg_temp._lor_display_candidate_build AS b
    JOIN ops.lor_reconciliation_group AS rg
      ON rg.lor_reconciliation_run_id = v_run_id
     AND rg.entity_type = 'DISPLAY'
     AND rg.logical_group_key = b.logical_group_key;

    SELECT
        count(*) FILTER (WHERE g.decision_required),
        count(*) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM ops.lor_reconciliation_display_candidate AS c
                WHERE c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
                  AND c.initial_resolution_state = 'BLOCKED'
            )
        )
      INTO v_decision_count, v_blocked_count
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_run_id = v_run_id;

    UPDATE ops.lor_reconciliation_run
       SET status = CASE WHEN v_decision_count > 0 OR v_blocked_count > 0
                         THEN 'AWAITING_DECISIONS'
                         ELSE 'READY_TO_FINISH' END,
           paused_at = CASE WHEN v_decision_count > 0 OR v_blocked_count > 0
                            THEN now() ELSE NULL END,
           blocked_count = v_blocked_count,
           unresolved_count = v_decision_count
     WHERE lor_reconciliation_run_id = v_run_id;

        RETURN v_run_id;
    EXCEPTION
        WHEN OTHERS THEN
            UPDATE ops.lor_reconciliation_run
               SET status = 'FAILED',
                   failed_at = now(),
                   failure_message = SQLERRM,
                   structural_failure_count = structural_failure_count + 1
             WHERE lor_reconciliation_run_id = v_run_id;
            RETURN v_run_id;
    END;
END;
$function$;

COMMENT ON FUNCTION ops.f_start_lor_display_reconciliation(text) IS
'Captures lor_snap.v_current_run once and persists the generic display candidate/group evaluation. Repeated calls for the same ingest return the existing reconciliation run.';

CREATE OR REPLACE FUNCTION ops.f_record_lor_reconciliation_action(
    p_lor_reconciliation_run_id bigint,
    p_lor_reconciliation_group_id bigint,
    p_action_type text,
    p_reason text,
    p_reassociation_map jsonb DEFAULT NULL,
    p_acted_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_allowed_actions text[];
    v_action_id bigint;
    v_member_count integer;
    v_mapping_count integer;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('AWAITING_DECISIONS', 'READY_TO_FINISH') THEN
        RAISE EXCEPTION 'Reconciliation run % does not accept decisions in status %',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT g.allowed_action_types, g.member_count
      INTO v_allowed_actions, v_member_count
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
      AND g.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group % does not belong to reconciliation run %',
            p_lor_reconciliation_group_id, p_lor_reconciliation_run_id;
    END IF;

    IF NOT (p_action_type = ANY(v_allowed_actions)) THEN
        RAISE EXCEPTION 'Action % is not allowed for group %; allowed actions are %',
            p_action_type, p_lor_reconciliation_group_id, v_allowed_actions;
    END IF;

    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'A nonblank operator reason is required';
    END IF;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        IF p_reassociation_map IS NULL
           OR jsonb_typeof(p_reassociation_map) <> 'object' THEN
            RAISE EXCEPTION
                'REASSOCIATE_DISPLAY requires a JSON object mapping every candidate ID to one target display_id';
        END IF;

        SELECT count(*)::integer
          INTO v_mapping_count
        FROM jsonb_each_text(p_reassociation_map);

        IF v_mapping_count <> v_member_count THEN
            RAISE EXCEPTION
                'Reassociation map has % members; group % requires exactly %',
                v_mapping_count, p_lor_reconciliation_group_id, v_member_count;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
            LEFT JOIN ops.lor_reconciliation_display_candidate AS c
              ON c.lor_reconciliation_display_candidate_id =
                    m.candidate_id::bigint
             AND c.lor_reconciliation_group_id = p_lor_reconciliation_group_id
            LEFT JOIN ref.display AS d ON d.display_id = m.target_id::bigint
            WHERE c.lor_reconciliation_display_candidate_id IS NULL
               OR d.display_id IS NULL
        ) THEN
            RAISE EXCEPTION
                'Reassociation map contains a candidate outside group % or an unknown target display_id',
                p_lor_reconciliation_group_id;
        END IF;

        IF (
            SELECT count(DISTINCT m.target_id::bigint)
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
        ) <> v_member_count THEN
            RAISE EXCEPTION
                'Each reassociation member must map to a different permanent display_id';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
            WHERE NOT EXISTS (
                SELECT 1
                FROM ops.lor_reconciliation_display_candidate AS member
                WHERE member.lor_reconciliation_group_id =
                        p_lor_reconciliation_group_id
                  AND m.target_id::bigint IN (
                        member.display_id,
                        member.uuid_display_id,
                        member.name_display_id
                  )
            )
        ) THEN
            RAISE EXCEPTION
                'A reassociation target is not part of the derived identity component';
        END IF;
    ELSIF p_reassociation_map IS NOT NULL THEN
        RAISE EXCEPTION 'Only REASSOCIATE_DISPLAY accepts a reassociation map';
    END IF;

    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        action_type,
        reason,
        action_payload,
        acted_by_application
    ) VALUES (
        p_lor_reconciliation_run_id,
        p_lor_reconciliation_group_id,
        v_import_run_id,
        p_action_type,
        btrim(p_reason),
        CASE WHEN p_reassociation_map IS NULL
             THEN '{}'::jsonb
             ELSE jsonb_build_object('reassociation_map', p_reassociation_map)
        END,
        nullif(btrim(p_acted_by_application), '')
    )
    RETURNING lor_reconciliation_action_id INTO v_action_id;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        INSERT INTO ops.lor_reconciliation_action_assignment (
            lor_reconciliation_action_id,
            lor_reconciliation_display_candidate_id,
            target_display_id
        )
        SELECT
            v_action_id,
            m.candidate_id::bigint,
            m.target_id::bigint
        FROM jsonb_each_text(p_reassociation_map)
            AS m(candidate_id, target_id);
    END IF;

    /* Refresh durable run counters from the latest action for every group. */
    WITH latest_action AS (
        SELECT DISTINCT ON (a.lor_reconciliation_group_id)
            a.lor_reconciliation_group_id,
            a.action_type
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND a.lor_reconciliation_group_id IS NOT NULL
        ORDER BY
            a.lor_reconciliation_group_id,
            a.acted_at DESC,
            a.lor_reconciliation_action_id DESC
    ),
    counts AS (
        SELECT
            count(*) FILTER (
                WHERE g.decision_required
                  AND la.lor_reconciliation_group_id IS NULL
            )::integer AS unresolved_count,
            count(*) FILTER (
                WHERE la.action_type = 'DEFER'
            )::integer AS deferred_count,
            count(*) FILTER (
                WHERE la.action_type IN (
                    'CORRECT_SOURCE_REQUIRED', 'RESTORE_TO_LOR_REQUIRED'
                )
                   OR (
                        la.lor_reconciliation_group_id IS NULL
                    AND EXISTS (
                        SELECT 1
                        FROM ops.lor_reconciliation_display_candidate AS c
                        WHERE c.lor_reconciliation_group_id =
                                g.lor_reconciliation_group_id
                          AND c.initial_resolution_state = 'BLOCKED'
                    )
                   )
            )::integer AS blocked_count
        FROM ops.lor_reconciliation_group AS g
        LEFT JOIN latest_action AS la
          ON la.lor_reconciliation_group_id = g.lor_reconciliation_group_id
        WHERE g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    )
    UPDATE ops.lor_reconciliation_run AS r
       SET unresolved_count = counts.unresolved_count,
           deferred_count = counts.deferred_count,
           blocked_count = counts.blocked_count,
           status = CASE WHEN counts.unresolved_count = 0
                         THEN 'READY_TO_FINISH'
                         ELSE 'AWAITING_DECISIONS' END,
           resumed_at = now(),
           paused_at = CASE WHEN counts.unresolved_count > 0
                            THEN coalesce(r.paused_at, now()) ELSE r.paused_at END
    FROM counts
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    RETURN v_action_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_record_lor_reconciliation_action(
    bigint, bigint, text, text, jsonb, text
) IS
'Records one append-only group action. Atomic reassociation is rejected unless every persisted group member has one valid permanent display target.';

CREATE OR REPLACE FUNCTION ops.f_record_lor_reconciliation_bulk_action(
    p_lor_reconciliation_run_id bigint,
    p_lor_reconciliation_group_ids bigint[],
    p_action_type text,
    p_reason text,
    p_acted_by_application text DEFAULT NULL
)
RETURNS TABLE (
    lor_reconciliation_group_id bigint,
    lor_reconciliation_action_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_group_id bigint;
BEGIN
    IF p_lor_reconciliation_group_ids IS NULL
       OR cardinality(p_lor_reconciliation_group_ids) = 0 THEN
        RAISE EXCEPTION 'At least one logical group is required';
    END IF;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        RAISE EXCEPTION
            'Atomic reassociation requires an individual complete mapping and cannot use the bulk-action function';
    END IF;

    IF cardinality(p_lor_reconciliation_group_ids)
       <> (
            SELECT count(DISTINCT selected_group_id)
            FROM unnest(p_lor_reconciliation_group_ids)
                AS selected(selected_group_id)
          ) THEN
        RAISE EXCEPTION 'The logical-group selection contains duplicate IDs';
    END IF;

    FOREACH v_group_id IN ARRAY p_lor_reconciliation_group_ids
    LOOP
        lor_reconciliation_group_id := v_group_id;
        lor_reconciliation_action_id :=
            ops.f_record_lor_reconciliation_action(
                p_lor_reconciliation_run_id,
                v_group_id,
                p_action_type,
                p_reason,
                NULL,
                p_acted_by_application
            );
        RETURN NEXT;
    END LOOP;
END;
$function$;

COMMENT ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(
    bigint, bigint[], text, text, text
) IS
'Records the same permitted action for an operator-selected set of independent logical groups in one transaction. Atomic reassociation remains group-specific.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_group_review AS
WITH latest_action AS (
    SELECT DISTINCT ON (a.lor_reconciliation_group_id)
        a.lor_reconciliation_group_id,
        a.lor_reconciliation_action_id,
        a.action_type,
        a.reason,
        a.acted_at,
        a.acted_by,
        a.acted_by_application
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY
        a.lor_reconciliation_group_id,
        a.acted_at DESC,
        a.lor_reconciliation_action_id DESC
)
SELECT
    g.lor_reconciliation_group_id,
    g.lor_reconciliation_run_id,
    g.import_run_id,
    g.entity_type,
    g.logical_group_key,
    g.group_kind,
    g.member_count,
    g.requires_atomic_decision,
    g.decision_required,
    g.allowed_action_types,
    g.operator_message,
    la.lor_reconciliation_action_id AS effective_action_id,
    la.action_type AS effective_action_type,
    la.reason AS effective_reason,
    la.acted_at,
    la.acted_by,
    la.acted_by_application,
    CASE
        WHEN la.action_type = 'DEFER' THEN 'DEFERRED'
        WHEN la.action_type = 'CORRECT_SOURCE_REQUIRED' THEN 'BLOCKED'
        WHEN la.action_type IS NOT NULL THEN 'APPROVED'
        WHEN g.decision_required THEN 'UNRESOLVED'
        ELSE 'AUTO_APPROVED'
    END AS effective_resolution_state
FROM ops.lor_reconciliation_group AS g
LEFT JOIN latest_action AS la
  ON la.lor_reconciliation_group_id = g.lor_reconciliation_group_id;

COMMENT ON VIEW ops.v_lor_reconciliation_group_review IS
'One row per persisted logical group with its latest append-only action and effective review state.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_operator_display_review AS
SELECT
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.group_kind,
    gr.member_count,
    gr.requires_atomic_decision,
    gr.effective_resolution_state,
    gr.allowed_action_types,
    gr.effective_action_type,
    gr.effective_reason,
    c.lor_reconciliation_display_candidate_id,
    c.classification_code,
    c.changed_fields,
    c.current_display_name,
    c.proposed_display_name,
    current_stage.stage_key AS current_stage_key,
    current_stage.stage_name AS current_stage_name,
    c.proposed_stage_key,
    proposed_stage.stage_name AS proposed_stage_name,
    c.preview_name,
    c.location_summary,
    c.current_string_type,
    c.proposed_string_type,
    c.operator_message,
    c.display_id,
    c.source_prop_id,
    c.lor_prop_id,
    c.uuid_display_id,
    c.name_display_id,
    c.source_evidence
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_display_candidate AS c
  ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
LEFT JOIN ref.stage AS current_stage
  ON current_stage.stage_id = c.current_stage_id
LEFT JOIN ref.stage AS proposed_stage
  ON proposed_stage.stage_id = c.proposed_stage_id
WHERE c.candidate_class <> 'EXCLUDED_NONPHYSICAL'
  AND (
      cardinality(c.changed_fields) > 0
      OR c.decision_required
      OR c.is_blocking
      OR gr.effective_action_type IS NOT NULL
  );

COMMENT ON VIEW ops.v_lor_reconciliation_operator_display_review IS
'Directus-ready persisted display review rows. Internal IDs remain available for safe action calls; production writes are not performed.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_run_review AS
SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.started_at,
    r.started_by,
    r.started_by_application,
    count(DISTINCT g.lor_reconciliation_group_id)::integer
        AS logical_group_count,
    count(c.*)::integer AS display_candidate_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'AUTO_APPROVED'
    )::integer AS auto_approved_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'APPROVED'
    )::integer AS approved_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'DEFERRED'
    )::integer AS deferred_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'BLOCKED'
    )::integer AS blocked_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'UNRESOLVED'
    )::integer AS unresolved_group_count
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_group AS g
  ON g.lor_reconciliation_run_id = r.lor_reconciliation_run_id
LEFT JOIN ops.v_lor_reconciliation_group_review AS gr
  ON gr.lor_reconciliation_group_id = g.lor_reconciliation_group_id
LEFT JOIN ops.lor_reconciliation_display_candidate AS c
  ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
GROUP BY
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.started_at,
    r.started_by,
    r.started_by_application;

COMMENT ON VIEW ops.v_lor_reconciliation_run_review IS
'One-row persisted reconciliation summary for operator status and validation. Counts come from frozen candidates and effective decisions.';

REVOKE EXECUTE ON FUNCTION ops.f_start_lor_display_reconciliation(text)
    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_record_lor_reconciliation_action(
    bigint, bigint, text, text, jsonb, text
) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(
    bigint, bigint[], text, text, text
) FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-02-persistent-operator-decision-layer-v1'::text
        AS installed_revision,
    to_regclass('ops.lor_reconciliation_run') IS NOT NULL AS has_run_table,
    to_regclass('ops.lor_reconciliation_group') IS NOT NULL AS has_group_table,
    to_regclass('ops.lor_reconciliation_display_candidate') IS NOT NULL
        AS has_display_candidate_table,
    to_regclass('ops.lor_reconciliation_action') IS NOT NULL AS has_action_table,
    to_regprocedure('ops.f_start_lor_display_reconciliation(text)') IS NOT NULL
        AS has_start_function,
    to_regprocedure(
        'ops.f_record_lor_reconciliation_action(bigint,bigint,text,text,jsonb,text)'
    ) IS NOT NULL AS has_action_function,
    to_regprocedure(
        'ops.f_record_lor_reconciliation_bulk_action(bigint,bigint[],text,text,text)'
    ) IS NOT NULL AS has_bulk_action_function;
