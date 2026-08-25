/* ============================================================================
Migration: 0038_allow_spare_to_display_activation.sql
Revision:  2026-08-25-spare-to-display-activation-v1

Purpose:
  Support the normal channel lifecycle in both directions: place a SPARE
  channel into service by assigning it a physical Display name, or return a
  recycled Display channel to SPARE, without nonphysical evidence creating a
  false physical reconciliation result.

Contract:
  - SPARE/PHANTOM rows remain visible and EXCLUDED_NONPHYSICAL.
  - Nonphysical rows do not contribute to physical UUID/name duplicate counts.
  - A SPARE/PHANTOM row cannot classify as a non-active physical Display.
  - Occurrence evidence is scoped by raw UUID and normalized Display name.
  - Nonphysical candidates receive their own nonphysical reconciliation group.
  - Nonphysical rows cannot create physical permanent-identity components.
  - A renamed in-service row follows the normal existing/new Display policy.

Safety:
  - No production Display, Stage, Scene, or snapshot row is changed.
  - Existing frozen reconciliation attempts remain immutable.
  - A new reconciliation attempt is required to use this classification rule.
============================================================================ */

BEGIN;

CREATE OR REPLACE VIEW lor_snap.v_display_reconciliation_source AS
WITH background_rows AS (
    SELECT
        p.import_run_id,
        p.preview_id,
        p.prop_id AS source_prop_id,
        btrim(pr.stage_id) AS preview_stage_id,
        pr.name AS preview_name,
        p.raw_prop_id AS lor_prop_id,
        p.name AS prop_name,
        p.lor_comment AS prop_comment,
        btrim(p.lor_comment) AS display_name,
        upper(btrim(p.lor_comment)) AS display_name_normalized,
        p.string_type,
        p.color,
        (
            p.lor_comment ILIKE '%spare%'
            OR coalesce(p.name, '') ILIKE '%spare%'
            OR coalesce(p.lor_comment, '') ILIKE '%spare%'
        ) AS is_spare,
        (
            p.lor_comment ILIKE '%phantom%'
        ) AS is_phantom
    FROM lor_snap.props AS p
    JOIN lor_snap.previews AS pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE pr.stage_id IS NOT NULL
      AND btrim(pr.stage_id) <> ''
      AND nullif(btrim(p.lor_comment), '') IS NOT NULL
      AND lower(btrim(pr.stage_id)) ~ '^0*[0-9]{1,2}[a-z]?$'
),
scene_rows AS (
    SELECT
        slp.import_run_id,
        slp.preview_id,
        p.prop_id AS source_prop_id,
        btrim(coalesce(slp.scene_stage_id, sc.stage_id)) AS preview_stage_id,
        pr.name AS preview_name,
        slp.raw_prop_id AS lor_prop_id,
        p.name AS prop_name,
        p.lor_comment AS prop_comment,
        btrim(p.lor_comment) AS display_name,
        upper(btrim(p.lor_comment)) AS display_name_normalized,
        p.string_type,
        p.color,
        (
            p.lor_comment ILIKE '%spare%'
            OR coalesce(p.name, '') ILIKE '%spare%'
            OR coalesce(p.lor_comment, '') ILIKE '%spare%'
        ) AS is_spare,
        (
            p.lor_comment ILIKE '%phantom%'
        ) AS is_phantom
    FROM lor_snap.scene_lor_props AS slp
    JOIN lor_snap.props AS p
      ON p.import_run_id = slp.import_run_id
     AND p.prop_id = slp.prop_id
     AND p.raw_prop_id = slp.raw_prop_id
    JOIN lor_snap.previews AS pr
      ON pr.import_run_id = slp.import_run_id
     AND pr.id = slp.preview_id
    LEFT JOIN lor_snap.scenes AS sc
      ON sc.import_run_id = slp.import_run_id
     AND sc.preview_id = slp.preview_id
     AND sc.scene_id = slp.scene_id
    WHERE coalesce(slp.scene_stage_id, sc.stage_id) IS NOT NULL
      AND btrim(coalesce(slp.scene_stage_id, sc.stage_id)) <> ''
      AND nullif(btrim(p.lor_comment), '') IS NOT NULL
      AND lower(btrim(coalesce(slp.scene_stage_id, sc.stage_id)))
            ~ '^0*[0-9]{1,2}[a-z]?$'
      AND pr.name ILIKE '%Master Musical Preview%'
),
combined_rows AS (
    SELECT br.*, 1 AS source_preference
    FROM background_rows AS br

    UNION ALL

    SELECT sr.*, 2 AS source_preference
    FROM scene_rows AS sr
),
source_rows AS (
    SELECT DISTINCT ON (
        cr.import_run_id,
        cr.display_name_normalized,
        cr.lor_prop_id
    )
        cr.import_run_id,
        cr.preview_id,
        cr.source_prop_id,
        cr.preview_stage_id,
        cr.preview_name,
        cr.lor_prop_id,
        cr.prop_name,
        cr.prop_comment,
        cr.display_name,
        cr.display_name_normalized,
        cr.string_type,
        cr.color,
        cr.is_spare,
        cr.is_phantom
    FROM combined_rows AS cr
    ORDER BY
        cr.import_run_id,
        cr.display_name_normalized,
        cr.lor_prop_id,
        cr.source_preference,
        cr.preview_name,
        cr.preview_id
),
uuid_counts AS (
    SELECT
        import_run_id,
        lor_prop_id,
        count(*) FILTER (
            WHERE NOT is_spare AND NOT is_phantom
        )::integer AS lor_uuid_row_count,
        count(DISTINCT display_name_normalized) FILTER (
            WHERE NOT is_spare AND NOT is_phantom
        )::integer AS lor_uuid_name_count
    FROM source_rows
    GROUP BY import_run_id, lor_prop_id
),
name_counts AS (
    SELECT
        import_run_id,
        display_name_normalized,
        count(DISTINCT lor_prop_id) FILTER (
            WHERE NOT is_spare AND NOT is_phantom
        )::integer AS lor_name_uuid_count
    FROM source_rows
    GROUP BY import_run_id, display_name_normalized
)
SELECT
    sr.import_run_id,
    sr.preview_id,
    sr.preview_stage_id,
    sr.preview_name,
    sr.lor_prop_id,
    sr.prop_name,
    sr.prop_comment,
    sr.display_name,
    sr.display_name_normalized,
    sr.string_type,
    sr.color,
    sr.is_spare,
    sr.is_phantom,
    uc.lor_uuid_row_count,
    uc.lor_uuid_name_count,
    nc.lor_name_uuid_count,
    sr.source_prop_id
