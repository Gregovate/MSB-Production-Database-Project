/* ============================================================================
MSB Setup Session — reviewed reusable catalog reconstruction
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-09 V0.1.0

Source authority:
  - reviewed MSB_Setup_ONE_LIST_Reconciliation_20260909_WITH_EFFORT workbook;
  - current Production Stage/Scene inventory exported 2026-09-09;
  - current 68-task reusable Production snapshot.

Result:
  - 191 active reusable tasks;
  - 66 existing reusable identities retained/updated;
  - 125 new reusable tasks created;
  - provisional duplicate task 40 retired in favor of task 51;
  - junk provisional task 58 retired;
  - 2025 annual history is NOT backfilled with newly reconstructed tasks.

Normalization:
  - equivalent locate variants -> Locate Power & Network;
  - equivalent panel-position variants -> Layout Panels;
  - MEDIUM effort -> MODERATE;
  - no planning-role/trailer-specific column is introduced.

Dependency boundary:
  Existing reusable dependencies are cleared. The reviewed predecessor pass is
  intentionally separate and must occur before the 2026 Setup Session exists.
============================================================================ */

\set ON_ERROR_STOP on
BEGIN;

DO $preflight$
DECLARE
    v_active_count integer;
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup reusable/annual foundation is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'effort_level'
    ) THEN
        RAISE EXCEPTION 'Migration 023 effort metadata must be installed first';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year >= 2026) THEN
        RAISE EXCEPTION 'STOP: a 2026-or-later Setup Session already exists';
    END IF;

    SELECT count(*) INTO v_active_count
    FROM ref.setup_task
    WHERE active_flag;

    IF v_active_count <> 68 THEN
        RAISE EXCEPTION 'STOP: expected 68 active reusable tasks before reconstruction, found %', v_active_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task
        WHERE setup_task_id = 40
          AND task_name = 'Deliver Command Center'
          AND active_flag
    ) THEN
        RAISE EXCEPTION 'STOP: provisional duplicate task 40 is not in the reviewed baseline';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task
        WHERE setup_task_id = 51
          AND task_name = 'Deliver and Set Up Command Center Trailer'
          AND active_flag
    ) THEN
        RAISE EXCEPTION 'STOP: accepted Command Center task 51 is not in the reviewed baseline';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task
        WHERE setup_task_id = 58
          AND task_name = 'light'
          AND active_flag
    ) THEN
        RAISE EXCEPTION 'STOP: provisional junk task 58 is not in the reviewed baseline';
    END IF;
END
$preflight$;

CREATE TEMP TABLE setup_catalog_reconstruction (
    source_id text PRIMARY KEY,
    existing_task_id bigint,
    target_task_id bigint,
    task_name text NOT NULL,
    stage_id integer,
    lor_scene_id bigint,
    task_action_type text NOT NULL,
    display_order integer NOT NULL,
    baseline_plan_order integer NOT NULL,
    normal_crew_min integer,
    normal_crew_max integer,
    expected_duration_minutes integer,
    effort_level text
);

\ir reconstruction/024_catalog_batch_01.sql
\ir reconstruction/024_catalog_batch_02.sql
\ir reconstruction/024_catalog_batch_03.sql
\ir reconstruction/024_catalog_batch_04.sql
\ir reconstruction/024_catalog_batch_05.sql

