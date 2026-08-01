/*
Schema: lor_snap / ref
Object: Latest-ingest scene preflight
Filename: 06_latest_ingest_scene_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Compare scenes from the latest complete LOR snapshot with the current
  production projection in ref.lor_scene.

Safety:
  SELECT only. Does not create objects, call P1/P2/P3, or modify production data.

Rules:
  - The latest import_run_id is selected automatically at execution time.
  - Dedicated previews control physical stage assignment for every scene they
    contain. Scene text cannot override the preview StageID.
  - Shared previews use preview_id + scene_id and the scene StageID.
  - Scene identity is preview_uuid + scene_uuid.
  - Historical scene definitions remain in lor_snap.scenes.
  - Existing production rows are not deleted by this preflight.

Result:
  Returns one exportable result set containing scene candidates classified as
  ADD_SCENE, UPDATE_SCENE, UNCHANGED_SCENE, or a blocking stage-resolution issue.

Revision History:
  2026-08-01  GAL / OpenAI  Split scene and scene-display preflight responsibilities.
  2026-08-01  GAL / OpenAI  Replace unsupported DISTINCT window functions with grouped CTEs.
  2026-08-01  GAL / OpenAI  Initial latest-ingest scene production preflight.
*/

WITH selected_run AS (
    SELECT ir.import_run_id, ir.run_ts
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
preview_profile AS (
    SELECT
        p.import_run_id,
        p.id AS preview_id,
        btrim(p.name) AS preview_name,
        lower(btrim(p.stage_id)) AS preview_stage_key,
        count(DISTINCT lower(btrim(s.stage_id))) FILTER (
            WHERE btrim(coalesce(s.stage_id, '')) <> ''
        ) AS distinct_scene_stage_count,
        (
            p.name ILIKE '%master musical preview%'
            OR count(DISTINCT lower(btrim(s.stage_id))) FILTER (
                WHERE btrim(coalesce(s.stage_id, '')) <> ''
            ) > 1
        ) AS is_shared_preview
    FROM lor_snap.previews AS p
    JOIN selected_run AS sr
      ON sr.import_run_id = p.import_run_id
    LEFT JOIN lor_snap.scenes AS s
      ON s.import_run_id = p.import_run_id
     AND s.preview_id = p.id
    GROUP BY
        p.import_run_id,
        p.id,
        p.name,
        p.stage_id
),
scene_source AS (
    SELECT
        s.import_run_id,
        s.preview_id,
        s.scene_id,
        btrim(s.name) AS scene_name,
        pp.preview_name,
        pp.is_shared_preview,
        pp.preview_stage_key,
        lower(btrim(s.stage_id)) AS declared_scene_stage_key,
        CASE
            WHEN pp.is_shared_preview
                THEN lower(btrim(s.stage_id))
            ELSE pp.preview_stage_key
        END AS resolved_stage_key,
        to_jsonb(s)->>'scene_section' AS scene_section,
        to_jsonb(s)->>'background_file' AS background_file,
        nullif(to_jsonb(s)->>'h_scroll', '')::integer AS h_scroll,
        nullif(to_jsonb(s)->>'v_scroll', '')::integer AS v_scroll,
        nullif(to_jsonb(s)->>'zoom', '')::integer AS zoom,
        to_jsonb(s)->>'create_grid_view' AS create_grid_view
    FROM lor_snap.scenes AS s
    JOIN selected_run AS sr
      ON sr.import_run_id = s.import_run_id
    JOIN preview_profile AS pp
      ON pp.import_run_id = s.import_run_id
     AND pp.preview_id = s.preview_id
),
classified AS (
    SELECT
        ss.import_run_id,
        ss.preview_id,
        ss.scene_id,
        ss.scene_name,
        ss.preview_name,
        ss.is_shared_preview,
        ss.preview_stage_key,
        ss.declared_scene_stage_key,
        ss.resolved_stage_key,
        st.stage_id AS resolved_stage_id,
        ls.lor_scene_id AS existing_lor_scene_id,
        ls.stage_id AS existing_stage_id,
        ls.scene_name AS existing_scene_name,
        ls.scene_section AS existing_scene_section,
        ls.background_file AS existing_background_file,
        ls.h_scroll AS existing_h_scroll,
        ls.v_scroll AS existing_v_scroll,
        ls.zoom AS existing_zoom,
        ls.create_grid_view AS existing_create_grid_view,
        ss.scene_section,
        ss.background_file,
        ss.h_scroll,
        ss.v_scroll,
        ss.zoom,
        ss.create_grid_view,
        CASE
            WHEN ss.resolved_stage_key IS NULL OR st.stage_id IS NULL
                THEN 'BLOCKED_SCENE_STAGE_NOT_RESOLVED'
            WHEN ls.lor_scene_id IS NULL
                THEN 'ADD_SCENE'
            WHEN ls.stage_id IS DISTINCT FROM st.stage_id
              OR ls.scene_name IS DISTINCT FROM ss.scene_name
              OR ls.scene_section IS DISTINCT FROM ss.scene_section
              OR ls.background_file IS DISTINCT FROM ss.background_file
              OR ls.h_scroll IS DISTINCT FROM ss.h_scroll
              OR ls.v_scroll IS DISTINCT FROM ss.v_scroll
              OR ls.zoom IS DISTINCT FROM ss.zoom
              OR ls.create_grid_view IS DISTINCT FROM ss.create_grid_view
                THEN 'UPDATE_SCENE'
            ELSE 'UNCHANGED_SCENE'
        END AS classification,
        (ss.resolved_stage_key IS NULL OR st.stage_id IS NULL) AS is_blocking,
        CASE
            WHEN ss.resolved_stage_key IS NULL
                THEN 'No authoritative stage key could be resolved for this scene.'
            WHEN st.stage_id IS NULL
                THEN 'No ref.stage row exists for resolved stage key ' || ss.resolved_stage_key || '.'
            WHEN ls.lor_scene_id IS NULL
                THEN 'Scene will be added for permanent stage_id ' || st.stage_id || '.'
            WHEN ls.stage_id IS DISTINCT FROM st.stage_id
              OR ls.scene_name IS DISTINCT FROM ss.scene_name
              OR ls.scene_section IS DISTINCT FROM ss.scene_section
              OR ls.background_file IS DISTINCT FROM ss.background_file
              OR ls.h_scroll IS DISTINCT FROM ss.h_scroll
              OR ls.v_scroll IS DISTINCT FROM ss.v_scroll
              OR ls.zoom IS DISTINCT FROM ss.zoom
              OR ls.create_grid_view IS DISTINCT FROM ss.create_grid_view
                THEN 'Existing production scene metadata differs from the latest ingest.'
            ELSE 'Production scene already matches the latest ingest.'
        END AS operator_message
    FROM scene_source AS ss
    LEFT JOIN ref.stage AS st
      ON st.stage_key = ss.resolved_stage_key
    LEFT JOIN ref.lor_scene AS ls
      ON ls.preview_uuid = ss.preview_id
     AND ls.scene_uuid = ss.scene_id
)
SELECT *
FROM classified
ORDER BY
    is_blocking DESC,
    CASE classification
        WHEN 'BLOCKED_SCENE_STAGE_NOT_RESOLVED' THEN 1
        WHEN 'ADD_SCENE' THEN 2
        WHEN 'UPDATE_SCENE' THEN 3
        WHEN 'UNCHANGED_SCENE' THEN 4
        ELSE 99
    END,
    preview_id,
    scene_id;