FROM source_rows AS sr
JOIN uuid_counts AS uc
  ON uc.import_run_id = sr.import_run_id
 AND uc.lor_prop_id = sr.lor_prop_id
JOIN name_counts AS nc
  ON nc.import_run_id = sr.import_run_id
 AND nc.display_name_normalized IS NOT DISTINCT FROM sr.display_name_normalized;

COMMENT ON VIEW lor_snap.v_display_reconciliation_source IS
'Run-aware display candidates canonicalized by normalized display name and raw LOR UUID. SPARE/PHANTOM rows remain visible as excluded evidence but do not contribute to physical UUID/name duplicate counts. source_prop_id identifies the exact canonical snapshot occurrence; lor_prop_id is the preview-independent raw_prop_id proposed for ref.display.';



CREATE OR REPLACE VIEW ops.v_lor_display_reconciliation AS
WITH production AS (
    SELECT
        d.display_id,
        d.lor_prop_id,
        d.display_name,
        upper(btrim(d.display_name)) AS display_name_normalized,
        d.display_status_id,
        ds.display_status_name,
        upper(btrim(ds.display_status_name)) = 'ACTIVE' AS is_active
    FROM ref.display AS d
    JOIN ref.display_status AS ds
      ON ds.display_status_id = d.display_status_id
),
production_counts AS (
    SELECT
        pr.*,
        count(*) OVER (PARTITION BY pr.lor_prop_id)::integer
            AS production_uuid_count,
        count(*) OVER (PARTITION BY pr.display_name_normalized)::integer
            AS production_name_count
    FROM production AS pr
),
source_with_matches AS (
    SELECT
        src.*,
        uuid_match.display_id AS uuid_display_id,
        uuid_match.display_name AS uuid_display_name,
        uuid_match.display_status_id AS uuid_display_status_id,
        uuid_match.display_status_name AS uuid_display_status_name,
        uuid_match.is_active AS uuid_is_active,
        coalesce(uuid_match.production_uuid_count, 0) AS production_uuid_count,
        name_match.display_id AS name_display_id,
        name_match.display_name AS name_display_name,
        name_match.display_status_id AS name_display_status_id,
        name_match.display_status_name AS name_display_status_name,
        name_match.is_active AS name_is_active,
        name_match.lor_prop_id AS name_production_lor_prop_id,
        coalesce(name_match.production_name_count, 0) AS production_name_count
    FROM lor_snap.v_display_reconciliation_source AS src
    LEFT JOIN production_counts AS uuid_match
      ON uuid_match.lor_prop_id = src.lor_prop_id
    LEFT JOIN production_counts AS name_match
      ON name_match.display_name_normalized = src.display_name_normalized
),
occurrence_summary AS (
    SELECT
        o.import_run_id,
        o.lor_prop_id,
        o.display_name_normalized,
        count(*)::integer AS occurrence_count,
        string_agg(
            DISTINCT CASE
                WHEN o.location_type = 'SCENE' THEN
                    format(
                        'preview "%s", scene "%s"',
                        coalesce(o.preview_name, o.preview_id),
                        coalesce(o.scene_name, o.scene_id)
                    )
                ELSE format('preview "%s"', coalesce(o.preview_name, o.preview_id))
            END,
            '; ' ORDER BY CASE
                WHEN o.location_type = 'SCENE' THEN
                    format(
                        'preview "%s", scene "%s"',
                        coalesce(o.preview_name, o.preview_id),
                        coalesce(o.scene_name, o.scene_id)
                    )
                ELSE format('preview "%s"', coalesce(o.preview_name, o.preview_id))
            END
        ) AS location_summary
    FROM lor_snap.v_display_lor_occurrence AS o
    GROUP BY
        o.import_run_id,
        o.lor_prop_id,
        o.display_name_normalized
),
candidate_rows AS (
    SELECT
        swm.import_run_id,
        swm.lor_prop_id,
        swm.display_name AS lor_display_name,
        swm.display_name_normalized AS lor_display_name_normalized,
        swm.preview_id,
        swm.preview_name,
        swm.preview_stage_id,
        coalesce(swm.uuid_display_id, swm.name_display_id) AS display_id,
        coalesce(swm.uuid_display_name, swm.name_display_name) AS production_display_name,
        coalesce(swm.uuid_display_status_id, swm.name_display_status_id)
            AS display_status_id,
        coalesce(swm.uuid_display_status_name, swm.name_display_status_name)
            AS display_status_name,
        coalesce(swm.uuid_is_active, swm.name_is_active) AS is_active,
        swm.lor_uuid_row_count,
        swm.lor_uuid_name_count,
        swm.lor_name_uuid_count,
        swm.production_uuid_count,
        swm.production_name_count,
        swm.uuid_display_id,
        swm.name_display_id,
        coalesce(os.occurrence_count, 0) AS occurrence_count,
        os.location_summary,
        CASE
            WHEN swm.is_spare OR swm.is_phantom
                THEN 'EXCLUDED_NONPHYSICAL'
            WHEN swm.lor_uuid_name_count > 1 OR swm.lor_uuid_row_count > 1
                THEN 'DUPLICATE_LOR_UUID'
            WHEN swm.lor_name_uuid_count > 1
                THEN 'DUPLICATE_LOR_NAME'
            WHEN swm.production_uuid_count > 1
                THEN 'DUPLICATE_PRODUCTION_UUID'
            WHEN swm.production_name_count > 1
                THEN 'DUPLICATE_PRODUCTION_NAME'
            WHEN swm.uuid_display_id IS NOT NULL
             AND swm.uuid_is_active = false
                THEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            WHEN swm.uuid_display_id IS NOT NULL
             AND swm.name_display_id = swm.uuid_display_id
                THEN 'EXACT_MATCH'
            WHEN swm.uuid_display_id IS NOT NULL
             AND swm.name_display_id IS NULL
                THEN 'NAME_CHANGED_SAME_UUID'
            WHEN swm.uuid_display_id IS NULL
             AND swm.name_display_id IS NOT NULL
             AND swm.name_is_active = false
                THEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            WHEN swm.uuid_display_id IS NULL
             AND swm.name_display_id IS NOT NULL
                THEN 'UUID_CHANGED_SAME_NAME'
            WHEN swm.uuid_display_id IS NULL
             AND swm.name_display_id IS NULL
                THEN 'NEW_DISPLAY_CANDIDATE'
            ELSE 'NAME_AND_UUID_CHANGED'
        END AS classification_code,
        swm.source_prop_id
    FROM source_with_matches AS swm
    LEFT JOIN occurrence_summary AS os
      ON os.import_run_id = swm.import_run_id
     AND os.lor_prop_id = swm.lor_prop_id
     AND os.display_name_normalized IS NOT DISTINCT FROM
         swm.display_name_normalized
),
candidate_output AS (
    SELECT
        cr.import_run_id,
        cr.lor_prop_id,
        cr.lor_display_name,
        cr.lor_display_name_normalized,
        cr.preview_id,
        cr.preview_name,
        cr.preview_stage_id,
        cr.display_id,
        cr.production_display_name,
        cr.display_status_id,
        cr.display_status_name,
        cr.is_active,
        cr.lor_uuid_row_count,
        cr.lor_uuid_name_count,
        cr.lor_name_uuid_count,
        cr.production_uuid_count,
        cr.production_name_count,
        cr.uuid_display_id,
        cr.name_display_id,
        cr.occurrence_count,
        cr.location_summary,
        cr.classification_code,
        cr.classification_code NOT IN (
            'EXACT_MATCH',
            'EXCLUDED_NONPHYSICAL'
        )
            AS is_blocking,
        CASE cr.classification_code
            WHEN 'EXACT_MATCH' THEN
                format('Display "%s" matches production display_id %s.', cr.lor_display_name, cr.display_id)
            WHEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR' THEN
                format(
                    'Display "%s" is non-active in PostgreSQL but remains in %s. Correct PostgreSQL status or remove it from LOR.',
                    cr.lor_display_name,
                    coalesce(cr.location_summary, 'the LOR snapshot')
                )
            WHEN 'ACTIVE_DISPLAY_MISSING_FROM_LOR' THEN NULL
            WHEN 'NAME_CHANGED_SAME_UUID' THEN
                format('LOR renamed production display_id %s from "%s" to "%s"; operator approval is required.', cr.display_id, cr.production_display_name, cr.lor_display_name)
            WHEN 'UUID_CHANGED_SAME_NAME' THEN
                format('Display "%s" has a new LOR UUID; operator approval is required for display_id %s.', cr.lor_display_name, cr.display_id)
            WHEN 'NEW_DISPLAY_CANDIDATE' THEN
                format('LOR display "%s" is not present in ref.display; operator approval is required to add it.', cr.lor_display_name)
            WHEN 'EXCLUDED_NONPHYSICAL' THEN
                format('LOR prop "%s" is classified as SPARE or PHANTOM and is excluded from physical-display identity reconciliation.', cr.lor_display_name)
            ELSE
                format('Display "%s" has blocking reconciliation classification %s.', cr.lor_display_name, cr.classification_code)
        END AS operator_message,
        CASE cr.classification_code
            WHEN 'EXACT_MATCH' THEN ARRAY['NONE']::text[]
            WHEN 'EXCLUDED_NONPHYSICAL' THEN ARRAY['NONE']::text[]
            WHEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR' THEN
                ARRAY['CORRECT_POSTGRES_STATUS', 'CORRECT_LOR_AND_REINGEST']::text[]
            WHEN 'ACTIVE_DISPLAY_MISSING_FROM_LOR' THEN
                ARRAY['CORRECT_POSTGRES_STATUS', 'CORRECT_LOR_AND_REINGEST']::text[]
            WHEN 'NAME_CHANGED_SAME_UUID' THEN ARRAY['APPROVE_LOR_RENAME']::text[]
            WHEN 'UUID_CHANGED_SAME_NAME' THEN ARRAY['APPROVE_LOR_UUID_CHANGE']::text[]
            WHEN 'NEW_DISPLAY_CANDIDATE' THEN ARRAY['APPROVE_NEW_LOR_DISPLAY']::text[]
            ELSE ARRAY['CORRECT_LOR_AND_REINGEST', 'DEFER']::text[]
        END AS allowed_resolution_paths,
        cr.source_prop_id
    FROM candidate_rows AS cr
),
run_ids AS (
    SELECT import_run_id FROM lor_snap.import_run
),
missing_active AS (
    SELECT
        r.import_run_id,
        pc.lor_prop_id,
        NULL::text AS lor_display_name,
        NULL::text AS lor_display_name_normalized,
        NULL::text AS preview_id,
        NULL::text AS preview_name,
        NULL::text AS preview_stage_id,
        pc.display_id,
        pc.display_name AS production_display_name,
        pc.display_status_id,
        pc.display_status_name,
        pc.is_active,
        0::integer AS lor_uuid_row_count,
        0::integer AS lor_uuid_name_count,
        0::integer AS lor_name_uuid_count,
        pc.production_uuid_count,
        pc.production_name_count,
        NULL::bigint AS uuid_display_id,
        NULL::bigint AS name_display_id,
        0::integer AS occurrence_count,
        NULL::text AS location_summary,
        'ACTIVE_DISPLAY_MISSING_FROM_LOR'::text AS classification_code,
        true AS is_blocking,
        format(
            'Active PostgreSQL display "%s" (display_id %s) is missing from the authoritative LOR display source. Restore it in LOR or correct its PostgreSQL status.',
            pc.display_name,
            pc.display_id
        ) AS operator_message,
        ARRAY['CORRECT_POSTGRES_STATUS', 'CORRECT_LOR_AND_REINGEST']::text[]
            AS allowed_resolution_paths,
        NULL::text AS source_prop_id
    FROM run_ids AS r
    CROSS JOIN production_counts AS pc
    WHERE pc.is_active
      AND NOT EXISTS (
          SELECT 1
          FROM lor_snap.v_display_reconciliation_source AS src
          WHERE src.import_run_id = r.import_run_id
            AND NOT src.is_spare
            AND NOT src.is_phantom
            AND (
                src.lor_prop_id = pc.lor_prop_id
                OR src.display_name_normalized = pc.display_name_normalized
            )
      )
)
SELECT * FROM candidate_output
UNION ALL
SELECT * FROM missing_active;