DO $source_validation$
BEGIN
    IF (SELECT count(*) FROM setup_catalog_reconstruction) <> 191 THEN
        RAISE EXCEPTION 'Catalog source row count is not 191';
    END IF;

    IF EXISTS (
        SELECT existing_task_id
        FROM setup_catalog_reconstruction
        WHERE existing_task_id IS NOT NULL
        GROUP BY existing_task_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Catalog source contains duplicate existing task identities';
    END IF;

    IF (
        SELECT count(*)
        FROM setup_catalog_reconstruction
        WHERE existing_task_id IS NOT NULL
    ) <> 66 THEN
        RAISE EXCEPTION 'Catalog source must retain exactly 66 existing reusable identities';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM setup_catalog_reconstruction s
        LEFT JOIN ref.setup_task t
          ON t.setup_task_id = s.existing_task_id
        WHERE s.existing_task_id IS NOT NULL
          AND t.setup_task_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Catalog source references an existing Setup task that is not present';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM setup_catalog_reconstruction s
        LEFT JOIN ref.stage st
          ON st.stage_id = s.stage_id
        WHERE s.stage_id IS NOT NULL
          AND st.stage_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Catalog source references an unknown Stage';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM setup_catalog_reconstruction s
        LEFT JOIN ref.lor_scene ls
          ON ls.lor_scene_id = s.lor_scene_id
         AND ls.stage_id = s.stage_id
        WHERE s.lor_scene_id IS NOT NULL
          AND ls.lor_scene_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Catalog source contains a Scene that does not belong to its Stage';
    END IF;
END
$source_validation$;

/* Keep the historical shells but remove provisional definitions from future use. */
UPDATE ops.setup_session_task st
   SET included_flag = false
 WHERE st.setup_task_id IN (40, 58)
   AND EXISTS (
       SELECT 1
       FROM ops.setup_session ss
       WHERE ss.setup_session_id = st.setup_session_id
         AND ss.session_status = 'HISTORICAL_VERIFICATION'
   );

UPDATE ref.setup_task
   SET active_flag = false
 WHERE setup_task_id IN (40, 58);

/* Predecessors are rebuilt after the catalog itself is accepted. */
DELETE FROM ref.setup_task_dependency;

/* Reuse permanent identities wherever the reviewed workbook already mapped one. */
UPDATE ref.setup_task t
   SET task_name = s.task_name,
       stage_id = s.stage_id,
       lor_scene_id = s.lor_scene_id,
       task_action_type = s.task_action_type,
       display_order = s.display_order,
       baseline_plan_order = s.baseline_plan_order,
       normal_crew_min = coalesce(s.normal_crew_min, t.normal_crew_min),
       normal_crew_max = coalesce(s.normal_crew_max, t.normal_crew_max),
       expected_duration_minutes = coalesce(
           s.expected_duration_minutes,
           t.expected_duration_minutes
       ),
       effort_level = s.effort_level,
       active_flag = true
FROM setup_catalog_reconstruction s
WHERE s.existing_task_id = t.setup_task_id;

UPDATE setup_catalog_reconstruction
   SET target_task_id = existing_task_id
 WHERE existing_task_id IS NOT NULL;

/* Create only reusable definitions. Do not fabricate 2025 annual occurrences. */
DO $create_new$
DECLARE
    r record;
    v_task_id bigint;
BEGIN
    FOR r IN
        SELECT *
        FROM setup_catalog_reconstruction
        WHERE existing_task_id IS NULL
        ORDER BY baseline_plan_order, source_id
    LOOP
        INSERT INTO ref.setup_task(
            task_name,
            stage_id,
            lor_scene_id,
            task_action_type,
            display_order,
            active_flag,
            normal_crew_min,
            normal_crew_max,
            expected_duration_minutes,
            effort_level,
            baseline_plan_order
        ) VALUES (
            r.task_name,
            r.stage_id,
            r.lor_scene_id,
            r.task_action_type,
            r.display_order,
            true,
            r.normal_crew_min,
            r.normal_crew_max,
            r.expected_duration_minutes,
            r.effort_level,
            r.baseline_plan_order
        )
        RETURNING setup_task_id INTO v_task_id;

        UPDATE setup_catalog_reconstruction
           SET target_task_id = v_task_id
         WHERE source_id = r.source_id;
    END LOOP;
END
$create_new$;

DO $postcheck$
DECLARE
    v_active_count integer;
BEGIN
    SELECT count(*) INTO v_active_count
    FROM ref.setup_task
    WHERE active_flag;

    IF v_active_count <> 191 THEN
        RAISE EXCEPTION 'STOP: reconstruction expected 191 active tasks, found %', v_active_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM setup_catalog_reconstruction
        WHERE target_task_id IS NULL
    ) THEN
        RAISE EXCEPTION 'STOP: a reconstruction row did not resolve to a permanent Setup task ID';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE active_flag
          AND setup_task_id IN (40, 58)
    ) THEN
        RAISE EXCEPTION 'STOP: provisional tasks 40/58 were not retired';
    END IF;

    IF (SELECT count(*) FROM ref.setup_task_dependency) <> 0 THEN
        RAISE EXCEPTION 'STOP: predecessor reset did not produce an empty dependency set';
    END IF;
END
$postcheck$;

COMMIT;

SELECT
    count(*) FILTER (WHERE existing_task_id IS NOT NULL) AS existing_updated,
    count(*) FILTER (WHERE existing_task_id IS NULL) AS newly_created,
    count(*) AS active_catalog_target
FROM setup_catalog_reconstruction;

SELECT
    effort_level,
    count(*) AS task_count
FROM ref.setup_task
WHERE active_flag
GROUP BY effort_level
ORDER BY effort_level NULLS FIRST;
