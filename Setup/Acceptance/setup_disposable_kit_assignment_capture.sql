/*
Disposable Kit assignment capture query.

Run only against the disposable browser-preview clone after the Manager has
finished the bulk Kit assignment pass. Existing Production assignments are
excluded because the workbench stamps only newly-created review rows with the
marker below.

This file is read-only. It does not mutate assignments.
*/

SELECT
    tc.setup_task_id,
    s.stage_key,
    s.stage_name,
    t.task_name,
    tc.container_id,
    c.description AS container_description,
    c.location_code,
    tc.relationship_type,
    tc.notes
FROM ref.setup_task_container_support AS tc
JOIN ref.setup_task AS t
  ON t.setup_task_id = tc.setup_task_id
LEFT JOIN ref.stage AS s
  ON s.stage_id = t.stage_id
JOIN ref.container AS c
  ON c.container_id = tc.container_id
WHERE tc.relationship_type = 'KIT'
  AND tc.notes LIKE '[DISPOSABLE_KIT_RECON_V1]%'
ORDER BY
    s.park_order NULLS LAST,
    s.sub_order NULLS LAST,
    t.display_order,
    tc.setup_task_id,
    tc.container_id;
