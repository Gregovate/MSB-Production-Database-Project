/*
Schema: lor_snap / ops / ref / pg_temp
Object: Latest-ingest scene-display preflight
Filename: 07_latest_ingest_scene_display_preflight.sql
Type: Read-only production validation with session-local working tables
Owner: msbadmin

Purpose:
  Compare physical display scene memberships from the latest complete LOR
  snapshot with the current production projection in ref.lor_scene_display.

Safety:
  Does not modify persistent database objects or production data.
  Creates only session-local temporary working tables, which are dropped at the
  end of the script and also disappear automatically when the session ends.
  Does not call P1, P2, or P3.

Execution:
  Run the entire file as one script in one database session.

Rules:
  - The latest import_run_id is captured once at the beginning of execution.
  - Scene identity is preview_uuid + scene_uuid.
  - Display identity remains ref.display.display_id.
  - Physical display resolution is reused from ops.v_lor_display_reconciliation.
  - The validated P2 display map is calculated once into a temporary indexed
    working table and reused by all downstream scene-membership checks.
  - EXCLUDED_NONPHYSICAL rows are not candidates for ref.lor_scene_display.
  - A display may have only one current scene within one preview.
  - The parent scene may already exist in ref.lor_scene or be a valid ADD_SCENE
    candidate from 06_latest_ingest_scene_preflight.sql.
  - Existing production rows are not deleted by this preflight.

Result:
  Returns one final exportable result set containing physical scene-display
  candidates classified as ADD_SCENE_DISPLAY, REASSOCIATE_SCENE_DISPLAY,
  UNCHANGED_SCENE_DISPLAY, or a blocking resolution issue.

Revision History:
  2026-08-01  GAL / OpenAI  Replace repeatedly expanded CTE/view plan with session-local indexed working tables.
  2026-08-01  GAL / OpenAI  Materialize the validated P2 display map once per execution.
  2026-08-01  GAL / OpenAI  Reuse validated P2 display reconciliation mapping and exclude nonphysical scene members.
  2026-08-01  GAL / OpenAI  Resolve display identity by underlying prop UUID and block non-unique production UUID links.
  2026-08-01  GAL / OpenAI  Initial latest-ingest scene-display preflight.
*/

DROP TABLE IF EXISTS pg_temp.lor_recon_context;
DROP TABLE IF EXISTS pg_temp.lor_p2_display_map;
DROP TABLE IF EXISTS pg_temp.lor_scene_source;
DROP TABLE IF EXISTS pg_temp.lor_scene_membership_source;
DROP TABLE IF EXISTS pg_temp.lor_physical_scene_membership;
DROP TABLE IF EXISTS pg_temp.lor_scene_membership_count;

CREATE TEMP TABLE lor_recon_context
ON COMMIT PRESERVE ROWS
AS
SELECT
    ir.import_run_id,
    ir.run_ts
FROM lor_snap.import_run AS ir
ORDER BY ir.import_run_id DESC
LIMIT 1;

CREATE UNIQUE INDEX lor_recon_context_pk
    ON lor_recon_context (import_run_id);

CREATE TEMP TABLE lor_p2_display_map
ON COMMIT PRESERVE ROWS
AS
SELECT
    v.import_run_id,
    v.lor_prop_id AS source_lor_prop_id,
    v.display_id,
    v.production_display_name AS display_name,
    v.classification_code AS display_classification
FROM ops.v_lor_display_reconciliation AS v
JOIN lor_recon_context AS rc
  ON rc.import_run_id = v.import_run_id
WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
  AND v.display_id IS NOT NULL;

CREATE UNIQUE INDEX lor_p2_display_map_source_uq
    ON lor_p2_display_map (import_run_id, source_lor_prop_id);

CREATE INDEX lor_p2_display_map_display_idx
    ON lor_p2_display_map (import_run_id, display_id);

ANALYZE lor_p2_display_map;

CREATE TEMP TABLE lor_scene_source
ON COMMIT PRESERVE ROWS
AS
SELECT
    s.import_run_id,
    s.preview_id,
    s.scene_id,
    btrim(s.name) AS scene_name,
    btrim(p.name) AS preview_name
FROM lor_snap.scenes AS s
JOIN lor_recon_context AS rc
  ON rc.import_run_id = s.import_run_id
JOIN lor_snap.previews AS p
  ON p.import_run_id = s.import_run_id
 AND p.id = s.preview_id;

CREATE UNIQUE INDEX lor_scene_source_uq
    ON lor_scene_source (import_run_id, preview_id, scene_id);

CREATE TEMP TABLE lor_scene_membership_source
ON COMMIT PRESERVE ROWS
AS
SELECT DISTINCT
    slp.import_run_id,
    slp.preview_id,
    slp.scene_id,
    slp.prop_id AS source_lor_prop_id,
    nullif(to_jsonb(slp)->>'scene_prop_ordinal', '')::integer AS scene_prop_ordinal,
    to_jsonb(slp)->>'scene_role' AS scene_role,
    to_jsonb(slp)->>'source' AS membership_source
