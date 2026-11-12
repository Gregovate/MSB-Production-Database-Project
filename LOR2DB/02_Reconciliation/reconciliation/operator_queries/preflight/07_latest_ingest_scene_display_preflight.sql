/*
Schema: lor_snap / ops / ref
Object: Current-ingest scene-display preflight
Filename: 07_latest_ingest_scene_display_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Compare physical-display scene memberships from the current LOR snapshot with
  ref.lor_scene_display.

Safety:
  SELECT only. Does not create temporary or persistent objects, call P1/P2/P3,
  or modify production data.

Source contract:
  - Current ingest: lor_snap.v_current_run.
  - Current scenes: lor_snap.v_current_scenes.
  - Current memberships: lor_snap.v_current_scene_lor_props.
  - Current physical-display resolution: ops.v_lor_display_reconciliation
    restricted to lor_snap.v_current_run.
  - All reconciliation scripts 01-07 use the same current snapshot interface.

Rules:
  - Scene identity is preview_uuid + scene_uuid.
  - Display identity is ref.display.display_id.
  - EXCLUDED_NONPHYSICAL rows are not scene-display candidates.
  - One physical display may have only one current scene within one preview.
  - A missing ref.lor_scene parent is not blocking when 06 classifies it as a
    valid ADD_SCENE candidate from the same current snapshot.

Revision History:
  2026-08-02  GAL / OpenAI  Resolve display identity through raw_prop_id while
                           retaining scoped prop_id as occurrence evidence.
  2026-08-01  GAL / OpenAI  Replace temporary working tables with the established
                           lor_snap.v_current_* snapshot interface.
  2026-08-01  GAL / OpenAI  Reuse validated P2 display reconciliation mapping.
  2026-08-01  GAL / OpenAI  Initial latest-ingest scene-display preflight.
*/

WITH current_display_map AS MATERIALIZED (
    SELECT
        v.import_run_id,
        v.lor_prop_id AS source_lor_prop_id,
        v.display_id,
        v.production_display_name AS display_name,
        v.classification_code AS display_classification
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
      AND v.display_id IS NOT NULL
),
current_scene_source AS (
    SELECT
        s.import_run_id,
        s.preview_id,
        s.scene_id,
        btrim(s.name) AS scene_name,
        btrim(p.name) AS preview_name
    FROM lor_snap.v_current_scenes AS s
    JOIN lor_snap.v_current_previews AS p ON p.id = s.preview_id
),
physical_membership AS MATERIALIZED (
    SELECT DISTINCT
        slp.import_run_id,
        slp.preview_id,
        slp.scene_id,
        slp.prop_id AS source_prop_id,
        slp.raw_prop_id AS source_lor_prop_id,
        nullif(to_jsonb(slp)->>'scene_prop_ordinal', '')::integer AS scene_prop_ordinal,
        to_jsonb(slp)->>'scene_role' AS scene_role,
        to_jsonb(slp)->>'source' AS membership_source,
        dm.display_id,
        dm.display_name,
        dm.display_classification
    FROM lor_snap.v_current_scene_lor_props AS slp
    JOIN current_display_map AS dm
      ON dm.import_run_id = slp.import_run_id
     AND dm.source_lor_prop_id = slp.raw_prop_id
),
membership_counts AS (
    SELECT
        pm.preview_id,
        pm.display_id,
        count(DISTINCT pm.scene_id) AS source_scene_count_for_display
    FROM physical_membership AS pm
    GROUP BY pm.preview_id, pm.display_id
),
resolved AS (
    SELECT
        pm.import_run_id,
        pm.preview_id,
        pm.scene_id,
        cs.scene_name,
        cs.preview_name,
        pm.source_lor_prop_id,
        pm.display_id,
        pm.display_name,
        pm.display_classification,
        pm.scene_prop_ordinal,
        pm.scene_role,
        pm.membership_source,
        mc.source_scene_count_for_display,
        target_scene.lor_scene_id AS target_lor_scene_id,
        current_membership.lor_scene_id AS current_lor_scene_id,
        current_scene.scene_uuid AS current_scene_uuid,
        current_scene.scene_name AS current_scene_name
    FROM physical_membership AS pm
    JOIN membership_counts AS mc
      ON mc.preview_id = pm.preview_id
     AND mc.display_id = pm.display_id
    LEFT JOIN current_scene_source AS cs
      ON cs.preview_id = pm.preview_id
     AND cs.scene_id = pm.scene_id
    LEFT JOIN ref.lor_scene AS target_scene
      ON target_scene.preview_uuid = pm.preview_id
     AND target_scene.scene_uuid = pm.scene_id
    LEFT JOIN ref.lor_scene_display AS current_membership
      ON current_membership.preview_uuid = pm.preview_id
     AND current_membership.display_id = pm.display_id
    LEFT JOIN ref.lor_scene AS current_scene
      ON current_scene.lor_scene_id = current_membership.lor_scene_id
),
classified AS (
    SELECT
        r.*,
        CASE
            WHEN r.scene_name IS NULL
                THEN 'BLOCKED_PARENT_SCENE_NOT_IN_CURRENT_SNAPSHOT'
            WHEN r.source_scene_count_for_display > 1
                THEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY'
            WHEN r.current_lor_scene_id IS NULL
                THEN 'ADD_SCENE_DISPLAY'
            WHEN r.target_lor_scene_id IS NOT NULL
             AND r.current_lor_scene_id = r.target_lor_scene_id
                THEN 'UNCHANGED_SCENE_DISPLAY'
            ELSE 'REASSOCIATE_SCENE_DISPLAY'
        END AS classification,
        (r.scene_name IS NULL OR r.source_scene_count_for_display > 1) AS is_blocking,
        CASE
            WHEN r.scene_name IS NULL
                THEN 'The referenced preview_id + scene_id is not present in the current LOR snapshot.'
            WHEN r.source_scene_count_for_display > 1
                THEN 'Display appears in more than one scene within preview ' || r.preview_id || '.'
            WHEN r.current_lor_scene_id IS NULL AND r.target_lor_scene_id IS NULL
                THEN 'Membership will be added after its ADD_SCENE parent is inserted.'
            WHEN r.current_lor_scene_id IS NULL
                THEN 'Membership will be added to existing lor_scene_id ' || r.target_lor_scene_id || '.'
            WHEN r.target_lor_scene_id IS NOT NULL
             AND r.current_lor_scene_id = r.target_lor_scene_id
                THEN 'Production scene membership already matches the current LOR snapshot.'
            ELSE 'Display will be reassociated from the current scene to current LOR scene ' || r.scene_id || '.'
        END AS operator_message
    FROM resolved AS r
)
SELECT *
FROM classified
ORDER BY
    is_blocking DESC,
    classification,
    preview_id,
    scene_id,
    display_id,
    source_lor_prop_id;
