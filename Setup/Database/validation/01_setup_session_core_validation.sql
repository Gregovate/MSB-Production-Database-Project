/* ============================================================================
MSB Setup Session — core schema validation
Issue: #122
Type: READ ONLY

Run only after 001_create_setup_session_core.sql has been deliberately applied
in an approved database environment.
============================================================================ */

/* 1. Required tables exist. expected missing_count = 0 */
WITH required(schema_name, table_name) AS (
    VALUES
        ('ref','setup_task'),
        ('ref','setup_task_dependency'),
        ('ref','setup_task_display'),
        ('ref','setup_task_container_support'),
        ('ref','setup_task_captain'),
        ('ref','setup_resource'),
        ('ref','setup_task_resource'),
        ('ops','setup_session'),
        ('ops','setup_session_task'),
        ('ops','setup_work_day'),
        ('ops','setup_work_day_task'),
        ('ops','setup_container_state'),
        ('ops','setup_display_state'),
        ('ops','setup_movement_event'),
        ('ops','setup_movement_event_display')
)
SELECT count(*) AS missing_count
FROM required r
LEFT JOIN information_schema.tables t
  ON t.table_schema = r.schema_name
 AND t.table_name = r.table_name
WHERE t.table_name IS NULL;

/* 2. One annual Setup Session per season constraint exists. */
SELECT
    conname,
    pg_get_constraintdef(oid, true) AS definition
FROM pg_constraint
WHERE conrelid = 'ops.setup_session'::regclass
  AND conname = 'uq_setup_session_season';

/* 3. Reusable tasks are in ref; annual task state is in ops. */
SELECT
    to_regclass('ref.setup_task') AS reusable_task_master,
    to_regclass('ops.setup_session_task') AS annual_task_state,
    to_regclass('ops.setup_movement_event') AS movement_history,
    to_regclass('ops.setup_display_state') AS annual_display_position;

/* 4. Actor triggers must exist on every Setup table. expected 30 rows. */
SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    t.tgname AS trigger_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname IN ('ref','ops')
  AND c.relname LIKE 'setup_%'
  AND t.tgname LIKE 'trg_%_actor_%'
ORDER BY n.nspname, c.relname, t.tgname;

/* 5. Movement must not change permanent Display -> Container relationships.
      This query simply re-proves the permanent relationship still belongs to
      ref.display and that no setup table contains a replacement container_id
      on setup_display_state. */
SELECT
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'display'
          AND column_name = 'container_id'
    ) AS ref_display_still_owns_container,
    NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_display_state'
          AND column_name = 'container_id'
    ) AS setup_display_state_does_not_snapshot_container;

/* 6. Current permanent Display -> Container -> storage resolution baseline. */
SELECT
    count(*) AS total_displays,
    count(*) FILTER (WHERE d.container_id IS NOT NULL) AS displays_with_container,
    count(*) FILTER (
        WHERE d.container_id IS NOT NULL
          AND c.container_id IS NOT NULL
          AND c.location_code IS NOT NULL
          AND sl.location_code IS NOT NULL
    ) AS resolved_storage_locations
FROM ref.display d
LEFT JOIN ref.container c ON c.container_id = d.container_id
LEFT JOIN ref.storage_location sl ON sl.location_code = c.location_code;

/* 7. No annual session rows are inserted by the schema migration itself. */
SELECT count(*) AS setup_session_rows
FROM ops.setup_session;
