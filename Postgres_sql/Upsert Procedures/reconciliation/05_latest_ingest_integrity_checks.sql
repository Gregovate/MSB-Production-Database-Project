/*
Schema: lor_snap / ref
Object: Latest-ingest reconciliation integrity checks
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return one exportable defect list for identity and SPARE safety checks.

Safety:
  SELECT only. Does not call P1 or P2 and does not modify any object.

Revision History:
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH selected_run AS (
    SELECT ir.import_run_id
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
defects AS (
    SELECT
        sr.import_run_id,
        'DUPLICATE_PRODUCTION_DISPLAY_NAME'::text AS defect_code,
        upper(btrim(d.display_name)) AS entity_key,
        count(*)::integer AS occurrence_count,
        string_agg(
            d.display_id::text || ': ' || d.display_name ||
            ' [lor_prop_id=' || coalesce(d.lor_prop_id, '<null>') || ']',
            E'\n' ORDER BY d.display_id
        ) AS details
    FROM ref.display AS d
    CROSS JOIN selected_run AS sr
    GROUP BY sr.import_run_id, upper(btrim(d.display_name))
    HAVING count(*) > 1

    UNION ALL

    SELECT
        sr.import_run_id,
        'DUPLICATE_PRODUCTION_LOR_UUID'::text AS defect_code,
        d.lor_prop_id AS entity_key,
        count(*)::integer AS occurrence_count,
        string_agg(
            d.display_id::text || ': ' || d.display_name,
            E'\n' ORDER BY d.display_id
        ) AS details
    FROM ref.display AS d
    CROSS JOIN selected_run AS sr
    WHERE d.lor_prop_id IS NOT NULL
      AND btrim(d.lor_prop_id) <> ''
    GROUP BY sr.import_run_id, d.lor_prop_id
    HAVING count(*) > 1

    UNION ALL

    SELECT
        p.import_run_id,
        'SPARE_COMMENT_MISSING_OR_INVALID'::text AS defect_code,
        p.prop_id AS entity_key,
        1::integer AS occurrence_count,
        'preview=' || coalesce(pr.name, '<unknown>') ||
        '; stage=' || coalesce(pr.stage_id, '<unknown>') ||
        '; prop_name=' || coalesce(p.name, '<null>') ||
        '; lor_comment=' || coalesce(p.lor_comment, '<null>') AS details
    FROM lor_snap.props AS p
    JOIN selected_run AS sr ON sr.import_run_id = p.import_run_id
    JOIN lor_snap.previews AS pr
      ON pr.import_run_id = p.import_run_id
     AND pr.id = p.preview_id
    WHERE upper(btrim(coalesce(p.name, ''))) ~ '(^|[[:space:]])SPARE[[:space:]]*$'
      AND upper(btrim(coalesce(p.lor_comment, ''))) <> 'SPARE'
)
SELECT
    import_run_id,
    defect_code,
    entity_key,
    occurrence_count,
    details
FROM defects
ORDER BY defect_code, entity_key;
