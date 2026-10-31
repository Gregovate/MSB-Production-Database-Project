-- #205 reporting-only disposable gate. Existing runner owns clone creation.
-- No schema changes, movement correction, synthetic scan or report insertion.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL ROLE fieldwiring_app;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';
-- Exercise the exact new Report Work fields/joins under the preview read role.
WITH latest AS (
 SELECT DISTINCT ON (p.setup_session_task_id)
        p.setup_session_task_id, p.setup_task_progress_id,
        p.performed_on, p.percent_complete, p.progress_note,
        p.recorded_at, p.updated_at,
        coalesce(nullif(btrim(concat_ws(' ', a.first_name,a.last_name)),''),a.email) AS recorded_by,
        coalesce(nullif(btrim(concat_ws(' ', u.first_name,u.last_name)),''),u.email) AS updated_by
 FROM ops.setup_task_progress p
 JOIN ops.setup_session_task t USING (setup_session_task_id)
 JOIN ops.setup_session s USING (setup_session_id)
 LEFT JOIN ref.person a ON a.person_id=p.created_by_person_id
 LEFT JOIN ref.person u ON u.person_id=p.updated_by_person_id
 WHERE s.season_year=2026
 ORDER BY p.setup_session_task_id,p.performed_on DESC NULLS LAST,
          p.recorded_at DESC,p.setup_task_progress_id DESC
)
SELECT count(*) AS tasks_with_report_evidence,
       count(progress_note) AS latest_reports_with_notes,
       count(recorded_by) AS latest_reports_with_attribution FROM latest;
-- Inspect availability; absence is a reporting gap, never permission to migrate.
SELECT table_schema,table_name,column_name
FROM information_schema.columns
WHERE (table_schema,table_name) IN
 (('ref','container'),('ref','display'),('ops','setup_container_state'),('ops','setup_display_state'))
 AND (column_name ILIKE '%pickup%' OR column_name ILIKE '%integral%'
      OR column_name ILIKE '%final%' OR column_name ILIKE '%attach%')
ORDER BY table_schema,table_name,column_name;
ROLLBACK;
\echo PASS: existing Report Work evidence is readable; no database writes