COMMENT ON VIEW ops.v_lor_display_reconciliation IS
'Live bidirectional display preflight by explicit import_run_id. SPARE/PHANTOM evidence cannot create a physical duplicate or contribute locations to a renamed in-service Display. Exact matches pass automatically; physical identity, status, duplicate, and missing-display discrepancies block.';



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
        WHERE r.classification_code <> 'EXCLUDED_NONPHYSICAL'
          AND r.uuid_display_id IS NOT NULL
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
                WHEN r.classification_code = 'EXCLUDED_NONPHYSICAL'
                    THEN format('NONPHYSICAL:%s', r.source_prop_id)
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
'Creates a new independent evaluation of the current completed ingest. SPARE/PHANTOM candidates are isolated from physical identity components and groups; older review-stage attempts are superseded with preserved audit evidence.';



REVOKE EXECUTE ON FUNCTION ops.f_start_lor_display_reconciliation(text)
    FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-25-spare-to-display-activation-v1'::text
        AS installed_revision,
    position('FILTER' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0
    AND position('is_spare' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0
    AND position('is_phantom' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0 AS has_physical_only_source_counts,
    position('os.display_name_normalized' IN pg_get_viewdef(
        'ops.v_lor_display_reconciliation'::regclass, true
    )) > 0 AS has_name_scoped_occurrence_evidence,
    position(
        'NONPHYSICAL:%s' IN
        pg_get_functiondef(
            'ops.f_start_lor_display_reconciliation(text)'::regprocedure
        )
    ) > 0 AS has_nonphysical_group_isolation;
