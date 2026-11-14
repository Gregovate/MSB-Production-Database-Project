-- QC coverage investigation only. No writes, no task creation, no repair changes.
-- Includes reference areas without tasks; their current-season eligibility must be reviewed.
BEGIN TRANSACTION READ ONLY;
WITH areas AS (
 SELECT s.stage_id,s.stage_key,s.stage_name,NULL::integer AS lor_scene_id,
        'Stage-level'::text AS scene_name FROM ref.stage s WHERE s.stage_key IS NOT NULL
 UNION ALL
 SELECT s.stage_id,s.stage_key,s.stage_name,l.lor_scene_id,l.scene_name
 FROM ref.stage s JOIN ref.lor_scene l ON l.stage_id=s.stage_id
 WHERE s.stage_key IS NOT NULL
), annual AS (
 SELECT t.*,q.signed_at,
   t.annual_task_name ~* '(plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show|^QC Check - Verify Stage/Scene sequence lights during the 2 minute test sequence$)' AS recognized_qc
 FROM ops.setup_session_task t JOIN ops.setup_session ss USING(setup_session_id)
 LEFT JOIN ops.setup_qc_signoff q USING(setup_session_task_id)
 WHERE ss.season_year=2026
)
SELECT a.stage_id,a.stage_key,a.stage_name,a.lor_scene_id,a.scene_name,
 count(t.setup_session_task_id) AS annual_tasks,
 count(t.setup_session_task_id) FILTER(WHERE t.included_flag) AS included_tasks,
 count(t.setup_session_task_id) FILTER(WHERE t.recognized_qc AND t.included_flag) AS qc_tasks,
 string_agg(t.setup_session_task_id::text,', ' ORDER BY t.setup_session_task_id)
   FILTER(WHERE t.recognized_qc AND t.included_flag) AS qc_ids,
 count(t.setup_session_task_id) FILTER(WHERE t.recognized_qc AND t.included_flag AND t.signed_at IS NOT NULL) AS signed_off_qc_tasks,
 CASE WHEN count(t.setup_session_task_id)=0 THEN 'No annual task at this exact scope'
 WHEN count(*) FILTER(WHERE t.recognized_qc AND t.included_flag)=0 THEN 'No included recognized QC task'
 WHEN count(*) FILTER(WHERE t.recognized_qc AND t.included_flag AND t.signed_at IS NULL)=0 THEN 'Signed off; hidden from active list'
 ELSE 'Has unsigned QC task; investigate UI filters if missing' END AS coverage
FROM areas a LEFT JOIN annual t ON t.annual_stage_id=a.stage_id
 AND t.annual_lor_scene_id IS NOT DISTINCT FROM a.lor_scene_id
GROUP BY a.stage_id,a.stage_key,a.stage_name,a.lor_scene_id,a.scene_name
ORDER BY a.stage_key,a.scene_name;

-- Preserve identity evidence when catalog and annual scopes differ.
SELECT t.setup_session_task_id,t.setup_task_id,t.annual_stage_id,
 t.annual_lor_scene_id,c.stage_id AS catalog_stage_id,c.lor_scene_id AS catalog_scene_id
FROM ops.setup_session_task t JOIN ops.setup_session ss USING(setup_session_id)
JOIN ref.setup_task c USING(setup_task_id)
WHERE ss.season_year=2026 AND (t.annual_stage_id IS DISTINCT FROM c.stage_id
 OR t.annual_lor_scene_id IS DISTINCT FROM c.lor_scene_id)
ORDER BY t.setup_session_task_id;
ROLLBACK;
