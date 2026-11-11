-- #205 / #122 | READ ONLY | Find replacement duplicate-assignment test candidates.
-- Scope: unfinished annual tasks with at least two unreported 2026 assignments.
-- Missing matched reports are evidence gaps, not proof that no work occurred.
-- Sort: reusable task, annual task, work date, shift, assignment ID.
WITH unreported AS (
    SELECT st.setup_session_id, st.setup_task_id, st.setup_session_task_id,
           st.annual_task_name AS task_name, st.execution_status,
           s.stage_key, s.stage_name, ls.scene_name,
           a.setup_work_day_task_id, d.work_date, a.shift_code,
           a.setup_work_day_crew_id,
           count(*) OVER (PARTITION BY st.setup_session_task_id) AS unreported_assignments
    FROM ops.setup_session_task st
    JOIN ops.setup_work_day_task a USING (setup_session_task_id)
    JOIN ops.setup_work_day d ON d.setup_work_day_id = a.setup_work_day_id
    LEFT JOIN ref.stage s ON s.stage_id = st.annual_stage_id
    LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = st.annual_lor_scene_id
    WHERE st.execution_status NOT IN ('COMPLETE', 'DEFERRED')
      AND d.day_status <> 'CANCELLED'
      AND d.work_date >= DATE '2026-01-01'
      AND d.work_date < DATE '2027-01-01'
      AND NOT EXISTS (
          SELECT 1 FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = a.setup_work_day_task_id
             OR (p.setup_work_day_task_id IS NULL
                 AND p.setup_session_task_id = a.setup_session_task_id
                 AND p.setup_work_day_id = a.setup_work_day_id
                 AND p.shift_code = a.shift_code)
      )
)
SELECT * FROM unreported
WHERE unreported_assignments > 1
ORDER BY setup_task_id NULLS LAST, setup_session_task_id,
         work_date, shift_code, setup_work_day_task_id;
