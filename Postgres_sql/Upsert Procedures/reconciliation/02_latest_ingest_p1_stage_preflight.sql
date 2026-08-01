/*
Schema: lor_snap / ref
Object: Latest-ingest P1 stage preflight
Filename: 02_latest_ingest_p1_stage_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Evaluate preview and populated-scene stage evidence from the latest ingest at
  the binding level before P1 or any scene-binding procedure is enabled.

Safety:
  SELECT only. Does not create objects, call P1/P2/P3, or modify production data.

Rules:
  - A dedicated preview binds to its physical stage by preview_id.
  - Scenes inside a dedicated preview are subordinate workspace associations and
    inherit the dedicated preview's stage; scene names or parsed scene stage keys
    do not override the preview StageID.
  - Scenes inside the shared Master Musical Preview bind by preview_id + scene_id
    and use scene-level stage evidence.
  - A shared preview's preview-level StageID is context only and cannot identify
    one physical stage.
  - Existing ref.stage rows are preserved; this query does not infer renames or
    renumbering without a persistent stage-to-LOR binding table.

Revision History:
  2026-08-01  GAL / OpenAI  Correct dedicated-preview scene handling: inherit
                           preview StageID and do not report scene-name conflicts.
  2026-08-01  GAL / OpenAI  Materialize classification before final sort.
  2026-08-01  GAL / OpenAI  Add repository filename to document-control header.
  2026-08-01  GAL / OpenAI  Replace stage-key rollup with binding-level preflight.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH selected_run AS (
    SELECT ir.import_run_id
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
populated_scenes AS (
    SELECT DISTINCT
        s.import_run_id,
        s.preview_id,
        s.scene_id,
        btrim(s.name) AS scene_name,
        lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS declared_scene_stage_key
    FROM lor_snap.scenes AS s
    JOIN selected_run AS sr
      ON sr.import_run_id = s.import_run_id
    JOIN lor_snap.scene_lor_props AS slp
      ON slp.import_run_id = s.import_run_id
     AND slp.preview_id = s.preview_id
     AND slp.scene_id = s.scene_id
    WHERE btrim(coalesce(slp.scene_stage_id, s.stage_id, '')) <> ''
      AND lower(btrim(coalesce(slp.scene_stage_id, s.stage_id)))
            ~ '^(0|[0-9]{1,2})[a-z]?$'
),
preview_profile AS (
    SELECT
        p.import_run_id,
        p.id AS preview_id,
        btrim(p.name) AS preview_name,
        lower(btrim(p.stage_id)) AS preview_stage_key,
        count(ps.scene_id) AS populated_scene_count,
        count(DISTINCT ps.declared_scene_stage_key) AS distinct_scene_stage_count,
        string_agg(
            DISTINCT ps.declared_scene_stage_key,
            ', ' ORDER BY ps.declared_scene_stage_key
        ) AS scene_stage_keys,
        p.name ILIKE '%master musical preview%' AS is_shared_preview
    FROM lor_snap.previews AS p
    JOIN selected_run AS sr
      ON sr.import_run_id = p.import_run_id
    LEFT JOIN populated_scenes AS ps
      ON ps.import_run_id = p.import_run_id
     AND ps.preview_id = p.id
    WHERE btrim(coalesce(p.stage_id, '')) <> ''
      AND lower(btrim(p.stage_id)) ~ '^(0|[0-9]{1,2})[a-z]?$'
    GROUP BY p.import_run_id, p.id, p.name, p.stage_id
),
preview_rows AS (
    SELECT
        pp.import_run_id,
        'PREVIEW'::text AS binding_type,
        pp.preview_id,
        NULL::text AS scene_id,
        pp.preview_name AS source_name,
        pp.preview_stage_key AS source_stage_key,
        NULL::text AS declared_scene_stage_key,
        pp.is_shared_preview,
        pp.populated_scene_count,
        pp.distinct_scene_stage_count,
        pp.scene_stage_keys,
        CASE
            WHEN pp.is_shared_preview
                THEN 'CONTEXT_ONLY_SHARED_PREVIEW'
            ELSE 'PREVIEW_BINDING_CANDIDATE'
        END AS preliminary_classification
    FROM preview_profile AS pp
),
scene_rows AS (
    SELECT
        ps.import_run_id,
        'SCENE'::text AS binding_type,
        ps.preview_id,
        ps.scene_id,
        ps.scene_name AS source_name,
        CASE
            WHEN pp.is_shared_preview
                THEN ps.declared_scene_stage_key
            ELSE pp.preview_stage_key
        END AS source_stage_key,
        ps.declared_scene_stage_key,
        pp.is_shared_preview,
        pp.populated_scene_count,
        pp.distinct_scene_stage_count,
        pp.scene_stage_keys,
        CASE
            WHEN pp.is_shared_preview
                THEN 'SCENE_BINDING_CANDIDATE'
            ELSE 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
        END AS preliminary_classification
    FROM populated_scenes AS ps
    JOIN preview_profile AS pp
      ON pp.import_run_id = ps.import_run_id
     AND pp.preview_id = ps.preview_id
),
all_rows AS (
    SELECT * FROM preview_rows
    UNION ALL
    SELECT * FROM scene_rows
),
classified AS (
    SELECT
        a.import_run_id,
        a.binding_type,
        a.preview_id,
        a.scene_id,
        a.source_name,
        a.source_stage_key,
        a.declared_scene_stage_key,
        rs.stage_id AS production_stage_id,
        rs.stage_key AS production_stage_key,
        rs.stage_name AS production_stage_name,
        rs.short_code AS production_short_code,
        rs.folder_name AS production_folder_name,
        a.is_shared_preview,
        a.populated_scene_count,
        a.distinct_scene_stage_count,
        a.scene_stage_keys,
        CASE
            WHEN a.preliminary_classification = 'CONTEXT_ONLY_SHARED_PREVIEW'
                THEN a.preliminary_classification
            WHEN rs.stage_id IS NULL
                THEN 'NEW_STAGE_REQUIRES_AUTHORITATIVE_METADATA'
            WHEN a.preliminary_classification = 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
                THEN 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
            WHEN a.binding_type = 'PREVIEW'
                THEN 'EXISTING_STAGE_PREVIEW_BINDING_CANDIDATE'
            ELSE 'EXISTING_STAGE_SCENE_BINDING_CANDIDATE'
        END AS classification,
        CASE
            WHEN a.preliminary_classification <> 'CONTEXT_ONLY_SHARED_PREVIEW'
             AND rs.stage_id IS NULL
                THEN true
            ELSE false
        END AS is_blocking,
        CASE
            WHEN a.preliminary_classification = 'CONTEXT_ONLY_SHARED_PREVIEW'
                THEN 'Shared preview_id is context only; stage identity must use scene bindings.'
            WHEN rs.stage_id IS NULL
                THEN 'No ref.stage row exists for source stage key ' || a.source_stage_key || '.'
            WHEN a.preliminary_classification = 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
                THEN 'Dedicated preview controls stage identity. Scene association inherits permanent stage_id ' ||
                     rs.stage_id || '; declared scene key ' ||
                     coalesce(a.declared_scene_stage_key, '<none>') ||
                     ' does not override preview stage ' || a.source_stage_key || '.'
            ELSE 'Binding candidate resolves to existing permanent stage_id ' || rs.stage_id || '.'
        END AS operator_message
    FROM all_rows AS a
    LEFT JOIN ref.stage AS rs
      ON rs.stage_key = a.source_stage_key
)
SELECT *
FROM classified
ORDER BY
    is_blocking DESC,
    CASE classification
        WHEN 'NEW_STAGE_REQUIRES_AUTHORITATIVE_METADATA' THEN 1
        WHEN 'EXISTING_STAGE_PREVIEW_BINDING_CANDIDATE' THEN 2
        WHEN 'EXISTING_STAGE_SCENE_BINDING_CANDIDATE' THEN 3
        WHEN 'DEDICATED_PREVIEW_SCENE_ASSOCIATION' THEN 4
        WHEN 'CONTEXT_ONLY_SHARED_PREVIEW' THEN 5
        ELSE 9
    END,
    source_stage_key,
    preview_id,
    scene_id NULLS FIRST;
