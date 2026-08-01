/* ============================================================================
Filename: 04_validate_p2_display_candidates_run36.sql
Object: Run 36 P2 display-promotion candidate validation
Type: Read-only production validation
Owner: msbadmin

Purpose:
  Validate the exact rows and LOR-owned attributes that a repaired P2 would
  promote from import run 36 after reconciliation has resolved display identity.

Current P2 scope:
  - Physical display main props only.
  - Existing permanent display_id values are preserved.
  - display_status_id remains PostgreSQL-owned and is not changed.
  - ref.spare_channel is not read, rebuilt, inserted, updated, or deleted.
  - SPARE, inferred-SPARE, PHANTOM, blank-comment, and other nonphysical props
    are not display candidates.
  - Subprops and their wiring remain preserved in lor_snap but are not promoted.

Safety:
  - This script contains SELECT statements only.
  - It does not call P1 or P2.
  - It does not create, replace, update, insert, or delete any database object.

Expected current Run 36 result:
  - Reconciliation is PASSED with zero blockers.
  - Every canonical physical candidate maps to exactly one ref.display row.
  - Every candidate stage key resolves to exactly one ref.stage row.
  - Name-inferred SPARE rows with missing/incorrect comments are reported as a
    separate blocking source-data defect. These rows are absent from the
    comment-required reconciliation source, so P2 must guard them directly.

Revision History:
  2026-08-01  GAL / OpenAI  Initial read-only Run 36 P2 validation.
============================================================================ */

/* --------------------------------------------------------------------------
1. Execution context and required object presence
---------------------------------------------------------------------------- */
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    now() AS checked_at,
    to_regclass('lor_snap.v_display_reconciliation_source') AS source_view,
    to_regclass('ops.v_lor_display_reconciliation') AS reconciliation_view,
    to_regclass('ref.display') AS display_table,
    to_regclass('ref.stage') AS stage_table;


/* --------------------------------------------------------------------------
2. Reconciliation gate

Expected for Run 36 after its 24 approved resolutions:
  blocking_count = 0
  preflight_status = PASSED
---------------------------------------------------------------------------- */
SELECT *
FROM ops.f_lor_reconciliation_summary(36);


/* --------------------------------------------------------------------------
3. Blocking source-data defect: channel/prop name ends in the word SPARE, but
   the LOR Comment field is null, blank, or anything other than exact SPARE.

These rows must be corrected in LOR and reingested. The defensive P2 guard will
also reject the run so an inferred spare can never receive a display_id.
---------------------------------------------------------------------------- */
SELECT
    p.import_run_id,
    p.preview_id,
    pr.name AS preview_name,
    pr.stage_id AS preview_stage_id,
    p.int_prop_id,
    p.prop_id AS lor_prop_id,
    p.name AS prop_name,
    p.lor_comment,
    p.network,
    p.uid AS controller_uid,
    p.start_channel,
    p.end_channel,
    'NAME_ENDS_IN_SPARE_WITHOUT_EXACT_SPARE_COMMENT'::text AS defect_code
FROM lor_snap.props AS p
JOIN lor_snap.previews AS pr
  ON pr.import_run_id = p.import_run_id
 AND pr.id = p.preview_id
WHERE p.import_run_id = 36
  AND upper(btrim(coalesce(p.name, ''))) ~ '(^|[[:space:]])SPARE[[:space:]]*$'
  AND upper(btrim(coalesce(p.lor_comment, ''))) <> 'SPARE'
ORDER BY
    lower(btrim(coalesce(pr.stage_id, ''))),
    pr.name,
    p.name,
    p.prop_id;


/* --------------------------------------------------------------------------
4. Blocking-defect count

Expected before correcting the demonstrated LOR source issue: greater than 0.
Required before P2 may run: 0.
---------------------------------------------------------------------------- */
SELECT
    count(*)::integer AS inferred_spare_comment_defect_count,
    CASE
        WHEN count(*) = 0 THEN 'PASSED'
        ELSE 'BLOCKED_CORRECT_LOR_AND_REINGEST'
    END AS p2_source_quality_status
