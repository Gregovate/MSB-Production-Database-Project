/* ============================================================================
Object:       SPARE-to-Display activation validation
Filename:     33_spare_to_display_activation_validation.sql
Type:         Read-only post-install validation
Migration:    0038_allow_spare_to_display_activation.sql

Purpose:
  Prove both routine lifecycle directions: SPARE-to-Display activation cannot
  inherit a false duplicate from nonphysical evidence, and Display-to-SPARE
  recycling remains excluded rather than appearing as a non-active Display.

Safety:
  Read-only. This file does not start/cancel/finish reconciliation, record an
  operator decision, or modify production/snapshot data.
============================================================================ */

/* Validation 1: installed definitions contain all three isolation rules. */
SELECT
    position('FILTER' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0
    AND position('is_spare' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0
    AND position('is_phantom' IN pg_get_viewdef(
        'lor_snap.v_display_reconciliation_source'::regclass, true
    )) > 0 AS has_physical_only_source_counts,
    position('os.display_name_normalized' IN pg_get_viewdef(
        'ops.v_lor_display_reconciliation'::regclass, true
    )) > 0 AS has_name_scoped_occurrence_evidence,
    position(
        'NONPHYSICAL:%s' IN
        pg_get_functiondef(
            'ops.f_start_lor_display_reconciliation(text)'::regprocedure
        )
    ) > 0 AS has_nonphysical_group_isolation;

/*
  Validation 2: independently recompute all physical-only counts and compare
  them with every source row. invalid_physical_count_assignment must be zero.
*/
WITH physical_uuid_counts AS (
    SELECT
        import_run_id,
        lor_prop_id,
        count(*)::integer AS expected_uuid_row_count,
        count(DISTINCT display_name_normalized)::integer
            AS expected_uuid_name_count
    FROM lor_snap.v_display_reconciliation_source
    WHERE NOT is_spare
      AND NOT is_phantom
    GROUP BY import_run_id, lor_prop_id
),
physical_name_counts AS (
    SELECT
        import_run_id,
        display_name_normalized,
        count(DISTINCT lor_prop_id)::integer AS expected_name_uuid_count
    FROM lor_snap.v_display_reconciliation_source
    WHERE NOT is_spare
      AND NOT is_phantom
    GROUP BY import_run_id, display_name_normalized
)
SELECT count(*) AS invalid_physical_count_assignment
FROM lor_snap.v_display_reconciliation_source AS src
LEFT JOIN physical_uuid_counts AS uc
  ON uc.import_run_id = src.import_run_id
 AND uc.lor_prop_id = src.lor_prop_id
LEFT JOIN physical_name_counts AS nc
  ON nc.import_run_id = src.import_run_id
 AND nc.display_name_normalized IS NOT DISTINCT FROM
     src.display_name_normalized
WHERE src.lor_uuid_row_count IS DISTINCT FROM
          coalesce(uc.expected_uuid_row_count, 0)
   OR src.lor_uuid_name_count IS DISTINCT FROM
          coalesce(uc.expected_uuid_name_count, 0)
   OR src.lor_name_uuid_count IS DISTINCT FROM
          coalesce(nc.expected_name_uuid_count, 0);

/*
  Validation 3: every current SPARE/PHANTOM source row remains nonphysical.
  invalid_nonphysical_classification_count must be zero. This specifically
  covers a recycled Display channel renamed to SPARE in LOR.
*/
SELECT count(*) AS invalid_nonphysical_classification_count
FROM ops.v_lor_display_reconciliation AS r
JOIN lor_snap.v_display_reconciliation_source AS src
  ON src.import_run_id = r.import_run_id
 AND src.source_prop_id = r.source_prop_id
WHERE (src.is_spare OR src.is_phantom)
  AND r.classification_code <> 'EXCLUDED_NONPHYSICAL';

/*
  Validation 4: show current raw UUIDs used by both physical and nonphysical
  rows. The physical row must carry physical-only counts; the SPARE/PHANTOM
  row remains visible with EXCLUDED_NONPHYSICAL classification.
*/
WITH shared_uuid AS (
    SELECT import_run_id, lor_prop_id
    FROM lor_snap.v_display_reconciliation_source
    GROUP BY import_run_id, lor_prop_id
    HAVING bool_or(is_spare OR is_phantom)
       AND bool_or(NOT is_spare AND NOT is_phantom)
)
SELECT
    src.import_run_id,
    src.lor_prop_id,
    src.display_name,
    src.is_spare,
    src.is_phantom,
    src.lor_uuid_row_count,
    src.lor_uuid_name_count,
    src.lor_name_uuid_count,
    r.classification_code,
    r.occurrence_count,
    r.location_summary
FROM shared_uuid AS shared
JOIN lor_snap.v_display_reconciliation_source AS src
  ON src.import_run_id = shared.import_run_id
 AND src.lor_prop_id = shared.lor_prop_id
JOIN ops.v_lor_display_reconciliation AS r
  ON r.import_run_id = src.import_run_id
 AND r.source_prop_id = src.source_prop_id
ORDER BY
    src.import_run_id,
    src.lor_prop_id,
    src.is_spare DESC,
    src.is_phantom DESC,
    src.display_name;

/*
  Validation 5: show the two triggering names. CL-LollipopStick-01 must no
  longer be a false duplicate. Any FC-MetroHeatLamp row flagged SPARE must be
  EXCLUDED_NONPHYSICAL. This is intentionally empty-safe when the current
  snapshot no longer contains either incident row.
*/
SELECT
    r.import_run_id,
    r.lor_display_name,
    r.lor_prop_id,
    src.prop_name,
    src.prop_comment,
    src.is_spare,
    src.is_phantom,
    r.classification_code,
    r.lor_uuid_row_count,
    r.lor_uuid_name_count,
    r.lor_name_uuid_count,
    r.allowed_resolution_paths,
    r.location_summary
FROM ops.v_lor_display_reconciliation AS r
LEFT JOIN lor_snap.v_display_reconciliation_source AS src
  ON src.import_run_id = r.import_run_id
 AND src.source_prop_id = r.source_prop_id
WHERE upper(btrim(r.lor_display_name)) IN (
    'CL-LOLLIPOPSTICK-01', 'FC-METROHEATLAMP'
)
ORDER BY r.import_run_id, r.source_prop_id;
