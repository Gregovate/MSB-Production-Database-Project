/* ============================================================================
Filename: 03_apply_run36_approved_resolutions.sql
Object: ops.lor_reconciliation_action / run 36 approved resolutions
Purpose: Apply and audit the 24 operator-approved display decisions for LOR
         import run 36.
Type: Controlled one-time production migration
Owner: msbadmin

Safety:
  - Run this file as one complete script.
  - The script uses one transaction and rolls back on any error.
  - It validates run 36, the V7 reconciliation source, all current production
    identities, all LOR evidence, status names, stage mappings, and uniqueness
    before changing ref.display.
  - Existing display_id values are never changed.
  - P1 and P2 are not called.
  - A second execution is rejected because the original evidence no longer
    matches after a successful application.

Expected actions:
  6 RENAME_DISPLAY
  6 KEEP_DISPLAY_UPDATE_LOR_LINK
  3 REASSOCIATE_DISPLAY
  5 ADD_NEW_DISPLAY
  4 SET_RECYCLED

Revision History:
  2026-07-31  GAL / OpenAI  Initial run 36 audited resolution application.
============================================================================ */

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';

/* Serialize this exact resolution application. */
SELECT pg_advisory_xact_lock(hashtextextended('MSB-LOR-RUN-36-RESOLUTION', 0));

