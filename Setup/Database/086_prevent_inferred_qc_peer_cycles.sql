-- #122/#205: peer QC checks cannot infer mutual sign-off dependencies.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION ops.setup_qc_final_gate(p_task bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref
AS $gate$
WITH target AS (
  SELECT * FROM ops.setup_session_task WHERE setup_session_task_id=p_task
), required AS (
  SELECT pst.setup_session_task_id AS id
  FROM target t JOIN ref.setup_task_dependency rd ON rd.setup_task_id=t.setup_task_id
  LEFT JOIN ops.setup_session_task pst ON pst.setup_session_id=t.setup_session_id
    AND pst.setup_task_id=rd.prerequisite_setup_task_id
  WHERE t.task_origin='REUSABLE'
  UNION
  SELECT ad.prerequisite_setup_session_task_id
  FROM target t JOIN ops.setup_session_task_dependency ad ON ad.setup_session_task_id=p_task
  LEFT JOIN ops.setup_session_task pst ON pst.setup_session_task_id=ad.prerequisite_setup_session_task_id
  WHERE t.task_origin='SEASON_ONLY' OR (ad.dependency_origin='ANNUAL' AND NOT EXISTS (
    SELECT 1 FROM ref.setup_task_dependency rd WHERE rd.setup_task_id=t.setup_task_id
      AND rd.prerequisite_setup_task_id=pst.setup_task_id))
  UNION
  SELECT pst.setup_session_task_id FROM target t
  JOIN ops.setup_session_task pst ON pst.setup_session_id=t.setup_session_id
    AND pst.annual_stage_id IS NOT DISTINCT FROM t.annual_stage_id
  WHERE pst.included_flag AND pst.setup_session_task_id<>p_task
    AND (t.annual_lor_scene_id IS NULL OR pst.annual_lor_scene_id=t.annual_lor_scene_id)
    -- Infer QC prerequisites only down the stage -> scene hierarchy. Peer
    -- checks in the same scope must not automatically require each other.
    -- Explicit reusable/annual dependencies above remain authoritative.
    AND (NOT ops.setup_qc_is_final_task(pst.setup_session_task_id)
         OR (t.annual_lor_scene_id IS NULL AND pst.annual_lor_scene_id IS NOT NULL))
), work AS (
  SELECT r.id,coalesce(pst.annual_task_name,'Missing annual prerequisite') AS name,
    CASE WHEN ops.setup_qc_is_final_task(pst.setup_session_task_id)
      THEN EXISTS (SELECT 1 FROM ops.setup_qc_signoff q WHERE q.setup_session_task_id=pst.setup_session_task_id)
      ELSE coalesce(pst.execution_status='COMPLETE' OR
        (pst.linked_work_order_gate AND wo.date_completed IS NOT NULL),false)
    END AS complete
  FROM required r LEFT JOIN ops.setup_session_task pst ON pst.setup_session_task_id=r.id
  LEFT JOIN ops.setup_scheduling_work_order_gate wo ON wo.work_order_id=pst.linked_work_order_id
)
SELECT jsonb_build_object(
  'task_id',p_task,
  'readiness_met',coalesce((SELECT annual_readiness_state='READY' FROM target),false),
  'required_work',coalesce((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.id NULLS FIRST) FROM work w),'[]'::jsonb),
  'unfinished_work',coalesce((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.id NULLS FIRST) FROM work w WHERE NOT complete),'[]'::jsonb),
  'unrepaired_findings',(SELECT count(*) FROM ops.setup_qc_finding f WHERE f.setup_session_task_id=p_task AND f.status IN ('OPEN','CLAIMED') AND NOT EXISTS(SELECT 1 FROM ops.setup_qc_season_exception x WHERE x.qc_finding_id=f.qc_finding_id)),
  'accepted_exceptions',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM ops.setup_qc_season_exception x JOIN ops.setup_qc_finding f USING(qc_finding_id) WHERE f.setup_session_task_id=p_task),'[]'::jsonb),
  'unresolved_findings',(SELECT count(*) FROM ops.setup_qc_finding f WHERE f.setup_session_task_id=p_task AND f.status<>'VERIFIED' AND NOT EXISTS(SELECT 1 FROM ops.setup_qc_season_exception x WHERE x.qc_finding_id=f.qc_finding_id))
);
$gate$;

COMMIT;
