/* ============================================================================
Filename: 01_run36_resolution_precheck.sql
Object: ops / ref LOR resolution production precheck
Purpose: Validate live dependencies before applying run 36 decisions.
Type: Read-only diagnostic
Owner: msbadmin

Safety:
  Creates no objects, changes no data, and does not run P1 or P2.

Revision History:
  2026-07-31  GAL / OpenAI  Initial run 36 resolution precheck.
  2026-07-31  GAL / OpenAI  Post-migration revision: work orders are joined
                            exclusively through display_id; removed all use of
                            the deleted display_lor_prop_id column.
  2026-07-31  GAL / OpenAI  Validate classification evidence independently
                            of is_blocking. Approved/commented decisions may
                            already be nonblocking before they are applied.
============================================================================ */

/* Confirm the immutable run and installed reconciliation revision. */
SELECT import_run_id, run_ts, notes
FROM lor_snap.import_run
WHERE import_run_id = 36;

SELECT
    '2026-07-31-comment-required-display-source-v7'::text
        AS expected_reconciliation_revision,
    position(
        'combined_rows' IN
        pg_get_viewdef(
            'lor_snap.v_display_reconciliation_source'::regclass,
            true
        )
    ) > 0 AS has_combined_source,
    position(
        'Master Musical Preview' IN
        pg_get_viewdef(
            'lor_snap.v_display_reconciliation_source'::regclass,
            true
        )
    ) > 0 AS has_master_musical_source;

SELECT * FROM ops.f_lor_reconciliation_summary(36);


/* Resolve status by name in the later action procedure, never by numeric ID. */
SELECT display_status_id, display_status_name, description
FROM ref.display_status
ORDER BY display_status_id;


/* Inventory all foreign keys that reference ref.display. */
SELECT
    con.conname AS constraint_name,
    con.conrelid::regclass AS referencing_table,
    pg_get_constraintdef(con.oid, true) AS constraint_definition,
    CASE con.confupdtype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE con.confupdtype::text
    END AS update_action
FROM pg_constraint AS con
WHERE con.contype = 'f'
  AND con.confrelid = 'ref.display'::regclass
ORDER BY con.conrelid::regclass::text, con.conname;


