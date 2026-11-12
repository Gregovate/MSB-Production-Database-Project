-- Purpose: inventory 2026 historical reports and resulting Work Orders before
-- Manager-confirmed pre-show QC reconciliation (#122/#205, PR485).
-- Scope: SELECT ONLY. No QC backfill, source edits, promotion reversal or close.
-- Missing source Stage is displayed as missing, never inferred from free text.
-- One row per Intake/Work Order pair; multiple resulting Work Orders stay visible.
SELECT i.intake_id, i.source_form_name, i.submitter_name_raw,
       i.updated_at AT TIME ZONE 'America/Chicago' AS intake_updated_local,
       i.stage_id AS intake_stage_id,
       to_jsonb(i)->>'stage_raw' AS original_stage_text,
       i.target_year, i.problem_raw, i.notes_raw,
       w.work_order_id, w.stage_id AS work_order_stage_id,
       w.is_active AS work_order_active, w.problem AS work_order_problem,
       w.notes AS work_order_notes, w.completion_notes
FROM stage.work_order_intake i
LEFT JOIN ops.work_order w ON w.source_intake_id=i.intake_id
WHERE i.target_year=2026
   OR (i.target_year IS NULL AND
       extract(year FROM i.updated_at AT TIME ZONE 'America/Chicago')::integer=2026)
ORDER BY i.intake_id, w.work_order_id NULLS FIRST;
