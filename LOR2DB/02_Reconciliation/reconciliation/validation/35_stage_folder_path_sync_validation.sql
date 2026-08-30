/* ============================================================================
Object:       Existing Stage folder_path synchronization validation
Filename:     35_stage_folder_path_sync_validation.sql
Type:         Read-only post-install validation
Migration:    0040_sync_existing_stage_folder_path.sql
Issue:        #101

Purpose:
  Prove that existing governed Stage/Sub-stage folder_path values synchronize
  only from one exact frozen governed LOR root, without Google Drive scanning.
============================================================================ */

/* Validation 1: installed P1 contract. All booleans must be true. */
SELECT
    to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation_before_0040(bigint)'
    ) IS NOT NULL AS preserved_prior_p1,
    position(
        'f_lor_governed_stage_roots'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS p1_uses_frozen_governed_root,
    position(
        'HAVING count(*) = 1'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS p1_requires_one_root,
    position(
        's.stage_name IS NOT DISTINCT FROM root.stage_name'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS p1_rechecks_stage_identity,
    position(
        's.folder_name IS NOT DISTINCT FROM root.folder_name'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS p1_rechecks_folder_identity,
    position(
        'P1_STAGE_FOLDER_PATH'
        IN pg_get_functiondef(
            'ref.p1_promote_stage_from_reconciliation(bigint)'::regprocedure
        )
    ) > 0 AS p1_records_path_result;

/* Validation 2: every normal governed Stage/Sub-stage with one current root
   must now have that exact folder_path. mismatch_count must be zero. */
WITH current_run AS (
    SELECT max(import_run_id) AS import_run_id
    FROM lor_snap.v_current_run
),
expected AS (
    SELECT
        s.stage_id,
        s.stage_key,
        s.folder_path AS stored_folder_path,
        root.folder_path AS governed_folder_path
    FROM current_run AS cr
    JOIN ref.stage AS s ON true
    CROSS JOIN LATERAL (
        SELECT min(r.folder_path) AS folder_path
        FROM ops.f_lor_governed_stage_roots(
            cr.import_run_id,
            s.stage_key
        ) AS r
        HAVING count(*) = 1
    ) AS root
    WHERE s.stage_key ~ '^[0-9]{2}[A-Za-z]?$'
      AND s.stage_key NOT IN (
            '12','39','40','90','91','92','93','94'
      )
)
SELECT count(*) AS mismatch_count
FROM expected
WHERE stored_folder_path IS DISTINCT FROM governed_folder_path;

/* Validation 3: production baseline acceptance cases. All exact_path true. */
SELECT
    s.stage_id,
    s.stage_key,
    s.folder_path,
    CASE s.stage_key
        WHEN '05a' THEN s.folder_path =
            E'G:\\Shared drives\\Display Folders\\05-Festive Trees-FT\\05a-Mega Star-MS'
        WHEN '07a' THEN s.folder_path =
            E'G:\\Shared drives\\Display Folders\\07-Whoville-WV\\07a-Who Forest-WF'
        WHEN '17' THEN s.folder_path =
            E'G:\\Shared drives\\Display Folders\\17-Candyland-CL'
        ELSE false
    END AS exact_path
FROM ref.stage AS s
WHERE s.stage_key IN ('05a','07a','17')
ORDER BY s.stage_key;

/* Validation 4: held/special rows remain outside path synchronization scope. */
SELECT
    stage_id,
    stage_key,
    stage_name,
    folder_name,
    folder_path
FROM ref.stage
WHERE stage_key IN ('12','39','40','90','91','92','93','94')
ORDER BY park_order, sub_order, stage_key;

/* Validation 5: current governed-root cardinality, including future/new keys. */
WITH current_run AS (
    SELECT max(import_run_id) AS import_run_id
    FROM lor_snap.v_current_run
)
SELECT
    cr.import_run_id,
    s.stage_key,
    count(r.folder_path) AS governed_root_count,
    string_agg(r.folder_path, '; ' ORDER BY r.folder_path) AS governed_paths
FROM current_run AS cr
JOIN ref.stage AS s ON true
LEFT JOIN LATERAL ops.f_lor_governed_stage_roots(
    cr.import_run_id,
    s.stage_key
) AS r ON true
WHERE s.stage_key ~ '^[0-9]{2}[A-Za-z]?$'
GROUP BY cr.import_run_id, s.stage_key, s.park_order, s.sub_order
ORDER BY s.park_order, s.sub_order, s.stage_key;

/* Validation 6: installation did not advance ingest/reconciliation lifecycle. */
SELECT
    (SELECT max(import_run_id) FROM lor_snap.import_run) AS max_import_run_id,
    (SELECT max(lor_reconciliation_run_id)
       FROM ops.lor_reconciliation_run) AS max_reconciliation_run_id;
