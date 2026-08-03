/* ============================================================================
Object group: Independent, idempotent reconciliation attempts
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
Filename:     0022_make_reconciliation_attempts_independent.sql
Revision:     2026-08-03-independent-reconciliation-attempts-v1

Purpose:
  Allow every Start Reconciliation request to create a new evaluation attempt.
  An interrupted attempt is frozen, reported honestly as SUPERSEDED, and never
  blocks the next attempt. Decisions from an older attempt are audit history
  only and are never inherited by the new evaluation.

Safety boundary:
  - Does not call P1, P2, P3, or P4.
  - Does not change ref data or delete lor_snap data.
  - Requires all decision-required groups to have deliberate terminal actions
    before normal Finish may begin promotion.

Revision history:
  2026-08-03  GAL / OpenAI  Initial independent-attempt lifecycle.
============================================================================ */

BEGIN;

DROP INDEX IF EXISTS ops.ux_lor_reconciliation_one_open_run;

ALTER TABLE ops.lor_reconciliation_run
    DROP CONSTRAINT IF EXISTS ux_lor_reconciliation_run_import;

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_run_import
    ON ops.lor_reconciliation_run (import_run_id, started_at DESC);

ALTER TABLE ops.lor_reconciliation_run
    ADD COLUMN IF NOT EXISTS superseded_at timestamptz,
    ADD COLUMN IF NOT EXISTS superseded_by_run_id bigint
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    ADD COLUMN IF NOT EXISTS supersession_reason text;

ALTER TABLE ops.lor_reconciliation_run
    DROP CONSTRAINT IF EXISTS ck_lor_reconciliation_run_status;
ALTER TABLE ops.lor_reconciliation_run
    ADD CONSTRAINT ck_lor_reconciliation_run_status CHECK (status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING', 'COMPLETED',
        'COMPLETED_WITH_EXCEPTIONS', 'CANCELLED', 'FAILED', 'SUPERSEDED'
    ));

ALTER TABLE ops.lor_reconciliation_run
    DROP CONSTRAINT IF EXISTS ck_lor_reconciliation_run_supersession;
ALTER TABLE ops.lor_reconciliation_run
    ADD CONSTRAINT ck_lor_reconciliation_run_supersession CHECK (
        status <> 'SUPERSEDED'
        OR (
            superseded_at IS NOT NULL
            AND superseded_by_run_id IS NOT NULL
            AND nullif(btrim(supersession_reason), '') IS NOT NULL
        )
    );

ALTER TABLE ops.lor_reconciliation_result
    DROP CONSTRAINT IF EXISTS ck_lor_reconciliation_result_class;
ALTER TABLE ops.lor_reconciliation_result
    ADD CONSTRAINT ck_lor_reconciliation_result_class CHECK (result_class IN (
        'ADDED', 'UPDATED', 'REASSOCIATED', 'STATUS_CHANGED', 'BLOCKED',
        'DEFERRED', 'UNRESOLVED', 'VALIDATION', 'CANCELLED', 'FAILED',
        'REPORT_PUBLISHED', 'SUPERSEDED'
    ));