FROM lor_snap.scene_lor_props AS slp
JOIN lor_recon_context AS rc
  ON rc.import_run_id = slp.import_run_id;

CREATE INDEX lor_scene_membership_source_prop_idx
    ON lor_scene_membership_source (import_run_id, source_lor_prop_id);

CREATE INDEX lor_scene_membership_source_scene_idx
    ON lor_scene_membership_source (import_run_id, preview_id, scene_id);

ANALYZE lor_scene_membership_source;

CREATE TEMP TABLE lor_physical_scene_membership
ON COMMIT PRESERVE ROWS
AS
SELECT
    ms.import_run_id,
    ms.preview_id,
    ms.scene_id,
    ms.source_lor_prop_id,
    ms.scene_prop_ordinal,
    ms.scene_role,
    ms.membership_source,
    pdm.display_id,
    pdm.display_name,
    pdm.display_classification
FROM lor_scene_membership_source AS ms
JOIN lor_p2_display_map AS pdm
  ON pdm.import_run_id = ms.import_run_id
 AND pdm.source_lor_prop_id = ms.source_lor_prop_id;

CREATE INDEX lor_physical_scene_membership_scene_idx
    ON lor_physical_scene_membership (import_run_id, preview_id, scene_id);

CREATE INDEX lor_physical_scene_membership_display_idx
    ON lor_physical_scene_membership (import_run_id, preview_id, display_id);

ANALYZE lor_physical_scene_membership;

CREATE TEMP TABLE lor_scene_membership_count
ON COMMIT PRESERVE ROWS
AS
SELECT
    pm.import_run_id,
    pm.preview_id,
    pm.display_id,
    count(DISTINCT pm.scene_id) AS source_scene_count_for_display
FROM lor_physical_scene_membership AS pm
GROUP BY
    pm.import_run_id,
    pm.preview_id,
    pm.display_id;

CREATE UNIQUE INDEX lor_scene_membership_count_uq
    ON lor_scene_membership_count (import_run_id, preview_id, display_id);

ANALYZE lor_scene_membership_count;

WITH resolved AS (
    SELECT
        pm.import_run_id,
        pm.preview_id,
        pm.scene_id,
        ss.scene_name,
        ss.preview_name,
        pm.source_lor_prop_id,
        pm.display_id,
        pm.display_name,
        pm.display_classification,
        pm.scene_prop_ordinal,
        pm.scene_role,
        pm.membership_source,
        mc.source_scene_count_for_display,
        ls.lor_scene_id AS target_lor_scene_id,
        lsd.lor_scene_id AS current_lor_scene_id,
        current_scene.scene_uuid AS current_scene_uuid,
        current_scene.scene_name AS current_scene_name
    FROM lor_physical_scene_membership AS pm
    JOIN lor_scene_membership_count AS mc
      ON mc.import_run_id = pm.import_run_id
     AND mc.preview_id = pm.preview_id
     AND mc.display_id = pm.display_id
    LEFT JOIN lor_scene_source AS ss
      ON ss.import_run_id = pm.import_run_id
     AND ss.preview_id = pm.preview_id
     AND ss.scene_id = pm.scene_id
    LEFT JOIN ref.lor_scene AS ls
      ON ls.preview_uuid = pm.preview_id
     AND ls.scene_uuid = pm.scene_id
    LEFT JOIN ref.lor_scene_display AS lsd
      ON lsd.preview_uuid = pm.preview_id
     AND lsd.display_id = pm.display_id
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
        r.display_id,
        r.display_name,
        r.display_classification,
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
            OR r.source_scene_count_for_display > 1
        ) AS is_blocking,
        CASE
            WHEN r.scene_name IS NULL
                THEN 'The referenced preview_id + scene_id is not present in the latest ingest.'
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
        WHEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY' THEN 2
        WHEN 'ADD_SCENE_DISPLAY' THEN 3
        WHEN 'REASSOCIATE_SCENE_DISPLAY' THEN 4
        WHEN 'UNCHANGED_SCENE_DISPLAY' THEN 5
        ELSE 99
    END,
    preview_id,
    scene_id,
    display_id,
    source_lor_prop_id;

DROP TABLE IF EXISTS pg_temp.lor_scene_membership_count;
DROP TABLE IF EXISTS pg_temp.lor_physical_scene_membership;
DROP TABLE IF EXISTS pg_temp.lor_scene_membership_source;
DROP TABLE IF EXISTS pg_temp.lor_scene_source;
DROP TABLE IF EXISTS pg_temp.lor_p2_display_map;
DROP TABLE IF EXISTS pg_temp.lor_recon_context;