/* Permanent append-only audit table for operator-approved LOR resolutions. */
CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_action (
    lor_reconciliation_action_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    import_run_id bigint NOT NULL,
    action_type text NOT NULL,
    display_id bigint NOT NULL,
    lor_prop_id_before text,
    lor_prop_id_after text,
    display_name_before text,
    display_name_after text,
    display_status_id_before integer,
    display_status_id_after integer,
    preview_id text,
    preview_stage_id text,
    reason text NOT NULL,
    acted_at timestamptz NOT NULL DEFAULT now(),
    acted_by text NOT NULL DEFAULT current_user,
    CONSTRAINT fk_lor_reconciliation_action_run
        FOREIGN KEY (import_run_id)
        REFERENCES lor_snap.import_run(import_run_id),
    CONSTRAINT fk_lor_reconciliation_action_display
        FOREIGN KEY (display_id)
        REFERENCES ref.display(display_id),
    CONSTRAINT fk_lor_reconciliation_action_status_before
        FOREIGN KEY (display_status_id_before)
        REFERENCES ref.display_status(display_status_id),
    CONSTRAINT fk_lor_reconciliation_action_status_after
        FOREIGN KEY (display_status_id_after)
        REFERENCES ref.display_status(display_status_id),
    CONSTRAINT ck_lor_reconciliation_action_type
        CHECK (action_type IN (
            'RENAME_DISPLAY',
            'KEEP_DISPLAY_UPDATE_LOR_LINK',
            'REASSOCIATE_DISPLAY',
            'ADD_NEW_DISPLAY',
            'SET_RECYCLED'
        )),
    CONSTRAINT ck_lor_reconciliation_action_reason
        CHECK (btrim(reason) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_lor_reconciliation_action_run_decision
    ON ops.lor_reconciliation_action (
        import_run_id,
        action_type,
        display_id
    );

COMMENT ON TABLE ops.lor_reconciliation_action IS
'Append-only audit history of operator-approved LOR-to-production display identity resolutions.';

/*
The temporary manifest stores both the approved decision and the exact current
production state that must still be present. New LOR values are populated only
from the canonical run-36 reconciliation source.
*/
CREATE TEMPORARY TABLE tmp_run36_decision (
    decision_order integer PRIMARY KEY,
    action_type text NOT NULL,
    display_id bigint,
    display_name_before text,
    display_name_after text,
    lor_prop_id_before text,
    lor_prop_id_after text,
    stage_key_after text,
    stage_id_after integer,
    preview_id text,
    string_type_after text,
    color_after text,
    display_status_id_before integer,
    display_status_id_after integer,
    reason text NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_run36_decision (
    decision_order,
    action_type,
    display_id,
    display_name_before,
    display_name_after,
    reason
)
VALUES
    ( 1, 'RENAME_DISPLAY', 767, 'FC-ArrowRight-2CH-01', 'FE-ArrowRight-2CH-01',
      'Run 36 approved identity-preserving display rename.'),
    ( 2, 'RENAME_DISPLAY', 773, 'TuneRadio-2CH-03', 'FE-TuneRadio-2CH-03',
      'Run 36 approved identity-preserving display rename.'),
    ( 3, 'RENAME_DISPLAY', 566, 'PB-IglooCR50-01', 'PB-Igloo-CR50-01',
      'Run 36 approved identity-preserving display rename.'),
    ( 4, 'RENAME_DISPLAY', 569, 'PB-IglooCR50-02', 'PB-Igloo-CR50-02',
      'Run 36 approved identity-preserving display rename.'),
    ( 5, 'RENAME_DISPLAY', 568, 'PB-IglooCR50-03', 'PB-Igloo-CR50-03',
      'Run 36 approved identity-preserving display rename.'),
    ( 6, 'RENAME_DISPLAY', 565, 'PB-IglooCR50-04', 'PB-Igloo-CR50-04',
      'Run 36 approved identity-preserving display rename.'),

    ( 7, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 1017, 'FE-TuneRadio-2CH-01', 'FE-TuneRadio-2CH-01',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),
    ( 8, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 885, 'SW-GiftBag', 'SW-GiftBag',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),
    ( 9, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 118, 'SW-StarRGB-RH', 'SW-StarRGB-RH',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),
    (10, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 1008, 'WW-Condor', 'WW-Condor',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),
    (11, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 46, 'WW-CousinEddie', 'WW-CousinEddie',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),
    (12, 'KEEP_DISPLAY_UPDATE_LOR_LINK', 61, 'WW-FlickPole', 'WW-FlickPole',
      'Run 36 approved keeping the existing display and updating its current LOR link.'),

    (13, 'REASSOCIATE_DISPLAY', 1018, 'FE-TuneRadio-1CH-01', 'FE-TuneRadio-2CH-02',
      'Run 36 approved existing-display reassociation after both LOR name and UUID changed.'),
    (14, 'REASSOCIATE_DISPLAY', 11, 'WaitTime15Min', 'HW-WaitTime15Min',
      'Run 36 approved existing-display reassociation after both LOR name and UUID changed.'),
    (15, 'REASSOCIATE_DISPLAY', 123, 'MC-Scaffold', 'WA-MegaCube-Scaffold',
      'Run 36 approved existing-display reassociation after both LOR name and UUID changed.'),

    (16, 'ADD_NEW_DISPLAY', NULL, NULL, 'QV-StationSign-02',
      'Run 36 approved creation of a new physical display identity.'),
    (17, 'ADD_NEW_DISPLAY', NULL, NULL, 'WW-ClarkGriswold',
      'Run 36 approved creation of a new physical display identity.'),
    (18, 'ADD_NEW_DISPLAY', NULL, NULL, 'WW-FreeFrosty-Spotlight',
      'Run 36 approved creation of a new physical display identity.'),
    (19, 'ADD_NEW_DISPLAY', NULL, NULL, 'WW-UncleLouis-Flying',
      'Run 36 approved creation of a new physical display identity.'),
    (20, 'ADD_NEW_DISPLAY', NULL, NULL, 'WW-UncleLouis-Standing',
      'Run 36 approved creation of a new physical display identity.'),

    (21, 'SET_RECYCLED', 597, 'PB-PVCIgloo-01', 'PB-PVCIgloo-01',
      'Run 36 approved changing this intentionally dismantled display from ACTIVE to RECYCLED.'),
    (22, 'SET_RECYCLED', 598, 'PB-PVCIgloo-02', 'PB-PVCIgloo-02',
      'Run 36 approved changing this intentionally dismantled display from ACTIVE to RECYCLED.'),
    (23, 'SET_RECYCLED', 599, 'PB-PVCIgloo-03', 'PB-PVCIgloo-03',
      'Run 36 approved changing this intentionally dismantled display from ACTIVE to RECYCLED.'),
    (24, 'SET_RECYCLED', 600, 'PB-PVCIgloo-04', 'PB-PVCIgloo-04',
      'Run 36 approved changing this intentionally dismantled display from ACTIVE to RECYCLED.');

DO $validation$
DECLARE
    v_latest_run_id bigint;
    v_active_status_id integer;
    v_recycled_status_id integer;
    v_count integer;
BEGIN
    SELECT max(import_run_id)
      INTO v_latest_run_id
    FROM lor_snap.import_run;

    IF v_latest_run_id IS DISTINCT FROM 36 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: latest import_run_id is %, expected 36.',
            v_latest_run_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM lor_snap.import_run
        WHERE import_run_id = 36
    ) THEN
        RAISE EXCEPTION 'Run 36 application stopped: import run 36 does not exist.';
    END IF;

    IF position(
        'combined_rows' IN
        pg_get_viewdef('lor_snap.v_display_reconciliation_source'::regclass, true)
    ) = 0 OR position(
        'Master Musical Preview' IN
        pg_get_viewdef('lor_snap.v_display_reconciliation_source'::regclass, true)
    ) = 0 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: required V7 reconciliation source is not installed.';
    END IF;

    SELECT display_status_id
      INTO STRICT v_active_status_id
    FROM ref.display_status
    WHERE upper(btrim(display_status_name)) = 'ACTIVE';

    SELECT display_status_id
      INTO STRICT v_recycled_status_id
    FROM ref.display_status
    WHERE upper(btrim(display_status_name)) = 'RECYCLED';

    IF v_recycled_status_id <> 3 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: RECYCLED resolved to status %, expected verified status 3.',
            v_recycled_status_id;
    END IF;

    UPDATE tmp_run36_decision
       SET display_status_id_after = CASE
               WHEN action_type = 'SET_RECYCLED' THEN v_recycled_status_id
               WHEN action_type = 'ADD_NEW_DISPLAY' THEN v_active_status_id
               ELSE NULL
           END;

    SELECT count(*)
      INTO v_count
    FROM tmp_run36_decision;

    IF v_count <> 24 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: manifest has % decisions, expected 24.',
            v_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_action
        WHERE import_run_id = 36
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: audit actions for import run 36 already exist.';
    END IF;

    /* Lock and capture the exact current state of all 19 existing displays. */
    PERFORM 1
    FROM ref.display AS d
    JOIN tmp_run36_decision AS t
      ON t.display_id = d.display_id
    WHERE t.action_type <> 'ADD_NEW_DISPLAY'
    FOR UPDATE OF d;

    SELECT count(*)
      INTO v_count
    FROM tmp_run36_decision AS t
    JOIN ref.display AS d
      ON d.display_id = t.display_id
     AND d.display_name = t.display_name_before
    WHERE t.action_type <> 'ADD_NEW_DISPLAY';

    IF v_count <> 19 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: % of 19 existing displays still match their approved display_id/name evidence.',
            v_count;
    END IF;

    UPDATE tmp_run36_decision AS t
       SET lor_prop_id_before = d.lor_prop_id,
           display_status_id_before = d.display_status_id,
           display_status_id_after = coalesce(t.display_status_id_after, d.display_status_id)
    FROM ref.display AS d
    WHERE d.display_id = t.display_id;

    IF EXISTS (
        SELECT 1
        FROM tmp_run36_decision AS t
        WHERE t.action_type = 'SET_RECYCLED'
          AND t.display_status_id_before <> v_active_status_id
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: one or more approved recycled displays are no longer ACTIVE.';
    END IF;
END
$validation$;

/* Populate all approved LOR-side values from the immutable canonical source. */
UPDATE tmp_run36_decision AS t
   SET lor_prop_id_after = src.lor_prop_id,
       stage_key_after = lower(btrim(src.preview_stage_id)),
       preview_id = src.preview_id,
       string_type_after = src.string_type,
       color_after = src.color
FROM lor_snap.v_display_reconciliation_source AS src
WHERE src.import_run_id = 36
  AND src.display_name_normalized = upper(btrim(t.display_name_after))
  AND t.action_type <> 'SET_RECYCLED';

UPDATE tmp_run36_decision AS t
   SET lor_prop_id_after = t.lor_prop_id_before,
       stage_id_after = d.stage_id,
       display_status_id_after = t.display_status_id_after
FROM ref.display AS d
WHERE t.action_type = 'SET_RECYCLED'
  AND d.display_id = t.display_id;

UPDATE tmp_run36_decision AS t
   SET stage_id_after = s.stage_id
FROM ref.stage AS s
WHERE t.action_type <> 'SET_RECYCLED'
  AND s.stage_key = t.stage_key_after;

DO $evidence$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*)
      INTO v_count
    FROM tmp_run36_decision
    WHERE action_type <> 'SET_RECYCLED'
      AND lor_prop_id_after IS NOT NULL
      AND stage_key_after IS NOT NULL
      AND stage_id_after IS NOT NULL;

    IF v_count <> 20 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: % of 20 LOR-backed decisions resolved uniquely to run-36 source and stage evidence.',
            v_count;
    END IF;

    /* Every candidate decision must have exactly one canonical source row. */
    IF EXISTS (
        SELECT t.decision_order
        FROM tmp_run36_decision AS t
        LEFT JOIN lor_snap.v_display_reconciliation_source AS src
          ON src.import_run_id = 36
         AND src.display_name_normalized = upper(btrim(t.display_name_after))
        WHERE t.action_type <> 'SET_RECYCLED'
        GROUP BY t.decision_order
        HAVING count(src.lor_prop_id) <> 1
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: one or more approved LOR names do not have exactly one canonical source row.';
    END IF;

    /* Confirm the original blocker type for every approved business action. */
    IF EXISTS (
        SELECT 1
        FROM tmp_run36_decision AS t
        WHERE CASE t.action_type
            WHEN 'RENAME_DISPLAY' THEN NOT EXISTS (
                SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                WHERE r.import_run_id = 36
                  AND r.display_id = t.display_id
                  AND r.lor_display_name = t.display_name_after
                  AND r.classification_code = 'NAME_CHANGED_SAME_UUID'
            )
            WHEN 'KEEP_DISPLAY_UPDATE_LOR_LINK' THEN NOT EXISTS (
                SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                WHERE r.import_run_id = 36
                  AND r.display_id = t.display_id
                  AND r.lor_display_name = t.display_name_after
                  AND r.classification_code = 'UUID_CHANGED_SAME_NAME'
            )
            WHEN 'REASSOCIATE_DISPLAY' THEN NOT (
                EXISTS (
                    SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                    WHERE r.import_run_id = 36
                      AND r.display_id = t.display_id
                      AND r.production_display_name = t.display_name_before
                      AND r.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
                )
                AND EXISTS (
                    SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                    WHERE r.import_run_id = 36
                      AND r.lor_display_name = t.display_name_after
                      AND r.classification_code = 'NEW_DISPLAY_CANDIDATE'
                )
            )
            WHEN 'ADD_NEW_DISPLAY' THEN NOT EXISTS (
                SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                WHERE r.import_run_id = 36
                  AND r.lor_display_name = t.display_name_after
                  AND r.classification_code = 'NEW_DISPLAY_CANDIDATE'
            )
            WHEN 'SET_RECYCLED' THEN NOT EXISTS (
                SELECT 1 FROM ops.v_lor_display_reconciliation AS r
                WHERE r.import_run_id = 36
                  AND r.display_id = t.display_id
                  AND r.production_display_name = t.display_name_before
                  AND r.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
            )
            ELSE true
        END
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: one or more decisions no longer match the approved reconciliation evidence.';
    END IF;

    /* Protect all production name and UUID uniqueness before mutation. */
    IF EXISTS (
        SELECT 1
        FROM tmp_run36_decision AS t
        JOIN ref.display AS d
          ON upper(btrim(d.display_name)) = upper(btrim(t.display_name_after))
        WHERE d.display_id IS DISTINCT FROM t.display_id
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: an approved display name is already owned by another display_id.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tmp_run36_decision AS t
        JOIN ref.display AS d
          ON d.lor_prop_id = t.lor_prop_id_after
        WHERE d.display_id IS DISTINCT FROM t.display_id
    ) THEN
        RAISE EXCEPTION
            'Run 36 application stopped: an approved LOR UUID is already owned by another display_id.';
    END IF;
END
$evidence$;

/* Apply the 15 approved changes to existing LOR-backed identities. */
UPDATE ref.display AS d
   SET display_name = t.display_name_after,
       lor_prop_id = t.lor_prop_id_after,
       inventory_type = 'LOR',
       stage_id = t.stage_id_after,
       string_type = t.string_type_after,
       color = t.color_after,
       updated_at = now(),
       updated_by = current_user
FROM tmp_run36_decision AS t
WHERE t.action_type IN (
        'RENAME_DISPLAY',
        'KEEP_DISPLAY_UPDATE_LOR_LINK',
        'REASSOCIATE_DISPLAY'
      )
  AND d.display_id = t.display_id;

/* Insert only the five approved new physical display identities. */
WITH inserted AS (
    INSERT INTO ref.display (
        lor_prop_id,
        display_name,
        inventory_type,
        display_status_id,
        stage_id,
        string_type,
        color,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    SELECT
        t.lor_prop_id_after,
        t.display_name_after,
        'LOR',
        t.display_status_id_after,
        t.stage_id_after,
        t.string_type_after,
        t.color_after,
        now(),
        current_user,
        now(),
        current_user
    FROM tmp_run36_decision AS t
    WHERE t.action_type = 'ADD_NEW_DISPLAY'
    ORDER BY t.decision_order
    RETURNING display_id, display_name, lor_prop_id, display_status_id
)
UPDATE tmp_run36_decision AS t
   SET display_id = i.display_id,
       display_status_id_before = NULL,
       display_status_id_after = i.display_status_id
FROM inserted AS i
WHERE t.action_type = 'ADD_NEW_DISPLAY'
  AND t.display_name_after = i.display_name
  AND t.lor_prop_id_after = i.lor_prop_id;

/* Status is PostgreSQL-owned: change only status for the four recycled rows. */
UPDATE ref.display AS d
   SET display_status_id = t.display_status_id_after,
       updated_at = now(),
       updated_by = current_user
FROM tmp_run36_decision AS t
WHERE t.action_type = 'SET_RECYCLED'
  AND d.display_id = t.display_id;

DO $post_mutation$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*)
      INTO v_count
    FROM tmp_run36_decision AS t
    JOIN ref.display AS d
      ON d.display_id = t.display_id
     AND d.display_name = t.display_name_after
     AND d.lor_prop_id = t.lor_prop_id_after
     AND d.display_status_id = t.display_status_id_after;

    IF v_count <> 24 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: only % of 24 applied rows passed post-mutation identity/status verification.',
            v_count;
    END IF;

    SELECT count(*)
      INTO v_count
    FROM ops.v_lor_display_reconciliation
    WHERE import_run_id = 36
      AND is_blocking;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: reconciliation still contains % blocking rows after applying decisions.',
            v_count;
    END IF;
END
$post_mutation$;

/* Write one immutable audit row for each approved business decision. */
INSERT INTO ops.lor_reconciliation_action (
    import_run_id,
    action_type,
    display_id,
    lor_prop_id_before,
    lor_prop_id_after,
    display_name_before,
    display_name_after,
    display_status_id_before,
    display_status_id_after,
    preview_id,
    preview_stage_id,
    reason
)
SELECT
    36,
    t.action_type,
    t.display_id,
    t.lor_prop_id_before,
    t.lor_prop_id_after,
    t.display_name_before,
    t.display_name_after,
    t.display_status_id_before,
    t.display_status_id_after,
    t.preview_id,
    t.stage_key_after,
    t.reason
FROM tmp_run36_decision AS t
ORDER BY t.decision_order;

DO $audit_check$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*)
      INTO v_count
    FROM ops.lor_reconciliation_action
    WHERE import_run_id = 36;

    IF v_count <> 24 THEN
        RAISE EXCEPTION
            'Run 36 application stopped: audit contains % rows, expected 24.',
            v_count;
    END IF;
END
$audit_check$;

COMMIT;

/* --------------------------------------------------------------------------
Post-commit verification grids. Save both grids with the production run record.
---------------------------------------------------------------------------- */
SELECT
    action_type,
    count(*) AS action_count
FROM ops.lor_reconciliation_action
WHERE import_run_id = 36
GROUP BY action_type
ORDER BY action_type;

SELECT
    a.lor_reconciliation_action_id,
    a.action_type,
    a.display_id,
    a.display_name_before,
    a.display_name_after,
    a.lor_prop_id_before,
    a.lor_prop_id_after,
    ds_before.display_status_name AS status_before,
    ds_after.display_status_name AS status_after,
    a.preview_stage_id AS stage_key_after,
    a.acted_at,
    a.acted_by
FROM ops.lor_reconciliation_action AS a
LEFT JOIN ref.display_status AS ds_before
  ON ds_before.display_status_id = a.display_status_id_before
LEFT JOIN ref.display_status AS ds_after
  ON ds_after.display_status_id = a.display_status_id_after
WHERE a.import_run_id = 36
ORDER BY a.lor_reconciliation_action_id;

SELECT *
FROM ops.f_lor_reconciliation_summary(36);
