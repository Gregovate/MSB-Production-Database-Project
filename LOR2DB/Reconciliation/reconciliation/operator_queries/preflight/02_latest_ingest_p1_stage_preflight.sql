/*
Schema: lor_snap / ref
Object: Current-ingest P1 stage preflight
Filename: 02_latest_ingest_p1_stage_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Evaluate current preview and populated-scene stage evidence before P1 or P3
  is enabled.

Safety:
  SELECT only. Does not create objects, call P1/P2/P3, or modify production data.

Source contract:
  Reads only lor_snap.v_current_run, lor_snap.v_current_previews,
  lor_snap.v_current_scenes, and lor_snap.v_current_scene_lor_props.

Rules:
  - Dedicated previews control physical stage assignment.
  - Scenes inside a dedicated preview inherit the preview StageID.
  - Shared Master Musical Preview scenes use scene-level stage evidence.
  - A shared preview UUID alone does not identify one physical stage.

Revision History:
  2026-08-01  GAL / OpenAI  Use the established lor_snap.v_current_* snapshot interface.
  2026-08-01  GAL / OpenAI  Correct dedicated-preview scene handling.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH populated_scenes AS (
    SELECT DISTINCT
        s.import_run_id,
        s.preview_id,
        s.scene_id,
        btrim(s.name) AS scene_name,
        lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS declared_scene_stage_key
    FROM lor_snap.v_current_scenes AS s
    JOIN lor_snap.v_current_scene_lor_props AS slp
      ON slp.preview_id = s.preview_id
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
        string_agg(DISTINCT ps.declared_scene_stage_key, ', ' ORDER BY ps.declared_scene_stage_key)
            AS scene_stage_keys,
        p.name ILIKE '%master musical preview%' AS is_shared_preview
    FROM lor_snap.v_current_previews AS p
    LEFT JOIN populated_scenes AS ps
      ON ps.preview_id = p.id
    WHERE btrim(coalesce(p.stage_id, '')) <> ''
      AND lower(btrim(p.stage_id)) ~ '^(0|[0-9]{1,2})[a-z]?$'
    GROUP BY p.import_run_id, p.id, p.name, p.stage_id
),
all_rows AS (
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
        CASE WHEN pp.is_shared_preview
             THEN 'CONTEXT_ONLY_SHARED_PREVIEW'
             ELSE 'PREVIEW_BINDING_CANDIDATE'
        END AS preliminary_classification
    FROM preview_profile AS pp

    UNION ALL

    SELECT
        ps.import_run_id,
        'SCENE'::text,
        ps.preview_id,
        ps.scene_id,
        ps.scene_name,
        CASE WHEN pp.is_shared_preview
             THEN ps.declared_scene_stage_key
             ELSE pp.preview_stage_key
        END,
        ps.declared_scene_stage_key,
        pp.is_shared_preview,
        pp.populated_scene_count,
        pp.distinct_scene_stage_count,
        pp.scene_stage_keys,
        CASE WHEN pp.is_shared_preview
             THEN 'SCENE_BINDING_CANDIDATE'
             ELSE 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
        END
    FROM populated_scenes AS ps
    JOIN preview_profile AS pp ON pp.preview_id = ps.preview_id
),
classified AS (
    SELECT
        a.*,
        rs.stage_id AS production_stage_id,
        rs.stage_key AS production_stage_key,
        rs.stage_name AS production_stage_name,
        rs.short_code AS production_short_code,
        rs.folder_name AS production_folder_name,
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
        (a.preliminary_classification <> 'CONTEXT_ONLY_SHARED_PREVIEW'
         AND rs.stage_id IS NULL) AS is_blocking,
        CASE
            WHEN a.preliminary_classification = 'CONTEXT_ONLY_SHARED_PREVIEW'
                THEN 'Shared preview is context only; stage identity uses its scenes.'
            WHEN rs.stage_id IS NULL
                THEN 'No ref.stage row exists for source stage key ' || a.source_stage_key || '.'
            WHEN a.preliminary_classification = 'DEDICATED_PREVIEW_SCENE_ASSOCIATION'
                THEN 'Dedicated preview controls stage identity; the scene inherits permanent stage_id '
                     || rs.stage_id || '.'
            ELSE 'Current LOR evidence resolves to existing permanent stage_id ' || rs.stage_id || '.'
        END AS operator_message
    FROM all_rows AS a
    LEFT JOIN ref.stage AS rs ON rs.stage_key = a.source_stage_key
)
SELECT *
FROM classified
ORDER BY
    is_blocking DESC,
    classification,
    source_stage_key,
    preview_id,
    scene_id NULLS FIRST;
