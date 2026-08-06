/*
Schema: ref / lor_snap / ops
Object: Unapproved ref.display insert forensics
Filename: 08a_unapproved_ref_display_insert_forensics.sql
Type: Read-only production baseline forensic audit
Owner: msbadmin

Purpose:
  Identify current physical LOR displays that already exist in ref.display but
  may have been inserted by the legacy P2 before operator approval.

  This is required when the P2 identity gate reports an exact match for a row
  the operator knows was never approved. The gate compares current LOR state to
  current production state; it cannot classify an already-inserted row as new.

  The report shows:
  - permanent display_id and production metadata;
  - ref.display creation/update audit fields;
  - the first snapshot/run in which the display name appeared;
  - the current LOR identity and stage evidence;
  - reconciliation approval count;
  - known production relationship counts.

Safety:
  SELECT only. Does not delete, update, create, or approve any display.

Interpretation:
  A recently created ref.display row with no reconciliation approval and no
  production relationships is a likely unapproved legacy-P2 insert. It must be
  reviewed before any corrective delete is considered.

Revision History:
  2026-08-01  GAL / OpenAI  Initial forensic audit after unapproved new displays
                           were found already present in ref.display.
*/

WITH current_run AS (
    SELECT import_run_id, run_ts
    FROM lor_snap.v_current_run
),
current_source AS (
    SELECT DISTINCT ON (s.display_name_normalized)
        s.import_run_id,
        s.lor_prop_id,
        s.display_name,
        s.display_name_normalized,
        s.preview_stage_id,
        s.preview_name,
        s.preview_id,
        s.string_type,
        s.color
    FROM lor_snap.v_display_reconciliation_source AS s
    JOIN current_run AS cr
      ON cr.import_run_id = s.import_run_id
    WHERE s.display_name_normalized IS NOT NULL
    ORDER BY
        s.display_name_normalized,
        s.lor_prop_id
),
first_seen AS (
    SELECT
        s.display_name_normalized,
        min(s.import_run_id) AS first_import_run_id
    FROM lor_snap.v_display_reconciliation_source AS s
    WHERE s.display_name_normalized IS NOT NULL
    GROUP BY s.display_name_normalized
),
first_seen_detail AS (
    SELECT
        fs.display_name_normalized,
        fs.first_import_run_id,
        ir.run_ts AS first_seen_at,
        ir.notes AS first_seen_notes
    FROM first_seen AS fs
    JOIN lor_snap.import_run AS ir
      ON ir.import_run_id = fs.first_import_run_id
),
approvals AS (
    SELECT
        a.display_id,
        count(*) FILTER (
            WHERE a.action_type IN (
                'ADD_NEW_DISPLAY',
                'APPROVE_NEW_LOR_DISPLAY',
                'REASSOCIATE_DISPLAY'
            )
        ) AS approval_count,
        min(a.acted_at) AS first_approval_at,
        max(a.acted_at) AS last_approval_at
    FROM ops.lor_reconciliation_action AS a
    GROUP BY a.display_id
),
work_order_refs AS (
    SELECT display_id, count(*) AS reference_count
    FROM ops.work_order
    WHERE display_id IS NOT NULL
    GROUP BY display_id
),
test_refs AS (
    SELECT display_id, count(*) AS reference_count
    FROM ops.display_test_session
    WHERE display_id IS NOT NULL
    GROUP BY display_id
),
label_refs AS (
    SELECT display_id, count(*) AS reference_count
    FROM ops.display_label_print
    WHERE display_id IS NOT NULL
    GROUP BY display_id
),
scene_refs AS (
    SELECT display_id, count(*) AS reference_count
    FROM ref.lor_scene_display
    GROUP BY display_id
)
SELECT
    cr.import_run_id AS current_import_run_id,
    cr.run_ts AS current_ingest_at,
    d.display_id,
    d.display_name AS production_display_name,
    d.lor_prop_id AS production_lor_prop_id,
    d.stage_id AS production_stage_id,
    d.display_status_id,
    ds.display_status_name,
    d.container_id,
    d.inventory_type,
    d.designer_id,
    d.theme_id,
    d.frame_id,
    d.year_built,
    d.amps_measured,
    d.est_light_count,
    d.dumb_controller,
    d.notes,
    d.label_required,
    d.created_at,
    d.created_by,
    d.created_by_person_id,
    d.updated_at,
    d.updated_by,
    d.updated_by_person_id,
    cs.lor_prop_id AS current_lor_prop_id,
    cs.display_name AS current_lor_display_name,
    cs.preview_stage_id AS current_lor_stage_key,
    cs.preview_name AS current_preview_name,
    cs.preview_id AS current_preview_id,
    fs.first_import_run_id,
    fs.first_seen_at,
    fs.first_seen_notes,
    coalesce(ap.approval_count, 0) AS reconciliation_approval_count,
    ap.first_approval_at,
    ap.last_approval_at,
    coalesce(wo.reference_count, 0) AS work_order_reference_count,
    coalesce(tr.reference_count, 0) AS test_reference_count,
    coalesce(lr.reference_count, 0) AS label_reference_count,
    coalesce(sr.reference_count, 0) AS scene_reference_count,
    CASE
        WHEN coalesce(ap.approval_count, 0) > 0
            THEN 'APPROVAL_RECORDED'
        WHEN d.created_at >= fs.first_seen_at
         AND coalesce(wo.reference_count, 0) = 0
         AND coalesce(tr.reference_count, 0) = 0
         AND coalesce(lr.reference_count, 0) = 0
         AND coalesce(sr.reference_count, 0) = 0
            THEN 'LIKELY_UNAPPROVED_INSERT_REVIEW_REQUIRED'
        ELSE 'REVIEW_HISTORY_AND_RELATIONSHIPS'
    END AS forensic_classification
FROM current_source AS cs
JOIN ref.display AS d
  ON upper(btrim(d.display_name)) = cs.display_name_normalized
JOIN current_run AS cr
  ON cr.import_run_id = cs.import_run_id
JOIN first_seen_detail AS fs
  ON fs.display_name_normalized = cs.display_name_normalized
LEFT JOIN ref.display_status AS ds
  ON ds.display_status_id = d.display_status_id
LEFT JOIN approvals AS ap
  ON ap.display_id = d.display_id
LEFT JOIN work_order_refs AS wo
  ON wo.display_id = d.display_id
LEFT JOIN test_refs AS tr
  ON tr.display_id = d.display_id
LEFT JOIN label_refs AS lr
  ON lr.display_id = d.display_id
LEFT JOIN scene_refs AS sr
  ON sr.display_id = d.display_id
WHERE
    coalesce(ap.approval_count, 0) = 0
    AND (
        d.display_id >= 1100
        OR d.created_at >= fs.first_seen_at
    )
ORDER BY
    d.created_at DESC,
    d.display_id DESC;
