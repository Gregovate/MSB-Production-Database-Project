/*
Schema: lor_snap / ops / ref
Object: Latest-ingest P2 display identity gate
Filename: 08_latest_ingest_p2_display_identity_gate.sql
Type: Read-only production preflight gate
Owner: msbadmin

Purpose:
  Perform the authoritative two-way identity comparison between the current
  LOR snapshot and permanent production display rows before P2 is authorized.

  The gate identifies:
  - current physical LOR displays that already match ref.display;
  - same physical display with a changed LOR UUID;
  - same established LOR UUID with a changed display name;
  - confirmed new-display candidates;
  - active production displays missing from current LOR;
  - non-active production displays still present in current LOR;
  - duplicate or conflicting identity evidence;
  - SPARE and PHANTOM rows excluded from ref.display.

Production row preservation contract:
  This gate is SELECT-only and changes nothing.

  A later approved P2 operation may update only the LOR-owned fields shared
  between the current snapshot and an existing ref.display row:

      lor_prop_id
      display_name
      stage_id
      string_type

  The existing display_id and every PostgreSQL/Directus-owned field and
  relationship must be preserved. In particular, ordinary LOR reconciliation
  must not overwrite inventory_type, display_status_id, designer_id, theme_id,
  frame_id, container_id, year_built, amps_measured, est_light_count,
  dumb_controller, notes, label_required, or creation/person audit fields.

  display_status_id may change only through an explicit approved lifecycle
  decision. A confirmed new physical display is the only case that creates a
  new ref.display row and new display_id.

Gate behavior:
  - Exact identity matches with no projected field changes require no action.
  - Exact identity matches with projected stage or string-type changes remain
    visible and available for DEFER; identity equality does not hide writes.
  - SPARE/PHANTOM rows pass without ref.display writes.
  - Preview movement does not alter LOR identity because reconciliation uses
    unscoped raw_prop_id rather than preview-scoped prop_id.
  - Identity changes and lifecycle discrepancies require operator review.
  - Duplicate or structurally conflicting evidence is blocking and normally
    requires LOR or PostgreSQL correction before a new ingest or re-evaluation.
  - Deferred candidates remain unchanged and are excluded from later P2 writes.
  - Unrelated approved candidates may proceed after all required decisions are
    recorded; the gate does not prohibit valid non-destructive changes.

Safety:
  SELECT only. Does not call P2, create objects, record decisions, or modify
  lor_snap, ref, or ops data.

Result:
  Returns one SUMMARY row followed by only the candidates requiring review or
  correction. Unchanged exact matches and excluded nonphysical rows are counted
  in the summary but omitted from detail. Exact identity matches with projected
  field changes are included.

Revision History:
  2026-08-02  GAL / OpenAI  Exclude nonphysical rows from projected-change
                           totals and derive atomic identity dependency groups
                           from the same generic UUID/name graph used by 04.
  2026-08-02  GAL / OpenAI  Removed a redundant second evaluation of the
                           canonical source view; read string_type from the
                           already exact-matched raw prop row.
  2026-08-02  GAL / OpenAI  Added field-level projected-change detection so
                           EXACT_MATCH no longer hides production updates;
                           removed color from LOR reconciliation authority.
  2026-08-02  GAL / OpenAI  Include scoped source_prop_id separately from the
                           raw lor_prop_id production association.
  2026-08-02  GAL / OpenAI  Use raw_prop_id as preview-independent LOR identity
                           and remove the obsolete preview-relocation class.
  2026-08-01  GAL / OpenAI  Replaced the procedure-definition audit with the
                           required two-way production identity preflight gate.
  2026-08-01  GAL / OpenAI  Documented the shared-field ownership boundary and
                           preservation of all Directus-owned display metadata.
*/

