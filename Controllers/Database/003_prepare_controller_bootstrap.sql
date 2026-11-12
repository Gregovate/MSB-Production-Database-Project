/* ============================================================================
Controller Inventory bootstrap preparation — STAGE ONLY
Issue: #110

Run after:
  001_create_stage_controller_bootstrap.sql
  workbook reconciliation loaded into stage.controller_bootstrap

This script:
  - reads existing ref.display only;
  - writes only stage.controller_bootstrap*;
  - creates no ref.controller* objects or rows;
  - allocates no permanent controller IDs.
============================================================================ */

BEGIN;

-- Auto-link only an unambiguous exact Display-name match.
-- Repeated workbook controller rows may legitimately link to the same Display.
WITH exact_match AS (
    SELECT
        b.controller_bootstrap_id,
        min(d.display_id) AS display_id,
        count(*) AS match_count
    FROM stage.controller_bootstrap AS b
    JOIN ref.display AS d
      ON lower(btrim(d.display_name)) = lower(btrim(b.display_name_evidence))
    GROUP BY b.controller_bootstrap_id
)
INSERT INTO stage.controller_bootstrap_display (
    controller_bootstrap_id,
    display_id,
    relationship_type,
    relationship_note
)
SELECT
    e.controller_bootstrap_id,
    e.display_id,
    'SERVES',
    'Unique exact Display-name bootstrap match'
FROM exact_match AS e
WHERE e.match_count = 1
ON CONFLICT (controller_bootstrap_id, display_id, relationship_type)
DO NOTHING;

-- Derive first-known deployment year from reviewed SERVES relationships.
-- For one controller serving multiple Displays, use the earliest known year.
WITH derived AS (
    SELECT
        bd.controller_bootstrap_id,
        min(d.year_built) FILTER (WHERE d.year_built IS NOT NULL) AS derived_year
    FROM stage.controller_bootstrap_display AS bd
    JOIN ref.display AS d ON d.display_id = bd.display_id
    WHERE bd.relationship_type = 'SERVES'
    GROUP BY bd.controller_bootstrap_id
)
UPDATE stage.controller_bootstrap AS b
SET year_deployed = d.derived_year,
    year_deployed_source = CASE
        WHEN d.derived_year IS NULL THEN b.year_deployed_source
        ELSE 'EARLIEST_ASSIGNED_DISPLAY_YEAR_BUILT'
    END
FROM derived AS d
WHERE d.controller_bootstrap_id = b.controller_bootstrap_id
  AND b.year_deployed IS NULL;

COMMIT;

-- Read-only review helper.
CREATE OR REPLACE VIEW stage.v_controller_bootstrap_review AS
WITH display_rollup AS (
    SELECT
        bd.controller_bootstrap_id,
        count(*) FILTER (WHERE bd.relationship_type = 'SERVES') AS serves_count,
        count(*) FILTER (WHERE bd.relationship_type = 'WIRING_SOURCE') AS wiring_source_count,
        string_agg(
            d.display_id::text || ':' || d.display_name,
            ' | ' ORDER BY d.display_id
        ) FILTER (WHERE bd.relationship_type = 'SERVES') AS serves_displays,
        min(d.year_built) FILTER (
            WHERE bd.relationship_type = 'SERVES' AND d.year_built IS NOT NULL
        ) AS earliest_display_year
    FROM stage.controller_bootstrap_display AS bd
    JOIN ref.display AS d ON d.display_id = bd.display_id
    GROUP BY bd.controller_bootstrap_id
),
name_matches AS (
    SELECT
        b.controller_bootstrap_id,
        count(d.display_id) AS exact_name_match_count,
        min(d.display_id) AS exact_name_display_id
    FROM stage.controller_bootstrap AS b
    LEFT JOIN ref.display AS d
      ON lower(btrim(d.display_name)) = lower(btrim(b.display_name_evidence))
    GROUP BY b.controller_bootstrap_id
)
SELECT
    b.controller_bootstrap_id,
    b.source_row_num,
    b.display_name_evidence,
    b.network_evidence,
    b.uid_evidence,
    b.model_evidence,
    b.firmware_evidence,
    b.firmware_state_evidence,
    b.controller_type_evidence,
    b.stage_scene_evidence,
    b.park_location_evidence,
    b.for_what_evidence,
    coalesce(dr.serves_count, 0) AS serves_count,
    dr.serves_displays,
    coalesce(dr.wiring_source_count, 0) AS wiring_source_count,
    b.year_deployed,
    b.year_deployed_source,
    dr.earliest_display_year,
    nm.exact_name_match_count,
    nm.exact_name_display_id,
    b.review_state,
    b.bootstrap_order,
    b.proposed_controller_id,
    array_remove(ARRAY[
        CASE WHEN nullif(btrim(b.model_evidence), '') IS NULL THEN 'MODEL_NOT_RECORDED' END,
        CASE WHEN coalesce(dr.serves_count, 0) = 0 THEN 'DISPLAY_NOT_RESOLVED' END,
        CASE WHEN b.year_deployed IS NULL THEN 'YEAR_DEPLOYED_NOT_RESOLVED' END
    ]::text[], NULL) AS blockers,
    b.review_notes
FROM stage.controller_bootstrap AS b
LEFT JOIN display_rollup AS dr
  ON dr.controller_bootstrap_id = b.controller_bootstrap_id
LEFT JOIN name_matches AS nm
  ON nm.controller_bootstrap_id = b.controller_bootstrap_id;

-- Assigns only review/proposed order in stage. No ref.controller object required.
CREATE OR REPLACE FUNCTION stage.prepare_controller_bootstrap_order()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_open integer;
    v_ready integer;
BEGIN
    SELECT count(*) INTO v_open
    FROM stage.controller_bootstrap
    WHERE review_state = 'REVIEW_REQUIRED';

    IF v_open > 0 THEN
        RAISE EXCEPTION
            'Cannot prepare Controller ID order: % staging rows still require review',
            v_open;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM stage.v_controller_bootstrap_review
        WHERE review_state = 'READY'
          AND cardinality(blockers) > 0
    ) THEN
        RAISE EXCEPTION
            'Cannot prepare Controller ID order: one or more READY rows still have blockers';
    END IF;

    UPDATE stage.controller_bootstrap
    SET bootstrap_order = NULL
    WHERE bootstrap_order IS NOT NULL;

    WITH ordered AS (
        SELECT
            controller_bootstrap_id,
            row_number() OVER (
                ORDER BY
                    year_deployed ASC,
                    lower(coalesce(network_evidence, '')) ASC,
                    lower(coalesce(uid_evidence, '')) ASC,
                    source_row_num ASC,
                    controller_bootstrap_id ASC
            )::integer AS new_order
        FROM stage.controller_bootstrap
        WHERE review_state = 'READY'
    )
    UPDATE stage.controller_bootstrap AS b
    SET bootstrap_order = o.new_order
    FROM ordered AS o
    WHERE o.controller_bootstrap_id = b.controller_bootstrap_id;

    SELECT count(*) INTO v_ready
    FROM stage.controller_bootstrap
    WHERE review_state = 'READY';

    RETURN v_ready;
END;
$$;