/*
Count historical work orders attached to the nine displays whose LOR UUID will
change. Work orders must be related to displays only through display_id.
*/
WITH uuid_change_display(display_id, decision_type) AS (
    VALUES
        (1017::bigint, 'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (885::bigint,  'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (118::bigint,  'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (1008::bigint, 'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (46::bigint,   'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (61::bigint,   'KEEP_DISPLAY_UPDATE_LOR_LINK'::text),
        (1018::bigint, 'REASSOCIATE_DISPLAY'::text),
        (11::bigint,   'REASSOCIATE_DISPLAY'::text),
        (123::bigint,  'REASSOCIATE_DISPLAY'::text)
)
SELECT
    d.display_id,
    d.display_name,
    ucd.decision_type,
    d.lor_prop_id AS current_lor_prop_id,
    count(DISTINCT wo.work_order_id) AS work_orders_by_display_id
FROM uuid_change_display AS ucd
JOIN ref.display AS d ON d.display_id = ucd.display_id
LEFT JOIN ops.work_order AS wo ON wo.display_id = d.display_id
GROUP BY d.display_id, d.display_name, ucd.decision_type, d.lor_prop_id
ORDER BY d.display_id;


/*
Validate the 24 confirmed business decisions against live run 36 evidence.
Each row must return evidence_matches_decision = true.
*/
WITH decision_manifest (
    decision_type, display_id, production_name, lor_name
) AS (
    VALUES
        ('RENAME_DISPLAY', 767::bigint, 'FC-ArrowRight-2CH-01', 'FE-ArrowRight-2CH-01'),
        ('RENAME_DISPLAY', 566::bigint, 'PB-IglooCR50-01', 'PB-Igloo-CR50-01'),
        ('RENAME_DISPLAY', 569::bigint, 'PB-IglooCR50-02', 'PB-Igloo-CR50-02'),
        ('RENAME_DISPLAY', 568::bigint, 'PB-IglooCR50-03', 'PB-Igloo-CR50-03'),
        ('RENAME_DISPLAY', 565::bigint, 'PB-IglooCR50-04', 'PB-Igloo-CR50-04'),
        ('RENAME_DISPLAY', 773::bigint, 'TuneRadio-2CH-03', 'FE-TuneRadio-2CH-03'),

        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 1017::bigint, 'FE-TuneRadio-2CH-01', 'FE-TuneRadio-2CH-01'),
        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 885::bigint, 'SW-GiftBag', 'SW-GiftBag'),
        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 118::bigint, 'SW-StarRGB-RH', 'SW-StarRGB-RH'),
        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 1008::bigint, 'WW-Condor', 'WW-Condor'),
        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 46::bigint, 'WW-CousinEddie', 'WW-CousinEddie'),
        ('KEEP_DISPLAY_UPDATE_LOR_LINK', 61::bigint, 'WW-FlickPole', 'WW-FlickPole'),

        ('REASSOCIATE_DISPLAY', 1018::bigint, 'FE-TuneRadio-1CH-01', 'FE-TuneRadio-2CH-02'),
        ('REASSOCIATE_DISPLAY', 11::bigint, 'WaitTime15Min', 'HW-WaitTime15Min'),
        ('REASSOCIATE_DISPLAY', 123::bigint, 'MC-Scaffold', 'WA-MegaCube-Scaffold'),

        ('ADD_NEW_DISPLAY', NULL::bigint, NULL::text, 'QV-StationSign-02'),
        ('ADD_NEW_DISPLAY', NULL::bigint, NULL::text, 'WW-ClarkGriswold'),
        ('ADD_NEW_DISPLAY', NULL::bigint, NULL::text, 'WW-FreeFrosty-Spotlight'),
        ('ADD_NEW_DISPLAY', NULL::bigint, NULL::text, 'WW-UncleLouis-Flying'),
        ('ADD_NEW_DISPLAY', NULL::bigint, NULL::text, 'WW-UncleLouis-Standing'),

        ('SET_RECYCLED', 597::bigint, 'PB-PVCIgloo-01', NULL::text),
        ('SET_RECYCLED', 598::bigint, 'PB-PVCIgloo-02', NULL::text),
        ('SET_RECYCLED', 599::bigint, 'PB-PVCIgloo-03', NULL::text),
        ('SET_RECYCLED', 600::bigint, 'PB-PVCIgloo-04', NULL::text)
),
evidence AS (
    SELECT *
    FROM ops.v_lor_display_reconciliation
    WHERE import_run_id = 36
)
SELECT
    dm.decision_type,
    dm.display_id,
    dm.production_name,
    dm.lor_name,
    pe.classification_code AS production_evidence,
    le.classification_code AS lor_evidence,
    le.lor_prop_id AS proposed_lor_prop_id,
    le.preview_stage_id AS proposed_stage_key,
    CASE dm.decision_type
        WHEN 'REASSOCIATE_DISPLAY' THEN
            pe.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
            AND le.classification_code = 'NEW_DISPLAY_CANDIDATE'
        WHEN 'SET_RECYCLED' THEN
            pe.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
        WHEN 'ADD_NEW_DISPLAY' THEN
            le.classification_code = 'NEW_DISPLAY_CANDIDATE'
        WHEN 'RENAME_DISPLAY' THEN
            le.classification_code = 'NAME_CHANGED_SAME_UUID'
        WHEN 'KEEP_DISPLAY_UPDATE_LOR_LINK' THEN
            le.classification_code = 'UUID_CHANGED_SAME_NAME'
        ELSE false
    END AS evidence_matches_decision
FROM decision_manifest AS dm
LEFT JOIN evidence AS pe
  ON pe.display_id = dm.display_id
 AND pe.production_display_name = dm.production_name
 AND pe.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
LEFT JOIN evidence AS le
  ON le.lor_display_name = dm.lor_name
 AND (
        dm.display_id IS NULL
        OR le.display_id = dm.display_id
        OR le.classification_code = 'NEW_DISPLAY_CANDIDATE'
     )
ORDER BY
    CASE dm.decision_type
        WHEN 'RENAME_DISPLAY' THEN 1
        WHEN 'KEEP_DISPLAY_UPDATE_LOR_LINK' THEN 2
        WHEN 'REASSOCIATE_DISPLAY' THEN 3
        WHEN 'ADD_NEW_DISPLAY' THEN 4
        WHEN 'SET_RECYCLED' THEN 5
        ELSE 9
    END,
    coalesce(dm.lor_name, dm.production_name);
