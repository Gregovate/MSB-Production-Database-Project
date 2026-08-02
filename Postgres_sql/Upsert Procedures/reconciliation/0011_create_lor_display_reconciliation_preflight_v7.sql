/* ============================================================================
Object group: LOR display reconciliation read-only preflight
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
File:         0011_create_lor_display_reconciliation_preflight_v7.sql

Purpose:
  Build the read-only, run-aware evidence and classification layer used before
  P1, P2, or future P3 may modify production reference data.

Display identity contract:
  - ref.display.display_id is the permanent relational identity.
  - ref.display.display_name is the human-facing identity.
  - ref.display.lor_prop_id is only the current LOR UUID association.
  - A LOR rename or UUID replacement must preserve display_id.
  - ref.display status is PostgreSQL-owned and is never inferred from LOR.

Safety:
  - This file creates or replaces views and one read-only SQL function.
  - It does not update ref.display, P1, P2, P3, or snapshot data.
  - Every snapshot join includes import_run_id.
  - lor_snap.preview_wiring_fieldonly_v6 is not changed.

Revision history:
  2026-07-31  GAL / OpenAI  Initial read-only preflight implementation.
  2026-07-31  GAL / OpenAI  Canonicalize background and Master Musical
                           scene evidence by display name and LOR UUID.
  2026-07-31  GAL / OpenAI  Add an installation fingerprint so DBeaver
                           confirms the scene-aware definition was installed.
  2026-08-02  GAL / OpenAI  Use unscoped raw_prop_id for LOR identity while
                           retaining scoped prop_id only for snapshot joins.
  2026-08-02  GAL / OpenAI  Expose the canonical scoped prop_id as
                           source_prop_id so P2 can revalidate the exact
                           captured source row before writing ref.display.
  2026-07-31  GAL / OpenAI  Classify SPARE and PHANTOM rows before duplicate
                           identity checks so nonphysical props do not block.
  2026-07-31  GAL / OpenAI  Require a nonblank LOR comment for display
                           identity; never substitute the prop/channel name.
  2026-07-31  GAL / OpenAI  Correct the governing design contract and issue
                           the withdrawn V6 draft as the validated V7 revision.
============================================================================ */

BEGIN;

