/*
Schema: lor_snap / ref
Object: Latest-ingest scene-display preflight
Filename: 07_latest_ingest_scene_display_preflight.sql
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Compare scene-to-display memberships from the latest complete LOR snapshot
  with the current production projection in ref.lor_scene_display.

Safety:
  SELECT only. Does not create objects, call P1/P2/P3, or modify production data.

Rules:
  - The latest import_run_id is selected automatically at execution time.
  - Scene identity is preview_uuid + scene_uuid.
  - Display identity remains ref.display.display_id.
  - The underlying LOR prop UUID is the persistent display-link evidence.
    Preview-qualified lor_prop_id values are assignment context only.
  - A display may have only one current scene within one preview.
  - The parent scene may already exist in ref.lor_scene or be a valid ADD_SCENE
    candidate from 06_latest_ingest_scene_preflight.sql.
  - Missing or non-unique display resolution blocks only that membership.
  - Existing production rows are not deleted by this preflight.

Result:
  Returns one exportable result set containing scene-display candidates classified
  as ADD_SCENE_DISPLAY, REASSOCIATE_SCENE_DISPLAY,
  UNCHANGED_SCENE_DISPLAY, or a blocking resolution issue.

Revision History:
  2026-08-01  GAL / OpenAI  Resolve display identity by underlying prop UUID and block non-unique production UUID links.
  2026-08-01  GAL / OpenAI  Initial latest-ingest scene-display preflight.
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
        btrim(p.name) AS preview_name
    FROM lor_snap.scenes AS s
    JOIN selected_run AS sr
      ON sr.import_run_id = s.import_run_id
    JOIN lor_snap.previews AS p
      ON p.import_run_id = s.import_run_id
     AND p.id = s.preview_id
),
membership_source AS (
    SELECT DISTINCT
        slp.import_run_id,
        slp.preview_id,
        slp.scene_id,
        slp.prop_id AS source_lor_prop_id,
        regexp_replace(btrim(slp.prop_id), '^.*:', '') AS lor_prop_uuid,
        nullif(to_jsonb(slp)->>'scene_prop_ordinal', '')::integer AS scene_prop_ordinal,
        to_jsonb(slp)->>'scene_role' AS scene_role,
        to_jsonb(slp)->>'source' AS membership_source
    FROM lor_snap.scene_lor_props AS slp
    JOIN selected_run AS sr
      ON sr.import_run_id = slp.import_run_id
),
membership_counts AS (
    SELECT
        ms.import_run_id,
        ms.preview_id,
        ms.lor_prop_uuid,
        count(DISTINCT ms.scene_id) AS source_scene_count_for_display
    FROM membership_source AS ms
    GROUP BY
        ms.import_run_id,
        ms.preview_id,
        ms.lor_prop_uuid
),
production_display_uuid AS (
    SELECT
        d.display_id,
        d.display_name,
        d.lor_prop_id AS production_lor_prop_id,
        regexp_replace(btrim(d.lor_prop_id), '^.*:', '') AS lor_prop_uuid,
        count(*) OVER (
            PARTITION BY regexp_replace(btrim(d.lor_prop_id), '^.*:', '')
        ) AS production_uuid_count
    FROM ref.display AS d
    WHERE d.lor_prop_id IS NOT NULL
      AND btrim(d.lor_prop_id) <> ''
),
resolved AS (
    SELECT
        ms.import_run_id,
        ms.preview_id,
        ms.scene_id,
        ss.scene_name,
        ss.preview_name,
        ms.source_lor_prop_id,
        ms.lor_prop_uuid,
        ms.scene_prop_ordinal,
        ms.scene_role,
        ms.membership_source,
        mc.source_scene_count_for_display,
        pdu.production_uuid_count,
        CASE
            WHEN pdu.production_uuid_count = 1 THEN pdu.display_id
            ELSE NULL
        END AS display_id,
        CASE
            WHEN pdu.production_uuid_count = 1 THEN pdu.display_name
            ELSE NULL
        END AS display_name,
        ls.lor_scene_id AS target_lor_scene_id,
        lsd.lor_scene_id AS current_lor_scene_id,
        current_scene.scene_uuid AS current_scene_uuid,
        current_scene.scene_name AS current_scene_name
    FROM membership_source AS ms
    JOIN membership_counts AS mc
      ON mc.import_run_id = ms.import_run_id
     AND mc.preview_id = ms.preview_id
     AND mc.lor_prop_uuid = ms.lor_prop_uuid
    LEFT JOIN scene_source AS ss
      ON ss.import_run_id = ms.import_run_id
     AND ss.preview_id = ms.preview_id
     AND ss.scene_id = ms.scene_id
    LEFT JOIN production_display_uuid AS pdu
      ON pdu.lor_prop_uuid = ms.lor_prop_uuid
    LEFT JOIN ref.lor_scene AS ls
      ON ls.preview_uuid = ms.preview_id
     AND ls.scene_uuid = ms.scene_id
    LEFT JOIN ref.lor_scene_display AS lsd
      ON lsd.preview_uuid = ms.preview_id
     AND lsd.display_id = CASE
            WHEN pdu.production_uuid_count = 1 THEN pdu.display_id
            ELSE NULL
         END
    LEFT JOIN ref.lor_scene AS current_scene
      ON current_scene.lor_scene_id = lsd.lor_scene_id
),
classified AS (
    SELECT
        r.import_run_id,
        r.preview_id,
        r.scene_id,
        r.scene_name,
        r.preview_name,
        r.source_lor_prop_id,
        r.lor_prop_uuid,
        r.display_id,
        r.display_name,
        r.production_uuid_count,
        r.scene_prop_ordinal,
        r.scene_role,
        r.membership_source,
        r.source_scene_count_for_display,
        r.target_lor_scene_id,
        r.current_lor_scene_id,
        r.current_scene_uuid,
        r.current_scene_name,
        CASE
            WHEN r.scene_name IS NULL
                THEN 'BLOCKED_PARENT_SCENE_NOT_IN_LATEST_INGEST'
            WHEN coalesce(r.production_uuid_count, 0) = 0
                THEN 'BLOCKED_DISPLAY_NOT_RESOLVED'
            WHEN r.production_uuid_count > 1
                THEN 'BLOCKED_DISPLAY_UUID_NOT_UNIQUE'
            WHEN r.source_scene_count_for_display > 1
                THEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY'
            WHEN r.current_lor_scene_id IS NULL
                THEN 'ADD_SCENE_DISPLAY'
            WHEN r.target_lor_scene_id IS NOT NULL
             AND r.current_lor_scene_id = r.target_lor_scene_id
                THEN 'UNCHANGED_SCENE_DISPLAY'
            ELSE 'REASSOCIATE_SCENE_DISPLAY'
        END AS classification,
        (
            r.scene_name IS NULL
            OR coalesce(r.production_uuid_count, 0) <> 1
            OR r.source_scene_count_for_display > 1
        ) AS is_blocking,
        CASE
            WHEN r.scene_name IS NULL
                THEN 'The referenced preview_id + scene_id is not present in the latest ingest.'
            WHEN coalesce(r.production_uuid_count, 0) = 0
                THEN 'Underlying LOR prop UUID ' || r.lor_prop_uuid || ' does not resolve to a ref.display row.'
            WHEN r.production_uuid_count > 1
                THEN 'Underlying LOR prop UUID ' || r.lor_prop_uuid || ' resolves to multiple ref.display rows.'
            WHEN r.source_scene_count_for_display > 1
                THEN 'Display appears in more than one scene within preview ' || r.preview_id || '.'
            WHEN r.current_lor_scene_id IS NULL AND r.target_lor_scene_id IS NULL
                THEN 'Membership will be added after its ADD_SCENE parent is inserted.'
            WHEN r.current_lor_scene_id IS NULL
                THEN 'Membership will be added to existing lor_scene_id ' || r.target_lor_scene_id || '.'
            WHEN r.target_lor_scene_id IS NOT NULL
             AND r.current_lor_scene_id = r.target_lor_scene_id
                THEN 'Production scene membership already matches the latest ingest.'
            ELSE 'Display will be reassociated from the current scene to latest-ingest scene ' || r.scene_id || '.'
        END AS operator_message
    FROM resolved AS r
)
SELECT *
FROM classified
ORDER BY
    is_blocking DESC,
    CASE classification
        WHEN 'BLOCKED_PARENT_SCENE_NOT_IN_LATEST_INGEST' THEN 1
        WHEN 'BLOCKED_DISPLAY_NOT_RESOLVED' THEN 2
        WHEN 'BLOCKED_DISPLAY_UUID_NOT_UNIQUE' THEN 3
        WHEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY' THEN 4
        WHEN 'ADD_SCENE_DISPLAY' THEN 5
        WHEN 'REASSOCIATE_SCENE_DISPLAY' THEN 6
        WHEN 'UNCHANGED_SCENE_DISPLAY' THEN 7
        ELSE 99
    END,
    preview_id,
    scene_id,
    display_id NULLS FIRST,
    lor_prop_uuid;
