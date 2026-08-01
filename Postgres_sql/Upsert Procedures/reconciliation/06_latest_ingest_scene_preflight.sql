/*
Schema: lor_snap / ref
Object: Latest-ingest scene production preflight
Filename: 06_latest_ingest_scene_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Compare scenes and scene-to-display memberships from the latest complete LOR
  snapshot with the current production projection in ref.lor_scene and
  ref.lor_scene_display.

Safety:
  SELECT only. Does not create objects, call P1/P2/P3, or modify production data.

Rules:
  - The latest import_run_id is selected automatically at execution time.
  - Dedicated previews control physical stage assignment for every scene they
    contain. Scene text cannot override the preview StageID.
  - Shared previews use preview_id + scene_id and the scene StageID.
  - Scene identity is preview_uuid + scene_uuid.
  - Display identity remains ref.display.display_id.
  - A display may have only one current scene within one preview.
  - Missing stage or display resolution is blocking for only that candidate.
  - Existing production rows are not deleted by this preflight.

Result:
  Returns one exportable result set containing scene and membership candidates.
  Exact matches are included as UNCHANGED rows for first-run verification.

Revision History:
  2026-08-01  GAL / OpenAI  Initial latest-ingest scene production preflight.
*/

WITH selected_run AS (
    SELECT ir.import_run_id, ir.run_ts
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
scene_source AS (
    SELECT
        s.import_run_id,
        s.preview_id,
        s.scene_id,
        btrim(s.name) AS scene_name,
        btrim(p.name) AS preview_name,
        (
            p.name ILIKE '%master musical preview%'
            OR count(DISTINCT lower(btrim(s2.stage_id))) FILTER (
                WHERE btrim(coalesce(s2.stage_id, '')) <> ''
            ) OVER (PARTITION BY s.import_run_id, s.preview_id) > 1
        ) AS is_shared_preview,
        lower(btrim(p.stage_id)) AS preview_stage_key,
        lower(btrim(s.stage_id)) AS declared_scene_stage_key,
        CASE
            WHEN p.name ILIKE '%master musical preview%'
              OR count(DISTINCT lower(btrim(s2.stage_id))) FILTER (
                    WHERE btrim(coalesce(s2.stage_id, '')) <> ''
                 ) OVER (PARTITION BY s.import_run_id, s.preview_id) > 1
                THEN lower(btrim(s.stage_id))
            ELSE lower(btrim(p.stage_id))
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
    JOIN lor_snap.previews AS p
      ON p.import_run_id = s.import_run_id
     AND p.id = s.preview_id
    LEFT JOIN lor_snap.scenes AS s2
      ON s2.import_run_id = s.import_run_id
     AND s2.preview_id = s.preview_id
),
scene_candidates AS (
    SELECT DISTINCT
        ss.import_run_id,
        ss.preview_id,
        ss.scene_id,
        ss.scene_name,
        ss.preview_name,
        ss.is_shared_preview,
        ss.preview_stage_key,
        ss.declared_scene_stage_key,
        ss.resolved_stage_key,
        ss.scene_section,
        ss.background_file,
        ss.h_scroll,
        ss.v_scroll,
        ss.zoom,
        ss.create_grid_view,
        st.stage_id AS resolved_stage_id,
        ls.lor_scene_id AS existing_lor_scene_id,
        ls.stage_id AS existing_stage_id,
        ls.scene_name AS existing_scene_name,
        ls.scene_section AS existing_scene_section,
        ls.background_file AS existing_background_file,
        ls.h_scroll AS existing_h_scroll,
        ls.v_scroll AS existing_v_scroll,
        ls.zoom AS existing_zoom,
        ls.create_grid_view AS existing_create_grid_view
    FROM scene_source AS ss
    LEFT JOIN ref.stage AS st
      ON st.stage_key = ss.resolved_stage_key
    LEFT JOIN ref.lor_scene AS ls
      ON ls.preview_uuid = ss.preview_id
     AND ls.scene_uuid = ss.scene_id
),
scene_results AS (
    SELECT
        sc.import_run_id,
        'SCENE'::text AS entity_type,
        sc.preview_id,
        sc.scene_id,
        sc.scene_name,
        sc.preview_name,
        sc.resolved_stage_key,
        sc.declared_scene_stage_key,
        sc.resolved_stage_id AS stage_id,
        NULL::bigint AS display_id,
        NULL::text AS display_name,
        sc.existing_lor_scene_id AS lor_scene_id,
        NULL::bigint AS existing_lor_scene_display_id,
        CASE
            WHEN sc.resolved_stage_key IS NULL OR sc.resolved_stage_id IS NULL
                THEN 'BLOCKED_SCENE_STAGE_NOT_RESOLVED'
            WHEN sc.existing_lor_scene_id IS NULL
                THEN 'ADD_SCENE'
            WHEN sc.existing_stage_id IS DISTINCT FROM sc.resolved_stage_id
              OR sc.existing_scene_name IS DISTINCT FROM sc.scene_name
              OR sc.existing_scene_section IS DISTINCT FROM sc.scene_section
              OR sc.existing_background_file IS DISTINCT FROM sc.background_file
              OR sc.existing_h_scroll IS DISTINCT FROM sc.h_scroll
              OR sc.existing_v_scroll IS DISTINCT FROM sc.v_scroll
              OR sc.existing_zoom IS DISTINCT FROM sc.zoom
              OR sc.existing_create_grid_view IS DISTINCT FROM sc.create_grid_view
                THEN 'UPDATE_SCENE'
            ELSE 'UNCHANGED_SCENE'
        END AS classification,
        (sc.resolved_stage_key IS NULL OR sc.resolved_stage_id IS NULL) AS is_blocking,
        CASE
            WHEN sc.resolved_stage_key IS NULL
                THEN 'No authoritative stage key could be resolved for this scene.'
            WHEN sc.resolved_stage_id IS NULL
                THEN 'No ref.stage row exists for resolved stage key ' || sc.resolved_stage_key || '.'
            WHEN sc.existing_lor_scene_id IS NULL
                THEN 'Scene will be added for permanent stage_id ' || sc.resolved_stage_id || '.'
            WHEN sc.existing_stage_id IS DISTINCT FROM sc.resolved_stage_id
              OR sc.existing_scene_name IS DISTINCT FROM sc.scene_name
              OR sc.existing_scene_section IS DISTINCT FROM sc.scene_section
              OR sc.existing_background_file IS DISTINCT FROM sc.background_file
              OR sc.existing_h_scroll IS DISTINCT FROM sc.h_scroll
              OR sc.existing_v_scroll IS DISTINCT FROM sc.v_scroll
              OR sc.existing_zoom IS DISTINCT FROM sc.zoom
              OR sc.existing_create_grid_view IS DISTINCT FROM sc.create_grid_view
                THEN 'Existing production scene metadata differs from the latest ingest.'
            ELSE 'Production scene already matches the latest ingest.'
        END AS operator_message
    FROM scene_candidates AS sc
),
membership_source AS (
    SELECT DISTINCT
        slp.import_run_id,
        slp.preview_id,
        slp.scene_id,
        slp.prop_id AS lor_prop_id,
        nullif(to_jsonb(slp)->>'scene_prop_ordinal', '')::integer AS scene_prop_ordinal,
        to_jsonb(slp)->>'scene_role' AS scene_role,
        to_jsonb(slp)->>'source' AS membership_source
    FROM lor_snap.scene_lor_props AS slp
    JOIN selected_run AS sr
      ON sr.import_run_id = slp.import_run_id
),
membership_resolution AS (
    SELECT
        ms.*,
        d.display_id,
        d.display_name,
        count(DISTINCT ms.scene_id) OVER (
            PARTITION BY ms.import_run_id, ms.preview_id, d.display_id
        ) AS source_scene_count_for_display,
        sc.resolved_stage_id,
        sc.existing_lor_scene_id,
        lsd.lor_scene_id AS current_lor_scene_id
    FROM membership_source AS ms
    LEFT JOIN ref.display AS d
      ON d.lor_prop_id = ms.lor_prop_id
    LEFT JOIN scene_candidates AS sc
      ON sc.import_run_id = ms.import_run_id
     AND sc.preview_id = ms.preview_id
     AND sc.scene_id = ms.scene_id
    LEFT JOIN ref.lor_scene_display AS lsd
      ON lsd.preview_uuid = ms.preview_id
     AND lsd.display_id = d.display_id
),
membership_results AS (
    SELECT
        mr.import_run_id,
        'SCENE_DISPLAY'::text AS entity_type,
        mr.preview_id,
        mr.scene_id,
        sc.scene_name,
        sc.preview_name,
        sc.resolved_stage_key,
        sc.declared_scene_stage_key,
        mr.resolved_stage_id AS stage_id,
        mr.display_id,
        mr.display_name,
        mr.existing_lor_scene_id AS lor_scene_id,
        mr.current_lor_scene_id AS existing_lor_scene_display_id,
        CASE
            WHEN mr.display_id IS NULL
                THEN 'BLOCKED_DISPLAY_NOT_RESOLVED'
            WHEN mr.resolved_stage_id IS NULL
                THEN 'BLOCKED_PARENT_SCENE_NOT_RESOLVED'
            WHEN mr.source_scene_count_for_display > 1
                THEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY'
            WHEN mr.current_lor_scene_id IS NULL
                THEN 'ADD_SCENE_DISPLAY'
            WHEN mr.current_lor_scene_id IS DISTINCT FROM mr.existing_lor_scene_id
                THEN 'REASSOCIATE_SCENE_DISPLAY'
            ELSE 'UNCHANGED_SCENE_DISPLAY'
        END AS classification,
        (
            mr.display_id IS NULL
            OR mr.resolved_stage_id IS NULL
            OR mr.source_scene_count_for_display > 1
        ) AS is_blocking,
        CASE
            WHEN mr.display_id IS NULL
                THEN 'LOR prop UUID ' || mr.lor_prop_id || ' does not resolve to one ref.display row.'
            WHEN mr.resolved_stage_id IS NULL
                THEN 'The parent scene does not resolve to a production stage.'
            WHEN mr.source_scene_count_for_display > 1
                THEN 'Display appears in more than one scene within preview ' || mr.preview_id || '.'
            WHEN mr.current_lor_scene_id IS NULL
                THEN 'Scene membership will be added for permanent display_id ' || mr.display_id || '.'
            WHEN mr.current_lor_scene_id IS DISTINCT FROM mr.existing_lor_scene_id
                THEN 'Display is assigned to a different production scene within this preview.'
            ELSE 'Production scene membership already matches the latest ingest.'
        END AS operator_message
    FROM membership_resolution AS mr
    LEFT JOIN scene_candidates AS sc
      ON sc.import_run_id = mr.import_run_id
     AND sc.preview_id = mr.preview_id
     AND sc.scene_id = mr.scene_id
)
SELECT *
FROM (
    SELECT * FROM scene_results
    UNION ALL
    SELECT * FROM membership_results
) AS results
ORDER BY
    is_blocking DESC,
    CASE classification
        WHEN 'BLOCKED_SCENE_STAGE_NOT_RESOLVED' THEN 1
        WHEN 'BLOCKED_PARENT_SCENE_NOT_RESOLVED' THEN 2
        WHEN 'BLOCKED_DISPLAY_NOT_RESOLVED' THEN 3
        WHEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY' THEN 4
        WHEN 'ADD_SCENE' THEN 5
        WHEN 'UPDATE_SCENE' THEN 6
        WHEN 'ADD_SCENE_DISPLAY' THEN 7
        WHEN 'REASSOCIATE_SCENE_DISPLAY' THEN 8
        WHEN 'UNCHANGED_SCENE' THEN 9
        WHEN 'UNCHANGED_SCENE_DISPLAY' THEN 10
        ELSE 99
    END,
    preview_id,
    scene_id,
    display_id NULLS FIRST;
