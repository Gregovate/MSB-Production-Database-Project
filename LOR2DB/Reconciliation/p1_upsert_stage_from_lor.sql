/*
Object: ref.p1_upsert_stage_from_lor(bigint)
Type: Procedure
Owner: msbadmin

Purpose:
  Upsert durable production stages from one explicit immutable LOR import run.
  Stage-bearing preview metadata (including background and standalone previews)
  and populated Master Musical Preview scenes provide stage discovery without
  overwriting established production naming.

Reads:
  lor_snap.import_run
  lor_snap.previews
  lor_snap.scenes
  lor_snap.scene_lor_props

Writes:
  ref.stage (INSERT/UPDATE only)

Rules:
  - Never selects the latest run implicitly.
  - Only accepts canonical stage keys: 0-99 with an optional letter suffix.
  - Uses preview and populated-scene evidence to discover stage keys.
  - A scene contributes a stage only when it contains at least one parsed prop.
  - Existing stages retain stage_name, short_code, folder_name, and folder_path.
  - Scene names contribute stage-key discovery only; they do not supply or
    require a stage short code.
  - A new stage is inserted only from one unambiguous stage-preview
    folder-style source name: <stage_key>-<stage_name>-<short_code>, where the
    short code is exactly two letters. The established
    standalone-preview form Show Stage <stage_key>-<stage_name>-<short_code>
    is normalized to that canonical form.
  - Never deletes a stage or changes an existing stage_id.

Revision History:
  2026-07-31  GAL / OpenAI  Initial explicit-run, scene-aware replacement.
  2026-07-31  GAL / OpenAI  Trim LOR names and normalize standalone Show Stage
                           names before canonical validation.
*/

CREATE OR REPLACE PROCEDURE ref.p1_upsert_stage_from_lor(
    IN p_import_run_id bigint
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_candidate_count integer;
    v_updated_count integer;
    v_inserted_count integer;
    v_unresolved_new_count integer;
BEGIN
    IF p_import_run_id IS NULL THEN
        RAISE EXCEPTION 'p_import_run_id is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM lor_snap.import_run AS ir
        WHERE ir.import_run_id = p_import_run_id
    ) THEN
        RAISE EXCEPTION 'LOR import_run_id % does not exist', p_import_run_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM lor_snap.previews AS p
        WHERE p.import_run_id = p_import_run_id
    ) THEN
        RAISE EXCEPTION 'LOR import_run_id % contains no previews', p_import_run_id;
    END IF;

    DROP TABLE IF EXISTS pg_temp.p1_stage_candidates;

    CREATE TEMP TABLE p1_stage_candidates ON COMMIT DROP AS
    WITH stage_evidence AS (
        SELECT
            lower(btrim(p.stage_id)) AS stage_key,
            btrim(p.name) AS source_name,
            'PREVIEW'::text AS evidence_type
        FROM lor_snap.previews AS p
        WHERE p.import_run_id = p_import_run_id
          AND btrim(coalesce(p.stage_id, '')) <> ''

        UNION ALL

        /*
          Fallback evidence: a populated scene supplies the effective stage for
          a Master Musical Preview whose preview row has no physical stage.
        */
        SELECT
            lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS stage_key,
            btrim(s.name) AS source_name,
            'SCENE'::text AS evidence_type
        FROM lor_snap.scenes AS s
        JOIN lor_snap.scene_lor_props AS slp
          ON slp.import_run_id = s.import_run_id
         AND slp.preview_id = s.preview_id
         AND slp.scene_id = s.scene_id
        WHERE s.import_run_id = p_import_run_id
          AND btrim(coalesce(slp.scene_stage_id, s.stage_id, '')) <> ''
        GROUP BY
            slp.scene_stage_id,
            s.stage_id,
            s.name,
            s.preview_id,
            s.scene_id
    ), valid_evidence AS (
        SELECT DISTINCT
            stage_key,
            btrim(source_name) AS source_name,
            evidence_type
        FROM stage_evidence
        WHERE stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'
    ), normalized_name_evidence AS (
        SELECT
            stage_key,
            source_name,
            evidence_type,
            CASE
                WHEN evidence_type = 'PREVIEW'
                 AND source_name ~* ('^Show Stage[[:space:]]+0*' || stage_key || '-')
                    THEN regexp_replace(
                        source_name,
                        '^Show Stage[[:space:]]+',
                        '',
                        'i'
                    )
                ELSE source_name
            END AS canonical_source_name
        FROM valid_evidence
    ), canonical_names AS (
        SELECT
            stage_key,
            canonical_source_name AS source_name,
            evidence_type,
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
    )
    SELECT
        v.stage_key,
        ((regexp_match(v.stage_key, '^0*([0-9]{1,2})'))[1])::integer AS park_order,
        CASE
            WHEN v.stage_key ~ '^[0-9]{1,2}[a-z]$'
                THEN ascii(right(v.stage_key, 1)) - ascii('a') + 1
            ELSE 0
        END AS sub_order,
        count(DISTINCT c.source_name) AS canonical_name_count,
        min(c.parsed_stage_name) AS new_stage_name,
        min(c.parsed_short_code) AS new_short_code,
        min(c.source_name) AS new_folder_name
    FROM valid_evidence AS v
    LEFT JOIN canonical_names AS c
      ON c.stage_key = v.stage_key
    GROUP BY v.stage_key;

    SELECT count(*) INTO v_candidate_count FROM p1_stage_candidates;

    IF v_candidate_count = 0 THEN
        RAISE EXCEPTION
            'LOR import_run_id % contains no canonical stage evidence',
            p_import_run_id;
    END IF;

    UPDATE ref.stage AS target
    SET
        park_order = source.park_order,
        sub_order = source.sub_order,
        updated_at = now(),
        updated_by = current_user
    FROM p1_stage_candidates AS source
    WHERE target.stage_key = source.stage_key
      AND (target.park_order, target.sub_order)
          IS DISTINCT FROM (source.park_order, source.sub_order);

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    INSERT INTO ref.stage (
        stage_key,
        stage_name,
        short_code,
        folder_name,
        folder_path,
        park_order,
        sub_order,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    SELECT
        p.stage_key,
        p.new_stage_name,
        p.new_short_code,
        p.new_folder_name,
        NULL,
        p.park_order,
        p.sub_order,
        now(),
        current_user,
        now(),
        current_user
    FROM p1_stage_candidates AS p
    WHERE p.canonical_name_count = 1
      AND NOT EXISTS (
          SELECT 1 FROM ref.stage AS existing
          WHERE existing.stage_key = p.stage_key
      );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    SELECT count(*)
    INTO v_unresolved_new_count
    FROM p1_stage_candidates AS p
    WHERE p.canonical_name_count <> 1
      AND NOT EXISTS (
          SELECT 1 FROM ref.stage AS existing
          WHERE existing.stage_key = p.stage_key
      );

    RAISE NOTICE
        'P1 stage promotion complete: import_run_id=%, candidates=%, updated=%, inserted=%, unresolved_new=%',
        p_import_run_id,
        v_candidate_count,
        v_updated_count,
        v_inserted_count,
        v_unresolved_new_count;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_upsert_stage_from_lor(bigint) IS
    'Discovers durable stage keys from one explicit LOR run, preserves established production naming, and inserts only unambiguous canonically named new stages; never deletes stages.';