/*
  Every call builds a new attempt. The advisory lock serializes Start calls;
  older review-stage attempts are closed only after the new run row exists so
  the audit relationship is explicit.
*/
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
    v_old_run record;
    v_old_unresolved integer;
    v_old_deferred integer;
    v_old_blocked integer;
    v_freeze_error text;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

    SELECT cr.import_run_id
      INTO v_import_run_id
    FROM lor_snap.v_current_run AS cr;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'No completed LOR snapshot is available';
    END IF;

    INSERT INTO ops.lor_reconciliation_run (
        import_run_id, status, started_by_application
    ) VALUES (
        v_import_run_id, 'PREFLIGHT', nullif(btrim(p_started_by_application), '')
    )
    RETURNING lor_reconciliation_run_id INTO v_run_id;

    FOR v_old_run IN
        SELECT r.lor_reconciliation_run_id, r.import_run_id
        FROM ops.lor_reconciliation_run AS r
        WHERE r.lor_reconciliation_run_id <> v_run_id
          AND r.status IN (
              'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
              'READY_TO_FINISH'
          )
        ORDER BY r.lor_reconciliation_run_id
        FOR UPDATE
    LOOP
        v_freeze_error := NULL;
        BEGIN
            PERFORM ops.f_freeze_lor_reconciliation_source_evidence(
                v_old_run.lor_reconciliation_run_id
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_freeze_error := SQLERRM;
        END;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id, gr.import_run_id, gr.entity_type,
            gr.logical_group_key, 'UNRESOLVED',
            'SUPERSEDED_WITHOUT_REQUIRED_DECISION',
            coalesce(
                gr.operator_message,
                'Required operator decision was incomplete when a later reconciliation attempt started.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id
          AND gr.effective_resolution_state = 'UNRESOLVED'
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code =
                    'SUPERSEDED_WITHOUT_REQUIRED_DECISION'
          );

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id,
            gr.import_run_id,
            gr.entity_type,
            gr.logical_group_key,
            CASE
                WHEN gr.effective_action_type = 'DEFER'
                    THEN 'DEFERRED'
                ELSE 'BLOCKED'
            END,
            CASE
                WHEN gr.effective_action_type = 'DEFER'
                    THEN 'SUPERSEDED_OPERATOR_DEFERRED'
                ELSE 'SUPERSEDED_OPERATOR_CHANGE_NOT_ACCEPTED'
            END,
            coalesce(
                gr.effective_reason,
                'The operator left production unchanged before this attempt was superseded.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id
          AND gr.effective_action_type IS NOT NULL
          AND gr.effective_action_type IN (
              'DEFER',
              'CORRECT_SOURCE_REQUIRED',
              'RESTORE_TO_LOR_REQUIRED'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code IN (
                    'SUPERSEDED_OPERATOR_DEFERRED',
                    'SUPERSEDED_OPERATOR_CHANGE_NOT_ACCEPTED'
                )
          );

        SELECT
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'UNRESOLVED'
            ),
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'DEFERRED'
            ),
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'BLOCKED'
            )
          INTO v_old_unresolved, v_old_deferred, v_old_blocked
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        ) VALUES (
            v_old_run.lor_reconciliation_run_id,
            v_old_run.import_run_id,
            'RUN',
            v_old_run.lor_reconciliation_run_id::text,
            'SUPERSEDED',
            'SUPERSEDED_BY_LATER_ATTEMPT',
            format(
                'Attempt superseded by reconciliation run %s. Undecided groups: %s. Frozen-source error: %s',
                v_run_id,
                coalesce(v_old_unresolved, 0),
                coalesce(v_freeze_error, 'none')
            ),
            false
        );

        UPDATE ops.lor_reconciliation_run
           SET status = 'SUPERSEDED',
               superseded_at = now(),
               superseded_by_run_id = v_run_id,
               supersession_reason =
                   'A later reconciliation attempt was started.',
               unresolved_count = coalesce(v_old_unresolved, 0),
               deferred_count = coalesce(v_old_deferred, 0),
               blocked_count = coalesce(v_old_blocked, 0),
               failure_message = CASE
                   WHEN v_freeze_error IS NULL THEN failure_message
                   ELSE concat_ws(
                       E'\n', failure_message,
                       'Source evidence freeze failed during supersession: '
                       || v_freeze_error
                   )
               END
         WHERE lor_reconciliation_run_id =
               v_old_run.lor_reconciliation_run_id;
    END LOOP;

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
'Creates a new independent evaluation of the current completed ingest and supersedes, preserves, and reports any interrupted review-stage attempts.';

CREATE OR REPLACE FUNCTION ops.trg_require_terminal_reconciliation_decisions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NEW.status = 'PROMOTING'
       AND OLD.status IS DISTINCT FROM NEW.status
       AND EXISTS (
           SELECT 1
           FROM ops.v_lor_reconciliation_group_review AS gr
           WHERE gr.lor_reconciliation_run_id = NEW.lor_reconciliation_run_id
             AND gr.effective_resolution_state = 'UNRESOLVED'
       ) THEN
        RAISE EXCEPTION
            'Reconciliation run % still has required decisions without a terminal operator outcome',
            NEW.lor_reconciliation_run_id;
    END IF;

    IF NEW.status = 'PROMOTING'
       AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id,
            gr.import_run_id,
            gr.entity_type,
            gr.logical_group_key,
            'BLOCKED',
            'OPERATOR_CHANGE_NOT_ACCEPTED',
            coalesce(
                gr.effective_reason,
                'The operator required source correction and left production unchanged.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id = NEW.lor_reconciliation_run_id
          AND gr.effective_action_type IN (
              'CORRECT_SOURCE_REQUIRED',
              'RESTORE_TO_LOR_REQUIRED'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code = 'OPERATOR_CHANGE_NOT_ACCEPTED'
          );
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_require_terminal_reconciliation_decisions
    ON ops.lor_reconciliation_run;
CREATE TRIGGER trg_require_terminal_reconciliation_decisions
BEFORE UPDATE OF status ON ops.lor_reconciliation_run
FOR EACH ROW
EXECUTE FUNCTION ops.trg_require_terminal_reconciliation_decisions();

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
    )::integer AS unresolved_group_count,
    r.superseded_at,
    r.superseded_by_run_id,
    r.supersession_reason
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
    r.started_by_application,
    r.superseded_at,
    r.superseded_by_run_id,
    r.supersession_reason;

COMMENT ON VIEW ops.v_lor_reconciliation_run_review IS
'One row per independent reconciliation attempt, including supersession lineage and frozen decision-state counts.';

COMMENT ON TABLE ops.lor_reconciliation_run IS
'One durable reconciliation attempt. Multiple attempts may independently evaluate the same import; older decisions never govern a later attempt.';

REVOKE EXECUTE ON FUNCTION
    ops.trg_require_terminal_reconciliation_decisions() FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-03-independent-reconciliation-attempts-v1'::text
        AS installed_revision,
    to_regprocedure('ops.f_start_lor_display_reconciliation(text)')
        IS NOT NULL AS has_independent_start,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'lor_reconciliation_run'
          AND column_name = 'superseded_by_run_id'
    ) AS has_supersession_lineage;