WITH RECURSIVE current_run AS (
    SELECT import_run_id, run_ts, notes
    FROM lor_snap.v_current_run
),
reconciliation AS (
    SELECT v.*
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr
      ON cr.import_run_id = v.import_run_id
),
projected_changes AS (
    SELECT
        r.import_run_id,
        r.source_prop_id,
        d.stage_id AS current_stage_id,
        st.stage_id AS proposed_stage_id,
        d.string_type AS current_string_type,
        raw.string_type AS proposed_string_type,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN r.display_id IS NULL THEN 'new_display' END,
            CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name THEN 'display_name' END,
            CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id THEN 'lor_prop_id' END,
            CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id THEN 'stage_id' END,
            CASE WHEN d.string_type IS DISTINCT FROM raw.string_type THEN 'string_type' END
        ]::text[], NULL) AS changed_fields
    FROM reconciliation AS r
    JOIN lor_snap.props AS raw
      ON raw.import_run_id = r.import_run_id
     AND raw.prop_id = r.source_prop_id
     AND raw.raw_prop_id = r.lor_prop_id
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    WHERE nullif(btrim(raw.lor_comment), '') IS NOT NULL
),
classified AS (
    SELECT
        r.*,
        pc.current_stage_id,
        pc.proposed_stage_id,
        pc.current_string_type,
        pc.proposed_string_type,
        coalesce(pc.changed_fields, ARRAY[]::text[]) AS changed_fields,
        CASE
            WHEN r.classification_code = 'EXCLUDED_NONPHYSICAL' THEN 'PASS'
            WHEN r.classification_code = 'EXACT_MATCH'
             AND cardinality(coalesce(pc.changed_fields, ARRAY[]::text[])) = 0
                THEN 'PASS'
            WHEN r.classification_code = 'NAME_AND_UUID_CHANGED'
                THEN 'BLOCKED'
            WHEN r.classification_code = 'EXACT_MATCH'
             AND cardinality(coalesce(pc.changed_fields, ARRAY[]::text[])) > 0
                THEN 'PROJECTED_CHANGE'
            WHEN r.classification_code IN (
                'NAME_CHANGED_SAME_UUID',
                'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE',
                'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN 'REVIEW_REQUIRED'
            ELSE 'BLOCKED'
        END AS gate_class
    FROM reconciliation AS r
    LEFT JOIN projected_changes AS pc
      ON pc.import_run_id = r.import_run_id
     AND pc.source_prop_id = r.source_prop_id
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
        CASE
            WHEN ie.display_id_a = ir.display_id THEN ie.display_id_b
            ELSE ie.display_id_a
        END AS display_id
    FROM identity_reach AS ir
    JOIN identity_edges AS ie
      ON ie.display_id_a = ir.display_id
      OR ie.display_id_b = ir.display_id
),
identity_components AS (
    SELECT
        display_id,
        min(root_display_id) AS component_id
    FROM identity_reach
    GROUP BY display_id
),
grouped AS (
    SELECT
        c.*,
        CASE
            WHEN ic.component_id IS NOT NULL
                THEN format('DISPLAY_IDENTITY:%s', ic.component_id)
            WHEN c.display_id IS NOT NULL
                THEN format('DISPLAY:%s', c.display_id)
            ELSE format('LOR_PROP:%s', c.lor_prop_id)
        END AS logical_group_key
    FROM classified AS c
    LEFT JOIN identity_components AS ic
      ON ic.display_id = c.display_id
),
grouped_with_counts AS (
    SELECT
        g.*,
        count(*) FILTER (WHERE g.gate_class <> 'PASS') OVER (
            PARTITION BY g.logical_group_key
        )::integer AS logical_group_member_count,
        bool_or(g.classification_code = 'NAME_AND_UUID_CHANGED') OVER (
            PARTITION BY g.logical_group_key
        ) AS requires_atomic_reassociation
    FROM grouped AS g
),
summary AS (
    SELECT
        cr.import_run_id,
        cr.run_ts,
        count(c.*)::bigint AS total_candidate_count,
        count(*) FILTER (WHERE c.classification_code = 'EXACT_MATCH')::bigint
            AS exact_match_count,
        count(*) FILTER (WHERE c.classification_code = 'EXCLUDED_NONPHYSICAL')::bigint
            AS excluded_nonphysical_count,
        count(*) FILTER (WHERE c.gate_class = 'REVIEW_REQUIRED')::bigint
            AS review_required_count,
        count(*) FILTER (WHERE c.gate_class = 'BLOCKED')::bigint
            AS blocked_count,
        count(*) FILTER (
            WHERE c.classification_code <> 'EXCLUDED_NONPHYSICAL'
              AND cardinality(c.changed_fields) > 0
        )::bigint AS projected_change_count,
        count(*) FILTER (
            WHERE c.classification_code = 'EXACT_MATCH'
              AND cardinality(c.changed_fields) > 0
        )::bigint AS exact_match_projected_change_count,
        CASE
            WHEN count(*) FILTER (WHERE c.gate_class = 'BLOCKED') > 0
                THEN 'BLOCKED_SOURCE_OR_IDENTITY_DEFECTS'
            WHEN count(*) FILTER (WHERE c.gate_class = 'REVIEW_REQUIRED') > 0
                THEN 'OPERATOR_DECISIONS_REQUIRED'
            ELSE 'PASSED'
        END AS gate_result
    FROM current_run AS cr
    LEFT JOIN grouped_with_counts AS c
      ON c.import_run_id = cr.import_run_id
    GROUP BY cr.import_run_id, cr.run_ts
),
output_rows AS (
    SELECT
        0::integer AS output_order,
        'SUMMARY'::text AS row_type,
        s.import_run_id,
        s.run_ts AS ingest_timestamp,
        s.gate_result,
        NULL::text AS gate_class,
        NULL::text AS classification_code,
        false AS is_blocking,
        NULL::text AS logical_group_key,
        NULL::integer AS logical_group_member_count,
        NULL::bigint AS display_id,
        NULL::text AS production_display_name,
        NULL::integer AS display_status_id,
        NULL::text AS display_status_name,
        NULL::text AS lor_display_name,
        NULL::text AS lor_prop_id,
        NULL::text AS source_prop_id,
        NULL::text[] AS changed_fields,
        NULL::text AS current_stage_key,
        NULL::text AS current_stage_name,
        NULL::text AS proposed_stage_key,
        NULL::text AS proposed_stage_name,
        NULL::text AS preview_name,
        NULL::text AS preview_id,
        NULL::text AS location_summary,
        NULL::text[] AS allowed_resolution_paths,
        format(
            'total=%s; exact=%s; excluded_nonphysical=%s; projected_changes=%s; exact_with_changes=%s; review_required=%s; blocked=%s',
            s.total_candidate_count,
            s.exact_match_count,
            s.excluded_nonphysical_count,
            s.projected_change_count,
            s.exact_match_projected_change_count,
            s.review_required_count,
            s.blocked_count
        ) AS operator_message
    FROM summary AS s

    UNION ALL

    SELECT
        CASE c.gate_class
            WHEN 'BLOCKED' THEN 1
            WHEN 'REVIEW_REQUIRED' THEN 2
            WHEN 'PROJECTED_CHANGE' THEN 3
            ELSE 9
        END AS output_order,
        'CANDIDATE'::text AS row_type,
        c.import_run_id,
        cr.run_ts AS ingest_timestamp,
        NULL::text AS gate_result,
        c.gate_class,
        c.classification_code,
        (c.gate_class = 'BLOCKED' OR c.requires_atomic_reassociation) AS is_blocking,
        c.logical_group_key,
        c.logical_group_member_count,
        c.display_id,
        c.production_display_name,
        c.display_status_id,
        c.display_status_name,
        c.lor_display_name,
        c.lor_prop_id,
        c.source_prop_id,
        c.changed_fields,
        current_stage.stage_key AS current_stage_key,
        current_stage.stage_name AS current_stage_name,
        c.preview_stage_id AS proposed_stage_key,
        proposed_stage.stage_name AS proposed_stage_name,
        c.preview_name,
        c.preview_id,
        c.location_summary,
        CASE
            WHEN c.requires_atomic_reassociation
                THEN ARRAY['REASSOCIATE_DISPLAY', 'CORRECT_LOR_AND_REINGEST', 'DEFER']::text[]
            WHEN c.gate_class = 'PROJECTED_CHANGE'
                THEN ARRAY['DEFER']::text[]
            ELSE c.allowed_resolution_paths
        END AS allowed_resolution_paths,
        CASE
            WHEN c.requires_atomic_reassociation THEN format(
                'This display is one of %s records in identity dependency group %s. Resolve or defer the complete group atomically.',
                c.logical_group_member_count,
                c.logical_group_key
            )
            WHEN c.gate_class = 'PROJECTED_CHANGE' THEN format(
                'Identity matches production. Projected fields: %s. The change remains eligible unless the operator records DEFER.',
                array_to_string(c.changed_fields, ', ')
            )
            ELSE c.operator_message
        END AS operator_message
    FROM grouped_with_counts AS c
    JOIN current_run AS cr
      ON cr.import_run_id = c.import_run_id
    LEFT JOIN ref.stage AS current_stage
      ON current_stage.stage_id = c.current_stage_id
    LEFT JOIN ref.stage AS proposed_stage
      ON proposed_stage.stage_id = c.proposed_stage_id
    WHERE c.gate_class <> 'PASS'
)
SELECT
    row_type,
    import_run_id,
    ingest_timestamp,
    gate_result,
    gate_class,
    classification_code,
    is_blocking,
    logical_group_key,
    logical_group_member_count,
    display_id,
    production_display_name,
    display_status_id,
    display_status_name,
    lor_display_name,
    lor_prop_id,
    source_prop_id,
    changed_fields,
    current_stage_key,
    current_stage_name,
    proposed_stage_key,
    proposed_stage_name,
    preview_name,
    preview_id,
    location_summary,
    allowed_resolution_paths,
    operator_message
FROM output_rows
ORDER BY
    output_order,
    classification_code NULLS FIRST,
    coalesce(production_display_name, lor_display_name),
    display_id NULLS LAST,
    lor_prop_id NULLS LAST;