FROM lor_snap.props AS p
WHERE p.import_run_id = 36
  AND upper(btrim(coalesce(p.name, ''))) ~ '(^|[[:space:]])SPARE[[:space:]]*$'
  AND upper(btrim(coalesce(p.lor_comment, ''))) <> 'SPARE';


/* --------------------------------------------------------------------------
5. Canonical physical candidate cardinality

The repaired P2 consumes only canonical rows that are neither SPARE nor
PHANTOM. After approved reconciliation, every row must match one production
display by both current lor_prop_id and normalized display_name.
---------------------------------------------------------------------------- */
WITH candidates AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    WHERE src.import_run_id = 36
      AND NOT src.is_spare
      AND NOT src.is_phantom
)
SELECT
    count(*)::integer AS physical_candidate_count,
    count(*) FILTER (
        WHERE d.display_id IS NOT NULL
    )::integer AS matched_by_uuid_and_name_count,
    count(*) FILTER (
        WHERE d.display_id IS NULL
    )::integer AS unmatched_candidate_count,
    count(DISTINCT d.display_id)::integer AS distinct_display_id_count
FROM candidates AS c
LEFT JOIN ref.display AS d
  ON d.lor_prop_id = c.lor_prop_id
 AND upper(btrim(d.display_name)) = c.display_name_normalized;


/* --------------------------------------------------------------------------
6. Blocking physical-candidate mapping failures

Required before P2 may run: zero rows.
---------------------------------------------------------------------------- */
WITH candidates AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    WHERE src.import_run_id = 36
      AND NOT src.is_spare
      AND NOT src.is_phantom
)
SELECT
    c.preview_stage_id AS stage_key,
    c.preview_name,
    c.preview_id,
    c.lor_prop_id,
    c.display_name AS lor_display_name,
    d_uuid.display_id AS uuid_match_display_id,
    d_uuid.display_name AS uuid_match_display_name,
    d_name.display_id AS name_match_display_id,
    d_name.lor_prop_id AS name_match_lor_prop_id,
    CASE
        WHEN d_uuid.display_id IS NULL AND d_name.display_id IS NULL
            THEN 'NO_PRODUCTION_MATCH'
        WHEN d_uuid.display_id IS NULL
            THEN 'UUID_DOES_NOT_MATCH_RESOLVED_DISPLAY'
        WHEN d_name.display_id IS NULL
            THEN 'NAME_DOES_NOT_MATCH_RESOLVED_DISPLAY'
        WHEN d_uuid.display_id <> d_name.display_id
            THEN 'UUID_AND_NAME_MATCH_DIFFERENT_DISPLAYS'
        ELSE 'UNKNOWN_MAPPING_FAILURE'
    END AS failure_code
FROM candidates AS c
LEFT JOIN ref.display AS d_uuid
  ON d_uuid.lor_prop_id = c.lor_prop_id
LEFT JOIN ref.display AS d_name
  ON upper(btrim(d_name.display_name)) = c.display_name_normalized
WHERE d_uuid.display_id IS NULL
   OR d_name.display_id IS NULL
   OR d_uuid.display_id <> d_name.display_id
ORDER BY c.display_name, c.lor_prop_id;


/* --------------------------------------------------------------------------
7. Blocking stage-resolution failures

Required before P2 may run: zero rows.
---------------------------------------------------------------------------- */
WITH candidates AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    WHERE src.import_run_id = 36
      AND NOT src.is_spare
      AND NOT src.is_phantom
)
SELECT
    c.preview_stage_id AS source_stage_key,
    c.preview_name,
    c.preview_id,
    c.lor_prop_id,
    c.display_name,
    s.stage_id AS resolved_stage_id,
    s.stage_key AS resolved_stage_key
FROM candidates AS c
LEFT JOIN ref.stage AS s
  ON s.stage_key = lower(btrim(c.preview_stage_id))
WHERE nullif(btrim(c.preview_stage_id), '') IS NULL
   OR s.stage_id IS NULL
ORDER BY c.display_name, c.lor_prop_id;


