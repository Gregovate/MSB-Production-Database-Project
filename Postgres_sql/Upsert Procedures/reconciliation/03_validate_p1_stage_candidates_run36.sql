/*
Object: Run 36 P1 stage-candidate validation
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Show the exact preview/scene evidence and winning source that the proposed
  scene-aware P1 procedure would use for import run 36.

Safety:
  Read-only. This script does not create, update, or delete any database data.

Revision History:
  2026-07-31  GAL / OpenAI  Initial validation query.
*/

WITH parameters AS (
    SELECT 36::bigint AS import_run_id
),
stage_evidence AS (
    SELECT
        lower(btrim(p.stage_id)) AS stage_key,
        btrim(p.stage_id) AS stage_id_raw,
        p.name AS source_name,
        'PREVIEW'::text AS evidence_type,
        1 AS source_priority,
        p.id AS preview_id,
        NULL::text AS scene_id
    FROM lor_snap.previews AS p
    JOIN parameters AS x
      ON x.import_run_id = p.import_run_id
    WHERE btrim(coalesce(p.stage_id, '')) <> ''

    UNION ALL

    SELECT
        lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS stage_key,
        btrim(coalesce(slp.scene_stage_id, s.stage_id)) AS stage_id_raw,
        s.name AS source_name,
        'POPULATED_SCENE'::text AS evidence_type,
        2 AS source_priority,
        s.preview_id,
        s.scene_id
    FROM lor_snap.scenes AS s
    JOIN parameters AS x
      ON x.import_run_id = s.import_run_id
    JOIN lor_snap.scene_lor_props AS slp
      ON slp.import_run_id = s.import_run_id
     AND slp.preview_id = s.preview_id
     AND slp.scene_id = s.scene_id
    WHERE btrim(coalesce(slp.scene_stage_id, s.stage_id, '')) <> ''
    GROUP BY
        slp.scene_stage_id,
        s.stage_id,
        s.name,
        s.preview_id,
        s.scene_id
),
ranked AS (
    SELECT
        e.*,
        e.stage_key ~ '^(0|[0-9]{1,2})[a-z]?$' AS is_canonical,
        row_number() OVER (
            PARTITION BY e.stage_key
            ORDER BY
                e.source_priority,
                (e.source_name ~* '^\s*stage\b') DESC,
                length(coalesce(e.source_name, '')) DESC,
                e.source_name DESC NULLS LAST,
                e.preview_id,
                e.scene_id NULLS FIRST
        ) AS candidate_rank
    FROM stage_evidence AS e
)
SELECT
    stage_key,
    stage_id_raw,
    evidence_type,
    source_name,
    preview_id,
    scene_id,
    is_canonical,
    candidate_rank,
    (is_canonical AND candidate_rank = 1) AS selected_by_p1
FROM ranked
ORDER BY
    CASE
        WHEN stage_key ~ '^[0-9]+' THEN
            ((regexp_match(stage_key, '^0*([0-9]{1,2})'))[1])::integer
        ELSE 1000
    END,
    stage_key,
    candidate_rank;