/* --------------------------------------------------------------------------
1. Canonical physical-display source

Background previews remain the preferred identity source because they carry a
canonical preview-level stage ID. V7 also permits a physical display to exist
only in the Master Musical Preview, where its stage context is carried by scene
membership. Background and Master Musical evidence are combined, then reduced
to one canonical row per normalized display name and LOR UUID. A background
row wins when both sources contain the same identity. This preserves genuine
same-name/different-UUID conflicts while preventing repeated occurrences from
becoming duplicate physical identities.
---------------------------------------------------------------------------- */
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
        count(*)::integer AS lor_uuid_row_count,
        count(DISTINCT display_name_normalized)::integer AS lor_uuid_name_count
    FROM source_rows
    GROUP BY import_run_id, lor_prop_id
),
name_counts AS (
    SELECT
        import_run_id,
        display_name_normalized,
        count(DISTINCT lor_prop_id)::integer AS lor_name_uuid_count
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
'Run-aware physical-display candidates requiring a nonblank LOR comment and canonicalized by normalized display name and raw LOR UUID. source_prop_id identifies the exact canonical snapshot occurrence; lor_prop_id is the preview-independent raw_prop_id proposed for ref.display. Prop/channel names are never substituted for blank comments. Background evidence is preferred; Master Musical scene evidence supplies musical-only displays.';


/* --------------------------------------------------------------------------
2. Preview and scene occurrence evidence

This view answers where a display is currently used in LOR. Scene rows are
supporting evidence only; they do not create or change physical identity.
---------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW lor_snap.v_display_lor_occurrence AS
WITH preview_occurrence AS (
    SELECT
        p.import_run_id,
        p.raw_prop_id AS lor_prop_id,
        btrim(p.lor_comment) AS display_name,
        upper(btrim(p.lor_comment)) AS display_name_normalized,
        p.preview_id,
        pr.name AS preview_name,
        pr.stage_id AS preview_stage_id,
        NULL::text AS scene_id,
        NULL::text AS scene_name,
        NULL::text AS scene_stage_id,
        'PREVIEW'::text AS location_type
    FROM lor_snap.props AS p
    JOIN lor_snap.previews AS pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE nullif(btrim(p.lor_comment), '') IS NOT NULL
),
scene_occurrence AS (
    SELECT
        slp.import_run_id::bigint AS import_run_id,
        slp.raw_prop_id AS lor_prop_id,
        btrim(p.lor_comment) AS display_name,
        upper(btrim(p.lor_comment)) AS display_name_normalized,
        slp.preview_id,
        pr.name AS preview_name,
        pr.stage_id AS preview_stage_id,
        slp.scene_id,
        sc.name AS scene_name,
        coalesce(slp.scene_stage_id, sc.stage_id) AS scene_stage_id,
        'SCENE'::text AS location_type
    FROM lor_snap.scene_lor_props AS slp
    JOIN lor_snap.props AS p
      ON p.import_run_id = slp.import_run_id::bigint
     AND p.prop_id = slp.prop_id
     AND p.raw_prop_id = slp.raw_prop_id
    JOIN lor_snap.previews AS pr
      ON pr.import_run_id = slp.import_run_id::bigint
     AND pr.id = slp.preview_id
    LEFT JOIN lor_snap.scenes AS sc
      ON sc.import_run_id = slp.import_run_id
     AND sc.preview_id = slp.preview_id
     AND sc.scene_id = slp.scene_id
    WHERE nullif(btrim(p.lor_comment), '') IS NOT NULL
)
SELECT * FROM preview_occurrence
UNION ALL
SELECT * FROM scene_occurrence;

COMMENT ON VIEW lor_snap.v_display_lor_occurrence IS
'Run-aware evidence of every preview and scene containing an LOR prop. Scene membership is location evidence, not physical-display identity authority.';


/* --------------------------------------------------------------------------
3. Bidirectional reconciliation classification

One primary candidate classification is emitted per authoritative source row.
The reverse branch emits active PostgreSQL displays missing from the selected
LOR source. Exact matches pass automatically; all identity/status differences
remain blocking until a later audited resolution layer is implemented.
---------------------------------------------------------------------------- */
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
    GROUP BY o.import_run_id, o.lor_prop_id
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
'Live bidirectional display preflight by explicit import_run_id. Exact matches pass automatically; identity, status, duplicate, and missing-display discrepancies block.';


/* --------------------------------------------------------------------------
4. Read-only run summary
---------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.f_lor_reconciliation_summary(
    p_import_run_id bigint
)
RETURNS TABLE (
    import_run_id bigint,
    total_count integer,
    exact_match_count integer,
    excluded_nonphysical_count integer,
    blocking_count integer,
    preflight_status text
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        p_import_run_id,
        count(*)::integer AS total_count,
        count(*) FILTER (WHERE classification_code = 'EXACT_MATCH')::integer
            AS exact_match_count,
        count(*) FILTER (WHERE classification_code = 'EXCLUDED_NONPHYSICAL')::integer
            AS excluded_nonphysical_count,
        count(*) FILTER (WHERE is_blocking)::integer AS blocking_count,
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM lor_snap.import_run AS ir
                WHERE ir.import_run_id = p_import_run_id
            ) THEN 'IMPORT_RUN_NOT_FOUND'
            WHEN count(*) FILTER (WHERE is_blocking) = 0 THEN 'PASSED'
            ELSE 'BLOCKED'
        END AS preflight_status
    FROM ops.v_lor_display_reconciliation
    WHERE import_run_id = p_import_run_id;
$function$;

COMMENT ON FUNCTION ops.f_lor_reconciliation_summary(bigint) IS
'Returns read-only display reconciliation counts and pass/block status for one explicit immutable LOR import_run_id.';

COMMIT;

/* --------------------------------------------------------------------------
Installation fingerprint

This returns one row after a successful full-script execution. Both Boolean
columns must be true. It distinguishes this scene-aware revision from an older
same-named download that excluded Master Musical Preview scene candidates.
---------------------------------------------------------------------------- */
SELECT
    '2026-08-02-raw-identity-exact-source-row-v7'::text
        AS installed_revision,
    position(
        'combined_rows' IN
        pg_get_viewdef('lor_snap.v_display_reconciliation_source'::regclass, true)
    ) > 0 AS has_combined_source,
    position(
        'Master Musical Preview' IN
        pg_get_viewdef('lor_snap.v_display_reconciliation_source'::regclass, true)
    ) > 0 AS has_master_musical_source,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'v_lor_display_reconciliation'
          AND column_name = 'source_prop_id'
    ) AS has_exact_source_prop_id;

/* --------------------------------------------------------------------------
Operator verification examples -- replace :import_run_id before execution.

SELECT *
FROM ops.f_lor_reconciliation_summary(:import_run_id);

SELECT classification_code, count(*) AS row_count
FROM ops.v_lor_display_reconciliation
WHERE import_run_id = :import_run_id
GROUP BY classification_code
ORDER BY classification_code;

SELECT *
FROM ops.v_lor_display_reconciliation
WHERE import_run_id = :import_run_id
  AND is_blocking
ORDER BY classification_code, coalesce(lor_display_name, production_display_name);
---------------------------------------------------------------------------- */