/* --------------------------------------------------------------------------
8. Exact proposed P2 changes

Only stage_id, string_type, and color are in the current approved update set.
Name, LOR UUID, display_id, inventory type, status, and all PostgreSQL-owned
asset/operational attributes are deliberately absent from the SET list.
---------------------------------------------------------------------------- */
WITH candidates AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    WHERE src.import_run_id = 36
      AND NOT src.is_spare
      AND NOT src.is_phantom
),
resolved AS (
    SELECT
        d.display_id,
        d.display_name,
        d.lor_prop_id,
        d.stage_id AS current_stage_id,
        s.stage_id AS proposed_stage_id,
        d.string_type AS current_string_type,
        c.string_type AS proposed_string_type,
        d.color AS current_color,
        c.color AS proposed_color
    FROM candidates AS c
    JOIN ref.display AS d
      ON d.lor_prop_id = c.lor_prop_id
     AND upper(btrim(d.display_name)) = c.display_name_normalized
    JOIN ref.stage AS s
      ON s.stage_key = lower(btrim(c.preview_stage_id))
)
SELECT
    display_id,
    display_name,
    lor_prop_id,
    current_stage_id,
    proposed_stage_id,
    current_string_type,
    proposed_string_type,
    current_color,
    proposed_color,
    concat_ws(', ',
        CASE WHEN current_stage_id IS DISTINCT FROM proposed_stage_id
             THEN 'stage_id' END,
        CASE WHEN current_string_type IS DISTINCT FROM proposed_string_type
             THEN 'string_type' END,
        CASE WHEN current_color IS DISTINCT FROM proposed_color
             THEN 'color' END
    ) AS changed_columns
FROM resolved
WHERE current_stage_id IS DISTINCT FROM proposed_stage_id
   OR current_string_type IS DISTINCT FROM proposed_string_type
   OR current_color IS DISTINCT FROM proposed_color
ORDER BY display_name, display_id;


/* --------------------------------------------------------------------------
9. Proposed-change summary
---------------------------------------------------------------------------- */
WITH candidates AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    WHERE src.import_run_id = 36
      AND NOT src.is_spare
      AND NOT src.is_phantom
),
resolved AS (
    SELECT
        d.display_id,
        d.stage_id AS current_stage_id,
        s.stage_id AS proposed_stage_id,
        d.string_type AS current_string_type,
        c.string_type AS proposed_string_type,
        d.color AS current_color,
        c.color AS proposed_color
    FROM candidates AS c
    JOIN ref.display AS d
      ON d.lor_prop_id = c.lor_prop_id
     AND upper(btrim(d.display_name)) = c.display_name_normalized
    JOIN ref.stage AS s
      ON s.stage_key = lower(btrim(c.preview_stage_id))
)
SELECT
    count(*)::integer AS matched_candidate_count,
    count(*) FILTER (
        WHERE current_stage_id IS DISTINCT FROM proposed_stage_id
           OR current_string_type IS DISTINCT FROM proposed_string_type
           OR current_color IS DISTINCT FROM proposed_color
    )::integer AS rows_that_would_update,
    count(*) FILTER (
        WHERE current_stage_id IS DISTINCT FROM proposed_stage_id
    )::integer AS stage_id_change_count,
    count(*) FILTER (
        WHERE current_string_type IS DISTINCT FROM proposed_string_type
    )::integer AS string_type_change_count,
    count(*) FILTER (
        WHERE current_color IS DISTINCT FROM proposed_color
    )::integer AS color_change_count
FROM resolved;


/* --------------------------------------------------------------------------
10. Confirm current P2 no-touch objects and columns exist for later comparison.

This is evidence only. No values are changed.
---------------------------------------------------------------------------- */
SELECT
    count(*)::integer AS current_spare_channel_row_count
FROM ref.spare_channel;

SELECT
    count(*)::integer AS current_display_row_count,
    count(*) FILTER (
        WHERE upper(btrim(coalesce(display_name, ''))) = 'SPARE'
           OR upper(btrim(coalesce(display_name, '')))
                ~ '(^|[[:space:]])SPARE[[:space:]]*$'
    )::integer AS current_display_rows_named_as_spare
FROM ref.display;

