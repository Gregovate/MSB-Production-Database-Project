/*
Schema: lor_snap / ref
Object: Latest-ingest P1 stage preflight
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Compare preview and populated-scene stage evidence from the latest ingest
  against ref.stage without changing production data.

Safety:
  SELECT only. Does not call P1 and does not modify any object.

Revision History:
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH selected_run AS (
    SELECT ir.import_run_id
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
stage_evidence AS (
    SELECT
        p.import_run_id,
        lower(btrim(p.stage_id)) AS stage_key,
        btrim(p.stage_id) AS stage_id_raw,
        btrim(p.name) AS source_name,
        'PREVIEW'::text AS evidence_type,
        p.id AS preview_id,
        NULL::text AS scene_id
    FROM lor_snap.previews AS p
    JOIN selected_run AS sr ON sr.import_run_id = p.import_run_id
    WHERE btrim(coalesce(p.stage_id, '')) <> ''

    UNION ALL

    SELECT
        s.import_run_id,
        lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS stage_key,
        btrim(coalesce(slp.scene_stage_id, s.stage_id)) AS stage_id_raw,
        btrim(s.name) AS source_name,
        'POPULATED_SCENE'::text AS evidence_type,
        s.preview_id,
        s.scene_id
    FROM lor_snap.scenes AS s
    JOIN selected_run AS sr ON sr.import_run_id = s.import_run_id
    JOIN lor_snap.scene_lor_props AS slp
      ON slp.import_run_id = s.import_run_id
     AND slp.preview_id = s.preview_id
     AND slp.scene_id = s.scene_id
    WHERE btrim(coalesce(slp.scene_stage_id, s.stage_id, '')) <> ''
    GROUP BY
        s.import_run_id,
        slp.scene_stage_id,
        s.stage_id,
        s.name,
        s.preview_id,
        s.scene_id
),
valid_evidence AS (
    SELECT *
    FROM stage_evidence
    WHERE stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'
),
normalized AS (
    SELECT
        e.*,
        CASE
            WHEN e.evidence_type = 'PREVIEW'
             AND e.source_name ~* ('^Show Stage[[:space:]]+0*' || e.stage_key || '-')
                THEN regexp_replace(e.source_name, '^Show Stage[[:space:]]+', '', 'i')
            ELSE e.source_name
        END AS canonical_source_name
    FROM valid_evidence AS e
),
canonical_names AS (
    SELECT DISTINCT
        stage_key,
        canonical_source_name AS source_name,
        (regexp_match(canonical_source_name,
            '(?i)^0*' || stage_key || '-(.+)-([^-]+)$'))[1] AS parsed_stage_name,
        (regexp_match(canonical_source_name,
            '(?i)^0*' || stage_key || '-(.+)-([^-]+)$'))[2] AS parsed_short_code
    FROM normalized
    WHERE evidence_type = 'PREVIEW'
      AND canonical_source_name ~* ('^0*' || stage_key || '-.+-[a-z]{2}$')
),
stage_summary AS (
    SELECT
        v.import_run_id,
        v.stage_key,
        count(*) AS evidence_count,
        count(DISTINCT c.source_name) AS canonical_name_count,
        min(c.parsed_stage_name) AS proposed_stage_name,
        min(c.parsed_short_code) AS proposed_short_code,
        min(c.source_name) AS proposed_folder_name,
        string_agg(
            DISTINCT v.evidence_type || ': ' || v.source_name ||
            ' [preview=' || coalesce(v.preview_id, '<null>') ||
            ', scene=' || coalesce(v.scene_id, '<none>') || ']',
            E'\n'
            ORDER BY v.evidence_type || ': ' || v.source_name ||
            ' [preview=' || coalesce(v.preview_id, '<null>') ||
            ', scene=' || coalesce(v.scene_id, '<none>') || ']'
        ) AS source_evidence
    FROM valid_evidence AS v
    LEFT JOIN canonical_names AS c ON c.stage_key = v.stage_key
    GROUP BY v.import_run_id, v.stage_key
)
SELECT
    ss.import_run_id,
    ss.stage_key,
    rs.stage_id AS production_stage_id,
    rs.stage_name AS production_stage_name,
    rs.short_code AS production_short_code,
    rs.folder_name AS production_folder_name,
    ss.proposed_stage_name,
    ss.proposed_short_code,
    ss.proposed_folder_name,
    ss.evidence_count,
    ss.canonical_name_count,
    CASE
        WHEN rs.stage_id IS NOT NULL THEN 'EXISTING_STAGE_REVIEW_BINDINGS'
        WHEN ss.canonical_name_count = 1 THEN 'NEW_STAGE_CANDIDATE'
        ELSE 'BLOCKED_UNRESOLVED_STAGE_METADATA'
    END AS classification,
    (rs.stage_id IS NULL AND ss.canonical_name_count <> 1) AS is_blocking,
    ss.source_evidence
FROM stage_summary AS ss
LEFT JOIN ref.stage AS rs ON rs.stage_key = ss.stage_key
ORDER BY
    is_blocking DESC,
    CASE WHEN ss.stage_key ~ '^[0-9]+'
         THEN ((regexp_match(ss.stage_key, '^0*([0-9]{1,2})'))[1])::integer
         ELSE 1000 END,
    ss.stage_key;
