/*
Schema: lor_snap / ref
Object: Current-ingest reconciliation integrity checks
Filename: 05_latest_ingest_integrity_checks.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return one exportable defect list for production identity and current LOR
  raw-identity and SPARE safety checks.

Safety:
  SELECT only. Does not call P1, P2, or P3 and does not modify any object.

Source contract:
  Reads the current ingest only through lor_snap.v_current_run,
  lor_snap.v_current_props, lor_snap.v_current_sub_props,
  lor_snap.v_current_scene_lor_props, and lor_snap.v_current_previews.

Revision History:
  2026-08-02  GAL / OpenAI  Validate raw_prop_id completeness and scene
                           membership agreement with its scoped source row.
  2026-08-01  GAL / OpenAI  Use the established lor_snap.v_current_* snapshot interface.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH defects AS (
    SELECT
        cr.import_run_id,
        'DUPLICATE_PRODUCTION_DISPLAY_NAME'::text AS defect_code,
        upper(btrim(d.display_name)) AS entity_key,
        count(*)::integer AS occurrence_count,
        string_agg(
            d.display_id::text || ': ' || d.display_name ||
            ' [lor_prop_id=' || coalesce(d.lor_prop_id, '<null>') || ']',
            E'\n' ORDER BY d.display_id
        ) AS details
    FROM ref.display AS d
    CROSS JOIN lor_snap.v_current_run AS cr
    GROUP BY cr.import_run_id, upper(btrim(d.display_name))
    HAVING count(*) > 1

    UNION ALL

    SELECT
        p.import_run_id,
        'MISSING_PROP_RAW_PROP_ID'::text,
        p.prop_id,
        1::integer,
        'preview_id=' || coalesce(p.preview_id, '<null>') ||
        '; prop_name=' || coalesce(p.name, '<null>')
    FROM lor_snap.v_current_props AS p
    WHERE NULLIF(btrim(p.raw_prop_id), '') IS NULL

    UNION ALL

    SELECT
        sp.import_run_id,
        'MISSING_SUBPROP_RAW_PROP_ID'::text,
        sp.sub_prop_id,
        1::integer,
        'preview_id=' || coalesce(sp.preview_id, '<null>') ||
        '; subprop_name=' || coalesce(sp.name, '<null>')
    FROM lor_snap.v_current_sub_props AS sp
    WHERE NULLIF(btrim(sp.raw_prop_id), '') IS NULL

    UNION ALL

    SELECT
        slp.import_run_id,
        'MISSING_SCENE_MEMBERSHIP_RAW_PROP_ID'::text,
        slp.prop_id,
        1::integer,
        'preview_id=' || coalesce(slp.preview_id, '<null>') ||
        '; scene_id=' || coalesce(slp.scene_id, '<null>')
    FROM lor_snap.v_current_scene_lor_props AS slp
    WHERE NULLIF(btrim(slp.raw_prop_id), '') IS NULL

    UNION ALL

    SELECT
        slp.import_run_id,
        'SCENE_MEMBERSHIP_RAW_PROP_ID_MISMATCH'::text,
        slp.prop_id,
        1::integer,
        'preview_id=' || coalesce(slp.preview_id, '<null>') ||
        '; scene_id=' || coalesce(slp.scene_id, '<null>') ||
        '; membership_raw_prop_id=' || coalesce(slp.raw_prop_id, '<null>')
    FROM lor_snap.v_current_scene_lor_props AS slp
    WHERE NOT EXISTS (
        SELECT 1
        FROM lor_snap.v_current_props AS p
        WHERE p.import_run_id = slp.import_run_id
          AND p.prop_id = slp.prop_id
          AND p.raw_prop_id = slp.raw_prop_id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM lor_snap.v_current_sub_props AS sp
        WHERE sp.import_run_id = slp.import_run_id
          AND sp.sub_prop_id = slp.prop_id
          AND sp.raw_prop_id = slp.raw_prop_id
    )

    UNION ALL

    SELECT
        cr.import_run_id,
        'DUPLICATE_PRODUCTION_LOR_UUID'::text,
        d.lor_prop_id,
        count(*)::integer,
        string_agg(d.display_id::text || ': ' || d.display_name, E'\n' ORDER BY d.display_id)
    FROM ref.display AS d
    CROSS JOIN lor_snap.v_current_run AS cr
    WHERE d.lor_prop_id IS NOT NULL AND btrim(d.lor_prop_id) <> ''
    GROUP BY cr.import_run_id, d.lor_prop_id
    HAVING count(*) > 1

    UNION ALL

    SELECT
        p.import_run_id,
        'SPARE_COMMENT_MISSING_OR_INVALID'::text,
        p.prop_id,
        1::integer,
        'preview=' || coalesce(pr.name, '<unknown>') ||
        '; stage=' || coalesce(pr.stage_id, '<unknown>') ||
        '; prop_name=' || coalesce(p.name, '<null>') ||
        '; lor_comment=' || coalesce(p.lor_comment, '<null>')
    FROM lor_snap.v_current_props AS p
    JOIN lor_snap.v_current_previews AS pr ON pr.id = p.preview_id
    WHERE upper(btrim(coalesce(p.name, ''))) ~ '(^|[[:space:]])SPARE[[:space:]]*$'
      AND upper(btrim(coalesce(p.lor_comment, ''))) <> 'SPARE'
)
SELECT import_run_id, defect_code, entity_key, occurrence_count, details
FROM defects
ORDER BY defect_code, entity_key;
