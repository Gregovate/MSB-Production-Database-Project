/*
MSB Setup — read-only durability check after LOR2DB reconciliation

Purpose
-------
Prove that a current LOR reconciliation can change ref.lor_scene / ref.lor_scene_display
membership while durable Setup knowledge remains intact.

This query is SELECT-only. It is tailored to LOR reconciliation Run 21 / ingest 63
(2026-09-14), whose write window was approximately 16:59:39 through 17:00:55 UTC.

Expected interpretation
-----------------------
1. The Stage 13 displays below should show their new current LOR Scene membership.
2. Scene-scoped Setup tasks, where present, should follow that current Scene membership
   through ref.lor_scene_display; no copied Display membership is required.
3. Durable Setup tables should show zero rows updated during the LOR reconciliation
   write window.
4. Current reusable-task / Kit fingerprints are retained as a post-run reference for
   later comparison.
*/

\set ON_ERROR_STOP on

\echo '=== A. Run-21 changed Stage 13 displays: current LOR membership and Scene-scoped Setup task linkage ==='
SELECT
    d.display_id,
    d.display_name,
    ls.lor_scene_id,
    ls.scene_name,
    string_agg(
        format(
            'Task %s | %s | requires_display_material=%s',
            t.setup_task_id,
            t.task_name,
            t.requires_display_material
        ),
        E'\n'
        ORDER BY t.display_order, t.setup_task_id
    ) FILTER (WHERE t.setup_task_id IS NOT NULL) AS scene_scoped_setup_tasks
FROM ref.display AS d
JOIN ref.lor_scene_display AS lsd
  ON lsd.display_id = d.display_id
JOIN ref.lor_scene AS ls
  ON ls.lor_scene_id = lsd.lor_scene_id
LEFT JOIN ref.setup_task AS t
  ON t.lor_scene_id = ls.lor_scene_id
 AND t.active_flag
WHERE d.display_name IN (
    '45-WW-SleddingDog',
    '47-WW-EarlyBird',
    '48-WW-RRCrossing-01',
    '53-WW-WallyWagon',
    '65-WW-Lobster',
    '67-WW-VW',
    '70-WW-RRCrossing-02'
)
GROUP BY
    d.display_id,
    d.display_name,
    ls.lor_scene_id,
    ls.scene_name
ORDER BY d.display_name, ls.scene_name;

\echo ''
\echo '=== B. Current Stage 13 reusable Setup task scope ==='
SELECT
    t.setup_task_id,
    t.task_name,
    t.active_flag,
    t.requires_display_material,
    t.lor_scene_id,
    ls.scene_name,
    count(DISTINCT lsd.display_id) AS current_scene_display_rows
FROM ref.setup_task AS t
LEFT JOIN ref.lor_scene AS ls
  ON ls.lor_scene_id = t.lor_scene_id
LEFT JOIN ref.lor_scene_display AS lsd
  ON lsd.lor_scene_id = t.lor_scene_id
WHERE t.stage_id = (
    SELECT stage_id
    FROM ref.stage
    WHERE stage_key = '13'
)
GROUP BY
    t.setup_task_id,
    t.task_name,
    t.active_flag,
    t.requires_display_material,
    t.lor_scene_id,
    ls.scene_name,
    t.display_order
ORDER BY t.display_order, t.setup_task_id;

\echo ''
\echo '=== C. Durable Setup rows updated during LOR Run-21 write window ==='
WITH changed AS (
    SELECT 'ref.setup_task'::text AS table_name, count(*)::bigint AS rows_touched
    FROM ref.setup_task
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ref.setup_task_dependency', count(*)
    FROM ref.setup_task_dependency
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ref.setup_task_display', count(*)
    FROM ref.setup_task_display
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ref.setup_task_container_support', count(*)
    FROM ref.setup_task_container_support
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ref.setup_task_resource', count(*)
    FROM ref.setup_task_resource
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ops.setup_session', count(*)
    FROM ops.setup_session
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'

    UNION ALL
    SELECT 'ops.setup_session_task', count(*)
    FROM ops.setup_session_task
    WHERE updated_at >= timestamptz '2026-09-14 16:59:30+00'
      AND updated_at <= timestamptz '2026-09-14 17:01:10+00'
)
SELECT
    table_name,
    rows_touched,
    CASE WHEN rows_touched = 0 THEN 'PASS - untouched by LOR reconciliation'
         ELSE 'REVIEW - Setup rows changed during LOR reconciliation window'
    END AS verdict
FROM changed
ORDER BY table_name;

\echo ''
\echo '=== D. Current durable Setup counts and fingerprints ==='
SELECT
    (SELECT count(*) FROM ref.setup_task WHERE active_flag) AS active_reusable_tasks,
    (SELECT count(*) FROM ref.setup_task_dependency) AS task_dependencies,
    (SELECT count(*) FROM ref.setup_task_display) AS explicit_task_display_rows,
    (SELECT count(*) FROM ref.setup_task_container_support WHERE relationship_type='KIT') AS kit_assignment_rows,
    (SELECT count(*) FROM ref.setup_task_resource) AS task_resource_rows,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2025) AS setup_2025_sessions,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_sessions,
    md5(coalesce((
        SELECT string_agg(row_to_json(x)::text, '' ORDER BY x.setup_task_id)
        FROM ref.setup_task AS x
    ), '')) AS reusable_task_fingerprint,
    md5(coalesce((
        SELECT string_agg(row_to_json(x)::text, '' ORDER BY x.setup_task_id, x.container_id)
        FROM ref.setup_task_container_support AS x
        WHERE x.relationship_type='KIT'
    ), '')) AS kit_assignment_fingerprint;

\echo ''
\echo '=== E. Current Kit assignment list for operator verification ==='
SELECT
    tc.container_id,
    c.description AS kit_name,
    t.setup_task_id,
    s.stage_key,
    s.stage_name,
    t.task_name,
    tc.notes AS relationship_notes
FROM ref.setup_task_container_support AS tc
JOIN ref.container AS c
  ON c.container_id = tc.container_id
JOIN ref.setup_task AS t
  ON t.setup_task_id = tc.setup_task_id
LEFT JOIN ref.stage AS s
  ON s.stage_id = t.stage_id
WHERE tc.relationship_type='KIT'
ORDER BY tc.container_id, t.setup_task_id;
