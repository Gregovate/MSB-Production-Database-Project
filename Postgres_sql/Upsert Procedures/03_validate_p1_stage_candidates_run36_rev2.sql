/*
Object: Run 36 P1 stage-candidate validation, revision 2
Type: Read-only validation query
Owner: msbadmin

Purpose:
  Show every discovered stage key and the action the corrected scene-aware P1
  would take for import run 36. Existing production names are never replaced.

Naming rules validated:
  - Stage previews may provide <stage_key>-<stage_name>-<two-letter short_code>.
  - Standalone names in the exact form
    Show Stage <stage_key>-<stage_name>-<two-letter short_code> are normalized.
  - The final two-letter segment is the preserved wiring/channel short code.
  - Scene names contribute the stage-key prefix only. A short code is neither
    required nor extracted from a scene name.
  - A scene-only new stage remains unresolved until an authoritative stage
    preview supplies its official name and two-letter short code.

Safety:
  Read-only. This script does not create, update, or delete any database data.

Revision History:
  2026-07-31  GAL / OpenAI  Initial validation query.
  2026-07-31  GAL / OpenAI  Final naming-rule revision: preserve preview short
                           codes and prohibit stage metadata derivation from
                           scene names.
  2026-07-31  GAL / OpenAI  Trim LOR names and normalize standalone Show Stage
                           names before canonical validation.
  2026-07-31  GAL / OpenAI  Issued under a unique revision filename to prevent
                           confusion with previously downloaded query copies.
*/

WITH parameters AS (
    SELECT 36::bigint AS import_run_id
),
stage_evidence AS (
    SELECT
        lower(btrim(p.stage_id)) AS stage_key,
        btrim(p.stage_id) AS stage_id_raw,
        btrim(p.name) AS source_name,
        'PREVIEW'::text AS evidence_type,
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
        btrim(s.name) AS source_name,
        'POPULATED_SCENE'::text AS evidence_type,
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
valid_evidence AS (
    SELECT
        e.*
    FROM stage_evidence AS e
    WHERE e.stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'
),
normalized_name_evidence AS (
    SELECT
        e.*,
        CASE
            WHEN e.evidence_type = 'PREVIEW'
             AND e.source_name ~* ('^Show Stage[[:space:]]+0*' || e.stage_key || '-')
                THEN regexp_replace(
                    e.source_name,
                    '^Show Stage[[:space:]]+',
                    '',
                    'i'
                )
            ELSE e.source_name
        END AS canonical_source_name
    FROM valid_evidence AS e
),
canonical_names AS (
    SELECT DISTINCT
        stage_key,
        canonical_source_name AS source_name,
        (regexp_match(
            canonical_source_name,
            '(?i)^0*' || stage_key || '-(.+)-([^-]+)$'
        ))[1] AS parsed_stage_name,
        (regexp_match(
            canonical_source_name,
            '(?i)^0*' || stage_key || '-(.+)-([^-]+)$'
        ))[2] AS parsed_short_code
    FROM normalized_name_evidence
    WHERE evidence_type = 'PREVIEW'
      AND canonical_source_name ~* ('^0*' || stage_key || '-.+-[a-z]{2}$')
),
stage_summary AS (
    SELECT
        v.stage_key,
        string_agg(
            DISTINCT v.evidence_type || ': ' || v.source_name,
            ' | '
            ORDER BY v.evidence_type || ': ' || v.source_name
        ) AS all_evidence,
        count(DISTINCT c.source_name) AS canonical_name_count,
        min(c.parsed_stage_name) AS proposed_new_stage_name,
        min(c.parsed_short_code) AS proposed_new_short_code,
        min(c.source_name) AS proposed_new_folder_name
    FROM valid_evidence AS v
    LEFT JOIN canonical_names AS c
      ON c.stage_key = v.stage_key
    GROUP BY v.stage_key
)
SELECT
    s.stage_key,
    existing.stage_id AS production_stage_id,
    existing.stage_name AS preserved_stage_name,
    existing.short_code AS preserved_short_code,
    existing.folder_name AS preserved_folder_name,
    s.canonical_name_count,
    s.proposed_new_stage_name,
    s.proposed_new_short_code,
    s.proposed_new_folder_name,
    CASE
        WHEN existing.stage_id IS NOT NULL THEN 'UPDATE_ORDER_ONLY'
        WHEN s.canonical_name_count = 1 THEN 'INSERT_NEW_STAGE'
        ELSE 'UNRESOLVED_NEW_STAGE'
    END AS p1_action,
    s.all_evidence
FROM stage_summary AS s
LEFT JOIN ref.stage AS existing
  ON existing.stage_key = s.stage_key
ORDER BY
    CASE
        WHEN s.stage_key ~ '^[0-9]+' THEN
            ((regexp_match(s.stage_key, '^0*([0-9]{1,2})'))[1])::integer
        ELSE 1000
    END,
    s.stage_key;
