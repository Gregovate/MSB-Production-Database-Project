\set ON_ERROR_STOP on
-- #445: current-state capture; SELECT only, suitable for Production read-only capture.
-- Do not substitute these results for an accepted freeze/snapshot.
BEGIN READ ONLY;
SELECT ss.setup_session_id,ss.season_year,ss.session_status
FROM ops.setup_session ss WHERE ss.season_year IN (2025,2026) ORDER BY season_year;
SELECT t.setup_task_id,t.task_name,t.active_flag,t.task_action_type,t.stage_id,
       t.normal_crew_min,t.normal_crew_max,t.expected_duration_minutes
FROM ref.setup_task t WHERE t.setup_task_id IN
(17,18,19,20,21,28,29,32,33,34,86,122,126,172,185,213,221,306,387)
ORDER BY t.setup_task_id;
SELECT t.setup_task_id,t.prerequisite_setup_task_id,t.dependency_note
FROM ref.setup_task_dependency t
WHERE t.setup_task_id IN (17,18,19,20,21,28,29,32,33,34,86,122,126,172,185,213,221,306,387)
OR t.prerequisite_setup_task_id IN (17,20,32,126,306)
ORDER BY 1,2;
SELECT st.setup_session_task_id,ss.season_year,st.setup_task_id,st.task_origin,
 st.annual_task_name,st.included_flag,st.execution_status,st.actual_started_at,
 st.actual_completed_at,st.actual_crew_count,st.actual_duration_minutes
FROM ops.setup_session_task st JOIN ops.setup_session ss USING(setup_session_id)
WHERE st.setup_task_id IN (17,18,19,20,21,28,29,32,33,34,86,122,126,213,306,387)
ORDER BY ss.season_year,st.setup_task_id;
SELECT ss.season_year,st.setup_task_id AS task_id,
 pst.setup_task_id AS prerequisite_id, d.dependency_origin,d.dependency_note
FROM ops.setup_session_task_dependency d
JOIN ops.setup_session_task st ON st.setup_session_task_id=d.setup_session_task_id
JOIN ops.setup_session_task pst ON pst.setup_session_task_id=d.prerequisite_setup_session_task_id
JOIN ops.setup_session ss ON ss.setup_session_id=st.setup_session_id
WHERE ss.season_year=2026 AND
 (st.setup_task_id IN (18,21,29,32,34,86,126,213)
  OR pst.setup_task_id IN (17,20,32,126,306))
ORDER BY 2,3;
SELECT setup_task_id,container_id,relationship_type,notes
FROM ref.setup_task_container_support
WHERE setup_task_id IN (17,19,20,21,32,34,122,126,306)
ORDER BY 1,2;
SELECT setup_task_id,display_id,relationship_type,notes
FROM ref.setup_task_display
WHERE setup_task_id IN (17,20,32,34)
ORDER BY 1,2;
SELECT st.setup_task_id,p.setup_session_task_id,count(*) AS progress_rows
FROM ops.setup_task_progress p JOIN ops.setup_session_task st
ON st.setup_session_task_id=p.setup_session_task_id
JOIN ops.setup_session ss ON ss.setup_session_id=st.setup_session_id
WHERE ss.season_year=2026 AND st.setup_task_id IN (17,20,32,122,126,306)
GROUP BY 1,2 ORDER BY 1;
SELECT st.setup_task_id,st.setup_session_task_id,count(*) AS assigned_rows
FROM ops.setup_work_day_task w JOIN ops.setup_session_task st
ON st.setup_session_task_id=w.setup_session_task_id
JOIN ops.setup_session ss ON ss.setup_session_id=st.setup_session_id
WHERE ss.season_year=2026 AND st.setup_task_id IN (17,20,32,122,126,306)
GROUP BY 1,2 ORDER BY 1;
COMMIT;
