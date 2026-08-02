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
      color

  The existing display_id and every PostgreSQL/Directus-owned field and
  relationship must be preserved. In particular, ordinary LOR reconciliation
  must not overwrite inventory_type, display_status_id, designer_id, theme_id,
  frame_id, container_id, year_built, amps_measured, est_light_count,
  dumb_controller, notes, label_required, or creation/person audit fields.

  display_status_id may change only through an explicit approved lifecycle
  decision. A confirmed new physical display is the only case that creates a
  new ref.display row and new display_id.

Gate behavior:
  - Exact matches require no operator action.
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
  correction. Exact matches and excluded nonphysical rows are counted in the
  summary but omitted from detail.

Revision History:
  2026-08-02  GAL / OpenAI  Include scoped source_prop_id separately from the
                           raw lor_prop_id production association.
  2026-08-02  GAL / OpenAI  Use raw_prop_id as preview-independent LOR identity
                           and remove the obsolete preview-relocation class.
  2026-08-01  GAL / OpenAI  Replaced the procedure-definition audit with the
                           required two-way production identity preflight gate.
  2026-08-01  GAL / OpenAI  Documented the shared-field ownership boundary and
                           preservation of all Directus-owned display metadata.
*/

WITH current_run AS (
    SELECT import_run_id, run_ts, notes
    FROM lor_snap.v_current_run
),
reconciliation AS (
    SELECT v.*
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr
      ON cr.import_run_id = v.import_run_id
),
classified AS (
    SELECT
        r.*,
        CASE
            WHEN r.classification_code IN (
                'EXACT_MATCH',
                'EXCLUDED_NONPHYSICAL'
            ) THEN 'PASS'
            WHEN r.classification_code IN (
                'NAME_CHANGED_SAME_UUID',
                'UUID_CHANGED_SAME_NAME',
                'NAME_AND_UUID_CHANGED',
                'NEW_DISPLAY_CANDIDATE',
                'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN 'REVIEW_REQUIRED'
            ELSE 'BLOCKED'
        END AS gate_class
    FROM reconciliation AS r
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
        CASE
            WHEN count(*) FILTER (WHERE c.gate_class = 'BLOCKED') > 0
                THEN 'BLOCKED_SOURCE_OR_IDENTITY_DEFECTS'
            WHEN count(*) FILTER (WHERE c.gate_class = 'REVIEW_REQUIRED') > 0
                THEN 'OPERATOR_DECISIONS_REQUIRED'
            ELSE 'PASSED'
        END AS gate_result
    FROM current_run AS cr
    LEFT JOIN classified AS c
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
        NULL::bigint AS display_id,
        NULL::text AS production_display_name,
        NULL::integer AS display_status_id,
        NULL::text AS display_status_name,
        NULL::text AS lor_display_name,
        NULL::text AS lor_prop_id,
        NULL::text AS source_prop_id,
        NULL::text AS proposed_stage_key,
        NULL::text AS preview_name,
        NULL::text AS preview_id,
        NULL::text AS location_summary,
        NULL::text[] AS allowed_resolution_paths,
        format(
            'total=%s; exact=%s; excluded_nonphysical=%s; review_required=%s; blocked=%s',
            s.total_candidate_count,
            s.exact_match_count,
            s.excluded_nonphysical_count,
            s.review_required_count,
            s.blocked_count
        ) AS operator_message
    FROM summary AS s

    UNION ALL

    SELECT
        CASE c.gate_class
            WHEN 'BLOCKED' THEN 1
            WHEN 'REVIEW_REQUIRED' THEN 2
            ELSE 9
        END AS output_order,
        'CANDIDATE'::text AS row_type,
        c.import_run_id,
        cr.run_ts AS ingest_timestamp,
        NULL::text AS gate_result,
        c.gate_class,
        c.classification_code,
        (c.gate_class = 'BLOCKED') AS is_blocking,
        c.display_id,
        c.production_display_name,
        c.display_status_id,
        c.display_status_name,
        c.lor_display_name,
        c.lor_prop_id,
        c.source_prop_id,
        c.preview_stage_id AS proposed_stage_key,
        c.preview_name,
        c.preview_id,
        c.location_summary,
        c.allowed_resolution_paths,
        c.operator_message
    FROM classified AS c
    JOIN current_run AS cr
      ON cr.import_run_id = c.import_run_id
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
    display_id,
    production_display_name,
    display_status_id,
    display_status_name,
    lor_display_name,
    lor_prop_id,
    source_prop_id,
    proposed_stage_key,
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
